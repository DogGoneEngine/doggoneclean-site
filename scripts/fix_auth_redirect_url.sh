#!/usr/bin/env bash
#
# Fix Dog Gone Clean sign-in (dgc-prod Supabase Auth URL config).
#
# Why: the Auth "Site URL" was saved with a typo ("http://hurricane bath.com",
# note the space), so after a Google sign-in the auth server tried to send the
# client back to an unparseable address and threw a 500. It broke Google sign-in
# for every client. This sets the Site URL and redirect allowlist to the correct
# https://hurricanebath.com through the Supabase Management API. Idempotent: safe
# to run more than once, it just re-applies the same correct values.
#
# Run on the Chromebook Linux terminal:
#   1) One time only, create a Supabase access token:
#        https://supabase.com/dashboard/account/tokens  ->  "Generate new token"
#      (Reuse it next time instead of making a new one.)
#   2) export SUPABASE_PAT="paste-the-token-here"
#   3) bash scripts/fix_auth_redirect_url.sh
#
set -euo pipefail

REF="urebdrosrxejhubpbxsa"                 # dgc-prod
SITE_URL="https://hurricanebath.com"
ALLOW_LIST="https://hurricanebath.com/**"
API="https://api.supabase.com/v1/projects/${REF}/config/auth"

if [ -z "${SUPABASE_PAT:-}" ]; then
  echo "Set your Supabase token first, then run again:" >&2
  echo "  export SUPABASE_PAT=\"sbp_...\"" >&2
  echo "Create one at https://supabase.com/dashboard/account/tokens" >&2
  exit 1
fi

show() {
  python3 -c 'import sys,json
try:
    d=json.load(sys.stdin)
except Exception:
    print("  (could not read the response)"); sys.exit(0)
if "site_url" not in d:
    print("  unexpected response:", d); sys.exit(0)
print("  Site URL      :", repr(d.get("site_url")))
print("  Redirect list :", repr(d.get("uri_allow_list")))'
}

echo "== BEFORE (what is saved now) =="
curl -s -H "Authorization: Bearer ${SUPABASE_PAT}" "${API}" | show

echo
echo "== APPLYING FIX =="
curl -s -X PATCH "${API}" \
  -H "Authorization: Bearer ${SUPABASE_PAT}" \
  -H "Content-Type: application/json" \
  -d "{\"site_url\":\"${SITE_URL}\",\"uri_allow_list\":\"${ALLOW_LIST}\"}" | show

echo
echo "== AFTER (what is saved now) =="
curl -s -H "Authorization: Bearer ${SUPABASE_PAT}" "${API}" | show

echo
echo "Done. If the AFTER lines show https://hurricanebath.com with no space,"
echo "Google sign-in is fixed. Have someone try it, then tell Claude to check the auth logs."
