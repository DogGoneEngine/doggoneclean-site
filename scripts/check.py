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

Run: python3 scripts/check.py
Exit code 0 = all checks pass, 1 = at least one failure.
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

failures = []


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
    nav = COMPONENTS / "Nav.astro"
    global_css = STYLES / "global.css"

    def require_present(path, pattern, rule_key, label, flags=0):
        text = _read(path)
        if text is None:
            failures.append(f"{path.relative_to(REPO)}: file missing (rule '{rule_key}')")
            return
        if not re.search(pattern, text, flags):
            failures.append(
                f"{path.relative_to(REPO)}: missing required pattern for rule "
                f"'{rule_key}': {label}"
            )

    def require_absent(path, pattern, rule_key, label, flags=re.IGNORECASE):
        text = _read(path)
        if text is None:
            return
        if re.search(pattern, text, flags):
            failures.append(
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
        failures.append(
            f"src/pages/the-villages.astro: 'households' appears < 2 times in "
            f"customer-facing copy (rule 'founders_cap_statement_always_visible'); "
            f"the founders cap must be in always-visible copy, not only in the "
            f"hidden counter element"
        )

    # ── single_visit_as_own_path ──────────────────────────────────────────
    # The city page must offer a single-visit CTA at its own URL, not as a row
    # buried inside a recurring pricing card.
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
    )

    # ── neural_expressive_design ──────────────────────────────────────────
    # The brand color tokens must be defined in global.css. A redesign that
    # replaces global.css with a new system cannot drop these tokens silently.
    css = _read(global_css)
    if css is None:
        failures.append(
            "src/styles/global.css: missing (rule 'neural_expressive_design')"
        )
    else:
        for token in ("--accent", "--accent2", "--ink", "--bg"):
            if token not in css:
                failures.append(
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
    if failures:
        print(f"AUDIT FAIL ({len(failures)} issue(s)):")
        for f in failures:
            print(f"  - {f}")
        sys.exit(1)
    print("AUDIT PASS: clients.json valid, no dashes, Oracle/index in sync, no conflict markers, no stale paths, workflows clean, rule-survival lint green.")
    sys.exit(0)


if __name__ == "__main__":
    main()
