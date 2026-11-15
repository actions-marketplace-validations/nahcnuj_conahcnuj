#!/usr/bin/env bash
# bot-user-id.sh: app.env value wins (no network), then the cache, then the
# public lookup. The lookup is exercised offline from a file:// fixture that
# carries GitHub's pretty-printed REST spacing.
# Usage: bash bot-user-id.sh <staged gh-app dir>
set -euo pipefail

STAGE="${1:?staged gh-app dir required}"

# Staged env has no BOT_USER_ID: point the lookup at an unreachable base so
# it fails fast offline with guidance instead of hanging on DNS.
OUT="$(GH_APP_API_BASE="http://127.0.0.1:9" bash "${STAGE}/bot-user-id.sh" 2>&1 || true)"
if [[ "${OUT}" != *"BOT_USER_ID"* ]]; then
  echo "FAIL: unresolved ID should print guidance:" >&2
  echo "${OUT}" >&2
  exit 1
fi
echo "PASS bot-user-id.sh fails with guidance when unresolvable"

printf '\nBOT_USER_ID=12345\n' >> "${STAGE}/app.env"
OUT="$(bash "${STAGE}/bot-user-id.sh")"
if [[ "${OUT}" != "12345" ]]; then
  echo "FAIL: env value should win, got '${OUT}'" >&2
  exit 1
fi
echo "PASS bot-user-id.sh prefers app.env value (no network)"

# Seeded cache wins over the (unreachable) API without network.
sed -i '/^BOT_USER_ID=/d' "${STAGE}/app.env"
printf '777' > "${STAGE}/bot-id.cache"
OUT="$(GH_APP_API_BASE="http://127.0.0.1:9" bash "${STAGE}/bot-user-id.sh")"
if [[ "${OUT}" != "777" ]]; then
  echo "FAIL: cache should win, got '${OUT}'" >&2
  exit 1
fi
echo "PASS bot-user-id.sh prefers cache (no network)"

# The lookup path itself, offline: GitHub REST answers pretty-printed (a space
# after the colon), which a compact-only parser finds nothing in. Serve the
# same URL from a file:// fixture and require the top-level "id".
WORK="$(dirname "${STAGE}")/bot-user-id-work"
mkdir -p "${WORK}/users"
cp "${STAGE}/bot-user-id.sh" "${WORK}/"
cat > "${WORK}/app.env" <<'EOF'
APP_SLUG="conahcnuj"
EOF
printf '{\n  "login": "conahcnuj[bot]",\n  "id": 331119074\n}\n' > "${WORK}/users/conahcnuj[bot]"
# curl must support file:// and --globoff (the URL carries %5B / %5D).
if curl -g -fsSL "file://${WORK}/users/conahcnuj%5Bbot%5D" >/dev/null 2>&1; then
  OUT="$(GH_APP_API_BASE="file://${WORK}" GH_TOKEN='' GITHUB_TOKEN='' bash "${WORK}/bot-user-id.sh")"
  if [[ "${OUT}" != "331119074" ]]; then
    echo "FAIL: pretty-printed REST lookup returned '${OUT}', expected 331119074" >&2
    exit 1
  fi
  echo "PASS bot-user-id.sh parses a pretty-printed REST lookup (no network)"
else
  echo "SKIP bot-user-id.sh lookup (curl has no file:// support)"
fi
