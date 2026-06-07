#!/usr/bin/env python3
"""Local checks for the Clean repo. No database, no dependencies.

Enforces every rule that can be checked mechanically. Same script powers three layers:
SessionStart hook, pre-commit hook, and CI. If a check passes here, drift cannot enter
the repo from any of those vectors.

Data + roster checks:
- clients.json parses and every standing record has the required fields
  (service_type_required, data_gap_explicit, hardness present).
- service_type is one of the allowed values.
- banned clients carry exclude_from_everything (banned_excluded).
- banned, one-off, and at-will clients never appear in route_template.md
  (banned_excluded, one_off_not_routed).

Copy checks:
- no em dashes or en dashes in tracked .md / .json files (no_em_dashes).
- src/ never uses bare 'grooming'/'groomer' without 'dog' qualifier (grooming_vocab).

Structural integrity (added to catch the drift modes that bit us before):
- no git merge conflict markers anywhere in tracked files.
- every Oracle rule key has a Business Rules index row, and vice versa.
- no references to the old data/ path outside legacy/data/ (the move happened 2026-05-26).
- no references to deleted claude/* branches inside .github/workflows/.

Two severities (redesign_survival_is_a_ship_gate):
- BLOCK (exit 1): broken data, conflict markers, Oracle/index drift, stale paths,
  engineering-safety regressions (raw fetch, nav backdrop-filter, auth listener),
  forbidden-pattern hits (em dash, jargon, DGN vocab, over-promises, priced
  add-ons), and the legal / safety / money customer commitments (friendly-dogs
  safety, the day-before charge promise, the 24-hour non-refundable terms,
  card-on-file). These are either unambiguous or catastrophic to ship.
- WARN (exit 0, printed loudly): brittle copy / design / UX phrasing whose rule
  is actually enforced in a durable layer (a DB constraint, a server RPC, or a
  data file). A legitimate rewrite of a marketing line should never be able to
  fail a deploy; the page string is a reminder, the durable layer is the teeth.

Run: python3 scripts/check.py
Exit code 0 = no blocking failures (warnings may print), 1 = at least one failure.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CLIENTS = REPO / "legacy" / "data" / "clients.json"
ROUTE = REPO / "legacy" / "data" / "route_template.md"
SITE = REPO / "src"

ALLOWED_SERVICE = {
    "full_groom",
    "bath",
    "nails_only_legacy",
    "mixed_groom_and_nails",
}
ALLOWED_CONFIDENCE = {"high", "medium", "low"}
ALLOWED_HARDNESS = {"HARD", "SOFT", "FLEX", "FLEX+"}
REQUIRED_STANDING_FIELDS = [
    "name", "status", "service_type", "cadence_days", "cadence_confidence",
    "dogs", "location", "access", "availability", "hardness", "flags",
    "relationships", "data_gaps",
]
EM_DASH = "—"
EN_DASH = "–"

# Two severities (see redesign_survival_is_a_ship_gate + the tiered-gate note
# in the module docstring):
#   failures  -> BLOCK: exit 1, fail the build. Reserved for problems that are
#                both unambiguous and catastrophic-or-durable to ship: broken
#                data, conflict markers, Oracle/index drift, engineering-safety
#                regressions, and legal / money / safety customer commitments.
#   warnings  -> WARN: printed loudly, never blocks. For brittle copy / design
#                phrasing whose rule is actually enforced in a durable layer
#                (DB constraint, server RPC, data file); the page string is a
#                reminder, not the last line of defense, so a legitimate
#                rewrite should not be able to fail a deploy.
#
# The invariant (redesign_survival_is_a_ship_gate): WARN is permitted ONLY when
# the rule's teeth live in a durable non-page layer (a DB constraint, an RPC, a
# data file, or a separate BLOCK guard), so dropping the page string does not
# lose the rule. A decision whose ONLY home is the page is split: BLOCK on the
# STRUCTURE that carries it (the element, the URL, the set of options) so a
# redesign cannot ship without it, and WARN only on the exact WORDING so a
# rewrite never blocks a deploy. A copy-only decision is never left as warn-only
# (that would let it ship dropped) and a block is never a dead end (the loop
# fixes it and retries; see the rule in CLEAN_ORACLE.md).
failures = []
warnings = []


def check_clients():
    try:
        data = json.loads(CLIENTS.read_text())
    except Exception as exc:
        failures.append(f"clients.json did not parse: {exc}")
        return

    standing = data.get("standing", [])
    if len(standing) != 33:
        failures.append(f"expected 33 standing clients, found {len(standing)}")

    for c in standing:
        name = c.get("name", "<unnamed>")
        for field in REQUIRED_STANDING_FIELDS:
            if field not in c:
                failures.append(f"{name}: missing required field '{field}'")
        st = c.get("service_type")
        if st not in ALLOWED_SERVICE:
            failures.append(f"{name}: service_type '{st}' not in {sorted(ALLOWED_SERVICE)}")
        conf = c.get("cadence_confidence")
        if conf not in ALLOWED_CONFIDENCE:
            failures.append(f"{name}: cadence_confidence '{conf}' not in {sorted(ALLOWED_CONFIDENCE)}")
        hard = c.get("hardness")
        if hard not in ALLOWED_HARDNESS:
            failures.append(f"{name}: hardness '{hard}' not in {sorted(ALLOWED_HARDNESS)}")

    for b in data.get("banned", []):
        if not b.get("exclude_from_everything"):
            failures.append(f"banned client {b.get('name')} missing exclude_from_everything=true")


def check_dashes():
    try:
        tracked = subprocess.check_output(
            ["git", "ls-files", "*.md", "*.json"], cwd=REPO, text=True
        ).split()
    except Exception as exc:
        failures.append(f"could not list tracked files: {exc}")
        return

    for rel in tracked:
        path = REPO / rel
        try:
            text = path.read_text(encoding="utf-8")
        except Exception:
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            if EM_DASH in line or EN_DASH in line:
                failures.append(f"{rel}:{lineno}: em/en dash found")


def check_route_excludes():
    """banned_excluded + one_off_not_routed: non-standing clients must never appear in the
    recurring route template."""
    try:
        data = json.loads(CLIENTS.read_text())
    except Exception:
        return  # parse failure already reported by check_clients
    try:
        route = ROUTE.read_text(encoding="utf-8")
    except Exception as exc:
        failures.append(f"could not read route_template.md: {exc}")
        return
    for group in ("one_off", "at_will", "banned"):
        for c in data.get(group, []):
            nm = c.get("name", "")
            if nm and nm in route:
                failures.append(
                    f"{group} client '{nm}' appears in route_template.md (must not be routed)"
                )


def check_dog_grooming():
    """grooming_vocab: customer-facing copy in src/ must say 'dog grooming' / 'dog groomer',
    never the bare words 'grooming' or 'groomer'."""
    if not SITE.exists():
        return
    exts = {".astro", ".md", ".mdx", ".html", ".js", ".jsx", ".ts", ".tsx"}
    pat = re.compile(r"groom(?:ing|er)", re.IGNORECASE)
    for path in sorted(SITE.rglob("*")):
        if not path.is_file() or path.suffix not in exts:
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for m in pat.finditer(text):
            before = text[max(0, m.start() - 4):m.start()].lower()
            if before.endswith("dog ") or before.endswith("dog-"):
                continue
            line = text.count("\n", 0, m.start()) + 1
            failures.append(
                f"{path.relative_to(REPO)}:{line}: '{m.group()}' must be qualified as "
                f"'dog {m.group()}' (grooming_vocab)"
            )


ORACLE = REPO / "CLEAN_ORACLE.md"
INDEX = REPO / "CLEAN_BUSINESS_RULES.md"
WORKFLOWS = REPO / ".github" / "workflows"
CONFLICT_MARKERS = ("<<<<<<< ", "=======\n", ">>>>>>> ")


def _tracked(*patterns):
    try:
        return subprocess.check_output(
            ["git", "ls-files", *patterns], cwd=REPO, text=True
        ).split()
    except Exception as exc:
        failures.append(f"could not list tracked files for {patterns}: {exc}")
        return []


def check_no_conflict_markers():
    for rel in _tracked():
        path = REPO / rel
        if not path.is_file():
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        # Skip this file itself: it defines the marker strings as data.
        if path.resolve() == Path(__file__).resolve():
            continue
        for lineno, line in enumerate(text.splitlines(keepends=True), 1):
            for marker in CONFLICT_MARKERS:
                if line.startswith(marker.rstrip("\n")) and (
                    marker.endswith("\n") and line.strip() == marker.strip()
                    or not marker.endswith("\n")
                ):
                    failures.append(f"{rel}:{lineno}: git conflict marker '{marker.strip()}'")
                    break


def check_oracle_index_consistency():
    if not ORACLE.exists() or not INDEX.exists():
        return
    oracle_text = ORACLE.read_text(encoding="utf-8")
    index_text = INDEX.read_text(encoding="utf-8")
    # Oracle rules: lines starting with `name` ( and a domain in parens.
    rule_def = re.compile(r"^`([a-z_0-9]+)`\s*\([a-zA-Z_ :]+\):\s*$", re.MULTILINE)
    oracle_rules = set(rule_def.findall(oracle_text))
    # Index rows: markdown table rows starting with | name |
    row = re.compile(r"^\|\s*([a-z_0-9]+)\s*\|", re.MULTILINE)
    index_rules = {m for m in row.findall(index_text) if m not in {"rule"}}
    missing_in_index = sorted(oracle_rules - index_rules)
    missing_in_oracle = sorted(index_rules - oracle_rules)
    for r in missing_in_index:
        failures.append(
            f"CLEAN_BUSINESS_RULES.md: missing index row for Oracle rule '{r}'"
        )
    for r in missing_in_oracle:
        failures.append(
            f"CLEAN_ORACLE.md: index row '{r}' has no matching rule definition"
        )


def check_no_stale_data_paths():
    """data/ moved to legacy/data/ on 2026-05-26. Any present-tense reference to the
    old path outside legacy/data/ is drift."""
    # Match data/<file> but NOT legacy/data/<file>.
    pat = re.compile(r"(?<!legacy/)\bdata/(?:clients\.json|route_template\.md|sources\.md|README\.md)\b")
    skip = {"scripts/check.py"}  # this file mentions the pattern as a literal
    for rel in _tracked("*.md", "*.py", "*.json", "*.sql", "*.astro", "*.mjs", "*.ts", "*.tsx", "*.js", "*.jsx", "*.yml", "*.yaml"):
        if rel in skip:
            continue
        if rel.startswith("legacy/data/"):
            continue
        path = REPO / rel
        if not path.is_file():
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            if pat.search(line):
                # Allow historical-record framing: line explicitly notes the path was
                # data/ at the time and was moved.
                if "was `data/" in line or "(then `data/" in line or "moved 2026-05-26" in line:
                    continue
                failures.append(
                    f"{rel}:{lineno}: stale path reference; use legacy/data/ "
                    f"(the move happened 2026-05-26)"
                )


def check_workflows_no_deleted_branches():
    """Deleted claude/* branches must not be referenced in deploy/CI workflows; a stale
    trigger silently disables deploys when the branch is gone."""
    if not WORKFLOWS.exists():
        return
    for path in sorted(WORKFLOWS.rglob("*.yml")):
        try:
            text = path.read_text(encoding="utf-8")
        except Exception:
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith("-") and "claude/" in stripped:
                failures.append(
                    f"{path.relative_to(REPO)}:{lineno}: references a claude/* branch; "
                    f"only main should trigger workflows"
                )


PAGES = REPO / "src" / "pages"
COMPONENTS = REPO / "src" / "components"
STYLES = REPO / "src" / "styles"


def _read(path):
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return None


def _strip_frontmatter_and_comments(text):
    """Astro frontmatter and HTML comments are not customer-facing copy."""
    if text is None:
        return ""
    body = text
    if body.startswith("---"):
        end = body.find("---", 3)
        if end > 0:
            body = body[end + 3 :]
    body = re.sub(r"<!--.*?-->", "", body, flags=re.DOTALL)
    return body


def check_rule_survival():
    """Lint patterns asserting that each high-risk rule still has its load-bearing
    copy or element on the page that carries it. A redesign that rewrites a page
    must keep these markers (or replace them with equivalents that the patterns
    here recognize). The patterns are deliberately loose: structural markers and
    key phrases, not pixel-level copy. The point is to catch silent rule drops,
    not to freeze wording.

    Each failure names its rule key so a redesigner can look up the source-of-
    truth requirement in CLEAN_ORACLE.md.

    Adding a rule? Add its survival check here at the same commit, per the going-
    forward rule: every new rule lands with its enforcement layer."""
    home = PAGES / "index.astro"
    villages = PAGES / "the-villages.astro"
    process_page = PAGES / "process.astro"
    book = PAGES / "book.astro"
    portal = PAGES / "portal.astro"
    terms = PAGES / "terms.astro"
    nav = COMPONENTS / "Nav.astro"
    global_css = STYLES / "global.css"
    # The portal copy lives in the React island once Phase 1 ships, not
    # in the page shell. Point the portal-control checks at the island.
    portal_app = COMPONENTS / "portal" / "PortalApp.jsx"
    # The booking copy lives in the React island once the funnel ships, not
    # in the page shell. Point the booking-surface checks at the island.
    booking_app = COMPONENTS / "portal" / "BookingApp.jsx"

    def _normalize_ws(text):
        # Collapse all runs of whitespace to a single space so multi-word
        # patterns ("the day before", "two taps") survive line wraps in
        # the source file. Required because Astro pages format prose
        # across multiple lines for readability.
        return re.sub(r"\s+", " ", text)

    # block=True  -> a miss fails the build (legal/safety/money/engineering).
    # block=False -> a miss is a loud warning only (brittle copy/design whose
    #                real teeth live in a durable layer). See the severity
    #                note at the top of this file.
    def require_present(path, pattern, rule_key, label, flags=re.IGNORECASE, block=True):
        text = _read(path)
        bucket = failures if block else warnings
        if text is None:
            bucket.append(f"{path.relative_to(REPO)}: file missing (rule '{rule_key}')")
            return
        if not re.search(pattern, _normalize_ws(text), flags):
            bucket.append(
                f"{path.relative_to(REPO)}: missing required pattern for rule "
                f"'{rule_key}': {label}"
            )

    def require_absent(path, pattern, rule_key, label, flags=re.IGNORECASE, block=True):
        text = _read(path)
        if text is None:
            return
        bucket = failures if block else warnings
        if re.search(pattern, _normalize_ws(text), flags):
            bucket.append(
                f"{path.relative_to(REPO)}: forbidden pattern for rule "
                f"'{rule_key}': {label}"
            )

    # ── villages_only_in_copy ──────────────────────────────────────────────
    # Marketing pages on the Hurricane Bath surface must not name other Florida
    # cities. Ocala is the legacy doggoneclean.us surface; mentioning it here
    # invites questions we cannot answer.
    for page in (home, villages, process_page):
        body = _strip_frontmatter_and_comments(_read(page))
        for forbidden in ("Ocala", "Fernandina", "St. Simons", "Saint Simons"):
            if forbidden in body:
                failures.append(
                    f"{page.relative_to(REPO)}: customer-facing copy mentions "
                    f"'{forbidden}' (rule 'villages_only_in_copy')"
                )

    # ── founders_cap_statement_always_visible ─────────────────────────────
    # The cap must appear in always-visible copy on the city page (not only in
    # the counter element, which is hidden until remaining drops below the
    # threshold). Word 'households' must appear in 2+ places (eyebrow + body).
    body = _strip_frontmatter_and_comments(_read(villages))
    if len(re.findall(r"\bhouseholds\b", body)) < 2:
        warnings.append(
            f"src/pages/the-villages.astro: 'households' appears < 2 times in "
            f"customer-facing copy (rule 'founders_cap_statement_always_visible'); "
            f"the founders cap must be in always-visible copy, not only in the "
            f"hidden counter element"
        )

    # ── single_visit_as_own_path ──────────────────────────────────────────
    # The city page must offer a single-visit CTA at its own URL, not as a row
    # buried inside a recurring pricing card.
    # The single-visit path is a locked decision with no durable home but this
    # guard; the CTA href is structure (a URL, not prose) -> BLOCK, so a
    # redesign that buries the trial path cannot ship.
    require_present(
        villages,
        r"/book\?plan=single",
        "single_visit_as_own_path",
        "single-visit CTA href '/book?plan=single'",
    )

    # ── specialist_named_not_promised ─────────────────────────────────────
    # The page must include a specialist section (a name + a place for a photo)
    # AND must not over-promise that any one operator will always be the one.
    require_present(
        villages,
        r'class="specialist-card"',
        "specialist_named_not_promised",
        "specialist section (class='specialist-card')",
        block=False,
    )
    for forbidden in ("always Paul", "always be Paul", "will be Paul", "only Paul", "you will always see Paul"):
        require_absent(
            villages,
            forbidden,
            "specialist_named_not_promised",
            f"over-promising phrase '{forbidden}' (the rule forbids locking in any one operator)",
        )

    # ── appointment_block_not_window ──────────────────────────────────────
    # Cable-company "arrival window" language must not appear on the marketing
    # pages. The page uses "block" instead.
    for page in (home, villages, process_page):
        require_absent(
            page,
            r"arrival window",
            "appointment_block_not_window",
            "'arrival window' (use 'block' instead)",
        )

    # ── language_bank ─────────────────────────────────────────────────────
    # The 'standard belongs to the process' line is a locked language-bank
    # entry. The Process page is its most central expression.
    require_present(
        process_page,
        r"belongs to the process",
        "language_bank",
        "the 'belongs to the process' line",
        block=False,
    )

    # ── neural_expressive_design ──────────────────────────────────────────
    # The brand color tokens must be defined in global.css. A redesign that
    # replaces global.css with a new system cannot drop these tokens silently.
    css = _read(global_css)
    if css is None:
        warnings.append(
            "src/styles/global.css: missing (rule 'neural_expressive_design')"
        )
    else:
        for token in ("--accent", "--accent2", "--ink", "--bg"):
            if token not in css:
                warnings.append(
                    f"src/styles/global.css: missing brand token '{token}' "
                    f"(rule 'neural_expressive_design')"
                )

    # ── nav_no_backdrop_filter ────────────────────────────────────────────
    # Never use backdrop-filter on the scrolled nav. Causes a dashed-line
    # rendering artifact on Android/Chrome. Use solid rgba background.
    require_absent(
        nav,
        r"backdrop-filter",
        "nav_no_backdrop_filter",
        "'backdrop-filter' (causes dashed-line artifact on Android/Chrome; use solid rgba background)",
    )

    # ── stop_sign_two_taps ────────────────────────────────────────────────
    # Oracle: marketed on four surfaces (homepage, booking step 2,
    # booking step 4, portal control). On the current site set, the
    # home page, the city page, the booking entry, the terms page,
    # and the portal React island each carry "two taps".
    for page in (home, villages, booking_app, terms, portal_app):
        require_present(
            page,
            r"two taps",
            "stop_sign_two_taps",
            "'two taps' (Oracle: stop-sign cancel marketed on four surfaces)",
        )

    # ── auto_charge_at_24h ────────────────────────────────────────────────
    # The customer-facing promise is "charged the day before, never sooner."
    # Required wherever the bath surface discusses billing.
    for page in (villages, booking_app, terms):
        require_present(
            page,
            r"the day before",
            "auto_charge_at_24h",
            "'the day before' (the customer-facing 24-hour charge promise)",
        )

    # ── within_24h_non_refundable ─────────────────────────────────────────
    # The customer-facing terms must say what happens once the visit enters
    # the 24-hour window: card charged, appointment locked, non-refundable.
    for page in (villages, terms):
        require_present(
            page,
            r"24[ -]hour",
            "within_24h_non_refundable",
            "'24 hour' (the locked-and-charged window must be stated)",
        )
    require_present(
        terms,
        r"non[- ]refundable",
        "within_24h_non_refundable",
        "'non-refundable' (the within-24h payment status must be stated in terms)",
    )

    # three_dog_cap: no cap to assert. The borrowed Villages-residency number
    # was lifted 2026-06-07 (migration 0017); dog_count is bounded only by
    # >= 1 (DB CHECK + RPC), and pricing scales per dog. Nothing customer-facing
    # states a count limit.

    # ── friendly_dogs_only ────────────────────────────────────────────────
    # Safety boundary must be visible on the customer-facing site, not
    # only buried in intake. Home page carries the safety section; the
    # city page carries it in eligibility.
    for page in (home, villages):
        require_present(
            page,
            r"friendly dogs",
            "friendly_dogs_only",
            "'friendly dogs' (the safety boundary)",
        )
        require_present(
            page,
            r"aggression",
            "friendly_dogs_only",
            "'aggression' (the negation half of the safety boundary)",
        )

    # ── premium_inclusive_no_addons ───────────────────────────────────────
    # One price per tier, no upsells. The page must say it.
    require_present(
        villages,
        r"no add ons",
        "premium_inclusive_no_addons",
        "'no add ons' (premium-inclusive pricing must be stated)",
        block=False,
    )

    # ── cadence_4wk_or_2wk_same_price ─────────────────────────────────────
    # 4wk default, 2wk freshness upgrade at the same price. The "same
    # price" framing is the rule's point and must be communicated.
    require_present(
        home,
        r"same price",
        "cadence_4wk_or_2wk_same_price",
        "'same price' (the 2-week cadence is freshness, not a different rate)",
        block=False,
    )

    # ── card_on_file_at_signup ────────────────────────────────────────────
    # Card-on-file at booking is the model. Customers learn about it
    # before they enter the flow.
    for page in (villages, booking_app, terms):
        require_present(
            page,
            r"card on file",
            "card_on_file_at_signup",
            "'card on file' (signup requires it; customer should expect it)",
        )

    # ── core_is_no_haircut_dogs ───────────────────────────────────────────
    # Bath only. The page must say so where eligibility is discussed.
    for page in (villages, process_page):
        require_present(
            page,
            r"bath only",
            "core_is_no_haircut_dogs",
            "'bath only' (we do not do haircuts)",
            block=False,
        )

    # ── bath_only_no_mats ─────────────────────────────────────────────────
    # Customer-facing eligibility: the tier names must be present (they
    # are the eligibility lens), and a yes/no eligibility distinction
    # must be visible.
    require_present(
        villages,
        r"Smoothcoat",
        "bath_only_no_mats",
        "'Smoothcoat' tier name (eligibility classifier)",
        block=False,
    )
    require_present(
        villages,
        r"Doublecoat",
        "bath_only_no_mats",
        "'Doublecoat' tier name (eligibility classifier)",
        block=False,
    )
    require_present(
        villages,
        r"[Ww]e bath",
        "bath_only_no_mats",
        "'we bath' (the eligibility yes header)",
        block=False,
    )
    require_present(
        villages,
        r"[Ww]e do not bath",
        "bath_only_no_mats",
        "'we do not bath' (the eligibility no header)",
        block=False,
    )

    # ── no_dgn_import ─────────────────────────────────────────────────────
    # DGN's nail vocabulary must not appear on Clean's bath surface.
    # Scoped to customer-facing pages and components; the Field Manual
    # and other internal docs can mention these terms internally.
    dgn_nail_vocab = [
        (r"rotary tool", "rotary tool"),
        (r"sculpt nails", "sculpt nails"),
        (r"grind nails", "grind nails"),
    ]
    customer_pages = [home, villages, process_page, book, booking_app, portal, terms,
                      PAGES / "privacy.astro", PAGES / "sms.astro"]
    for page in customer_pages:
        for pat, label in dgn_nail_vocab:
            require_absent(
                page, pat, "no_dgn_import",
                f"DGN nail vocab '{label}' (Clean is bath only, not nails)",
            )

    # ── no_jargon ─────────────────────────────────────────────────────────
    # Corporate jargon must not appear in customer-facing copy. "free up"
    # is scoped to its banned context "free up the slot" to avoid
    # tripping on legitimate sentences like "free up your weekend."
    jargon = [
        (r"\breach out\b", "'reach out'"),
        (r"\bcircle back\b", "'circle back'"),
        (r"\bbandwidth\b", "'bandwidth' as a corporate noun"),
        (r"free up the slot", "'free up the slot'"),
    ]
    for page in customer_pages:
        for pat, label in jargon:
            require_absent(page, pat, "no_jargon", label)

    # ── reminder_voice ────────────────────────────────────────────────────
    # The banned-phrase list from `reminder_voice`. "Arrival window" is
    # already covered by `appointment_block_not_window` so it is not
    # duplicated here.
    reminder_banned = [
        (r"friendly reminder", "'friendly reminder'"),
        (r"just a reminder", "'just a reminder'"),
        (r"reaching out", "'reaching out'"),
        (r"please be advised", "'please be advised'"),
        (r"\blast chance\b", "'last chance'"),
        (r"make changes now", "'make changes now'"),
    ]
    for page in customer_pages:
        for pat, label in reminder_banned:
            require_absent(page, pat, "reminder_voice", label)

    # ── founders_spots_remaining_counter ──────────────────────────────────
    # The counter element must exist on /the-villages even though its
    # display is gated until remaining drops below the threshold. A
    # redesign that drops the element means the counter never lights up
    # when sign-ups roll in.
    require_present(
        villages,
        r'id="launch-spot-count"',
        "founders_spots_remaining_counter",
        "'id=\"launch-spot-count\"' element (the counter target)",
        flags=0,
        block=False,
    )

    # ── Booking-surface rule survival ─────────────────────────────────────
    # These four rules shipped 2026-05-29 as copy/logic living ONLY inside the
    # booking island. The marketing-page lints above do not cover the funnel,
    # so a redesign of BookingApp.jsx could drop them silently. Each one is the
    # actual gate or framing the customer hits while booking; lint it where it
    # lives.

    # ── octane_selector_cadence_picker ────────────────────────────────────
    # Booking step 2 presents the three cadences and carries the locked
    # "Want your dog fresher?" framing (freshness as the upgrade, not savings).
    # Split by survival: the DECISION (three cadences are offered) has no DB/RPC
    # home, so this guard is its only durable layer -> BLOCK, so a redesign that
    # drops the picker cannot ship until it is restored. The exact tagline
    # WORDING is prose -> WARN, so a rewrite never blocks a deploy.
    for lab in ("Every 4 weeks", "Every 2 weeks", "Single visit"):
        require_present(
            booking_app, re.escape(lab),
            "octane_selector_cadence_picker", f"cadence option '{lab}'",
        )
    require_present(
        booking_app,
        r"want your dog fresher",
        "octane_selector_cadence_picker",
        "the locked 'Want your dog fresher?' tagline wording",
        block=False,
    )

    # ── friendly_dogs_only (booking gate) ─ SAFETY: BLOCK ─────────────────
    require_present(booking_app, r"friendly dogs", "friendly_dogs_only",
                    "'friendly dogs' on the booking gate")
    require_present(booking_app, r"aggression", "friendly_dogs_only",
                    "'aggression' on the booking gate")

    # ── service_area_enforced_server_side (no manual address path) ────────
    # The gate is autocomplete + the in-area polygon ONLY. A manual-entry path
    # is the unverified hole the rule forbids (an address we cannot verify is
    # in-area must not be bookable). Fail the build if it creeps back into the
    # booking island; the server reject (migration 0009) is the durable teeth,
    # this guard keeps the page from re-opening the hole in a redesign.
    require_absent(booking_app, r"enter it manually", "service_area_enforced_server_side",
                   "a manual-address-entry link in the booking flow (autocomplete + polygon only)")
    require_absent(booking_app, r"confirm your address is on the route before your first visit",
                   "service_area_enforced_server_side",
                   "the 'confirm later' manual-address punt copy in the booking flow")

    # ── core_is_no_haircut_dogs / bath_only_no_mats (booking eligibility) ──
    # Eligibility copy; the coat-tier teeth are the DB CHECK + the RPC. WARN.
    require_present(booking_app, r"bath only", "core_is_no_haircut_dogs",
                    "'bath only' on the booking eligibility gate", block=False)
    require_present(booking_app, r"Smoothcoat", "bath_only_no_mats",
                    "'Smoothcoat' tier on the booking coat picker", block=False)
    require_present(booking_app, r"Doublecoat", "bath_only_no_mats",
                    "'Doublecoat' tier on the booking coat picker", block=False)

    # ── premium_inclusive_no_addons (booking surface) ─────────────────────
    # One price per tier, no upsell may be introduced into the funnel. Catch a
    # priced add-on ("Deshed add-on $15") or a "+ $N" upcharge, without
    # tripping on a legitimate "no add ons" reassurance line.
    require_absent(booking_app, r"add[- ]?on[^.]{0,40}\$\d", "premium_inclusive_no_addons",
                   "a priced add-on in the booking flow (one price per tier, no upsells)")
    require_absent(booking_app, r"\+\s?\$\d", "premium_inclusive_no_addons",
                   "a '+ $N' upcharge in the booking flow (no per-visit extras)")

    # ── supabase_rpc_not_raw_fetch ────────────────────────────────────────
    # Forbid `fetch(...SUPABASE_URL...)` in portal code: this is the raw
    # REST call pattern that causes auth-lock conflicts. Edge function
    # calls via `callPortalEdge()` go through the supabase client's
    # `.functions.invoke()` or a separate session-token path and do not
    # match this pattern, so legitimate calls are not flagged.
    portal_dir = COMPONENTS / "portal"
    if portal_dir.exists():
        for path in sorted(portal_dir.rglob("*.js*")):
            if not path.is_file():
                continue
            text = _read(path)
            if text is None:
                continue
            normalized = re.sub(r"\s+", " ", text)
            if re.search(r"fetch\([^)]*SUPABASE_URL", normalized):
                failures.append(
                    f"{path.relative_to(REPO)}: forbidden pattern for rule "
                    f"'supabase_rpc_not_raw_fetch': raw fetch() against "
                    f"SUPABASE_URL (use sb().rpc() / sb().from() instead; "
                    f"raw fetch causes auth-lock conflicts)"
                )

    # ── auth_listener_sets_state_only ─────────────────────────────────────
    # The onAuthStateChange callback must set state only. Network calls
    # (.from(...), await fetch(...)) inside the callback recurse into
    # the same auth-lock conflict. Scan portal code for these patterns
    # inside an onAuthStateChange( ... ) block.
    if portal_dir.exists():
        for path in sorted(portal_dir.rglob("*.js*")):
            if not path.is_file():
                continue
            text = _read(path)
            if text is None:
                continue
            # Locate each onAuthStateChange( ... ) block by paren-matching.
            for m in re.finditer(r"onAuthStateChange\s*\(", text):
                depth = 1
                i = m.end()
                while i < len(text) and depth > 0:
                    if text[i] == "(":
                        depth += 1
                    elif text[i] == ")":
                        depth -= 1
                    i += 1
                block = text[m.end() : i]
                forbidden_in_block = [
                    (r"\.from\(", ".from() database call"),
                    (r"\.rpc\(", ".rpc() database call"),
                    (r"\bawait\s+fetch\b", "await fetch() network call"),
                    (r"loadPortalData\(", "loadPortalData() network call"),
                ]
                for pat, label in forbidden_in_block:
                    if re.search(pat, block):
                        line = text.count("\n", 0, m.start()) + 1
                        failures.append(
                            f"{path.relative_to(REPO)}:{line}: forbidden pattern for "
                            f"rule 'auth_listener_sets_state_only': {label} inside "
                            f"onAuthStateChange callback (set state only; do network "
                            f"calls in a separate useEffect that watches auth state)"
                        )


def main():
    check_clients()
    check_dashes()
    check_route_excludes()
    check_dog_grooming()
    check_no_conflict_markers()
    check_oracle_index_consistency()
    check_no_stale_data_paths()
    check_workflows_no_deleted_branches()
    check_rule_survival()
    if warnings:
        print(f"AUDIT WARNINGS ({len(warnings)}): redesign-fragile copy/design drift. "
              f"Does NOT block the build; the rule's real enforcement is its durable "
              f"layer (DB / RPC / data). Fix the copy or update the pattern:")
        for w in warnings:
            print(f"  ~ {w}")
        print()
    if failures:
        print(f"AUDIT FAIL ({len(failures)} issue(s)): broken data, structural drift, or a "
              f"legal / safety / money / engineering rule. These block the build:")
        for f in failures:
            print(f"  - {f}")
        sys.exit(1)
    print("AUDIT PASS: data valid, no dashes, Oracle/index in sync, no conflict markers, "
          "no stale paths, workflows clean, blocking rule-survival checks green"
          + (f" ({len(warnings)} non-blocking warning(s) above)." if warnings else "."))
    sys.exit(0)


if __name__ == "__main__":
    main()
