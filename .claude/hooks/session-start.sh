#!/bin/bash
# SessionStart hook for Dog Gone Clean.
#
# The real problem this solves: every prior bad session started on a stale
# claude/* branch (whichever one the harness happened to spin up on) and worked
# against the Scroll it found there, which was a frozen-in-amber view of the
# world. The session then "helpfully" re-decided things that had already been
# settled on main. From Paul's seat that looked like sabotage.
#
# This hook makes every session orient off reality from turn one:
#   1. Fetch origin.
#   2. If on a claude/* branch that is just an ancestor of main, fast-forward
#      to main (the branch was a stale starting point, not real work).
#   3. If on a claude/* branch that has real unmerged commits, stay on it but
#      print a loud warning so the session knows it is NOT on the trunk.
#   4. If on main, fast-forward to origin/main.
#   5. Print the latest commit and the Scroll's current focus block so the
#      session orients off real state instead of the file system.
#   6. Install npm deps (Astro site needs them to build) and run scripts/check.py
#      so the session knows the docs lint clean before any edits.
#
# Idempotent. Non-interactive. Runs only in the remote/web environment.

set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

echo "=== Dog Gone Clean session orient ==="

# 1. Fetch origin.
git fetch --prune origin 2>&1 | tail -3 || echo "warning: git fetch failed; continuing"

# 2-4. Orient the branch.
current_branch=$(git rev-parse --abbrev-ref HEAD)
echo "current branch: $current_branch"

if [ "$current_branch" = "main" ]; then
  git merge --ff-only origin/main 2>&1 | tail -2 || true
elif [[ "$current_branch" == claude/* ]]; then
  # Is this branch ahead of main with real work, or just a stale snapshot?
  ahead=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo "0")
  if [ "$ahead" = "0" ]; then
    echo "branch is behind main with no unique commits; switching to main"
    git checkout main
    git merge --ff-only origin/main 2>&1 | tail -2 || true
  else
    echo ""
    echo "!!  this claude/* branch has $ahead commit(s) NOT in main."
    echo "!!  staying on it. merge to main when work is shipped."
    echo ""
  fi
fi

# 5. Print the real state.
echo ""
echo "--- latest commit ---"
git log -1 --format="%h %ai %s"
echo ""
echo "--- Scroll current focus / next action ---"
if [ -f CLEAN_SCROLL_OF_HEPHAESTUS.md ]; then
  awk '
    /^## Current focus \/ next action/ { p=1; print; next }
    p && /^---$/ { exit }
    p { print }
  ' CLEAN_SCROLL_OF_HEPHAESTUS.md
fi
echo ""

# 6. Dependencies + check.
if [ -f package.json ]; then
  echo "--- installing npm deps ---"
  npm install --no-audit --no-fund --silent || echo "warning: npm install failed"
fi

if [ -f scripts/check.py ]; then
  echo "--- running scripts/check.py (full audit) ---"
  if ! python3 scripts/check.py; then
    echo ""
    echo "!!  AUDIT FAILED. The repo is in a drifted state. Fix the issues above"
    echo "!!  before doing any other work. Do not edit docs or ship code until the"
    echo "!!  audit passes."
    echo ""
  fi
fi

# Install the pre-commit hook so every commit from this session runs the same audit.
# Idempotent: re-running this just overwrites with the current content.
if [ -d .git/hooks ] && [ -f scripts/check.py ]; then
  cat > .git/hooks/pre-commit << 'PRECOMMIT'
#!/bin/bash
# Auto-installed by .claude/hooks/session-start.sh. Runs the full audit before every commit.
exec python3 scripts/check.py
PRECOMMIT
  chmod +x .git/hooks/pre-commit
fi

echo ""
echo "=== orient complete. read CLAUDE.md, then the Scroll, then CLEAN_ORACLE.md. ==="
