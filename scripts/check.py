#!/usr/bin/env python3
"""Local checks for the Clean repo. No database, no dependencies.

Enforces the rules that are enforceable today:
- clients.json parses and every standing record has the required fields
  (service_type_required, data_gap_explicit, hardness present).
- service_type is one of the allowed values.
- banned clients carry exclude_from_everything (banned_excluded).
- no em dashes or en dashes in tracked .md / .json files (no_em_dashes).

Run: python3 scripts/check.py
Exit code 0 = all checks pass, 1 = at least one failure.
"""

import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CLIENTS = REPO / "data" / "clients.json"
ROUTE = REPO / "data" / "route_template.md"

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


def main():
    check_clients()
    check_dashes()
    check_route_excludes()
    if failures:
        print(f"CHECK FAILED ({len(failures)} issue(s)):")
        for f in failures:
            print(f"  - {f}")
        sys.exit(1)
    print("CHECK PASSED: clients.json valid, no em/en dashes in tracked docs.")
    sys.exit(0)


if __name__ == "__main__":
    main()
