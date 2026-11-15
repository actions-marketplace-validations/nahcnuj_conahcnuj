#!/usr/bin/env bash
# Print the bot account user ID (<slug>[bot]) for noreply email attribution.
# Order: BOT_USER_ID from app.env when set to a real value, then the
# persistent cache (bot IDs are immutable), then the public GitHub API
# (no auth needed). Exits non-zero with guidance when none works.
# APP_ID is never a fallback: it is the App's own ID and never attributes
# commits to the bot account.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${DIR}/app.env"
if [[ ! -f "${ENV_FILE}" && -f "${DIR}/app.env.example" ]]; then
  ENV_FILE="${DIR}/app.env.example"
fi

# Preserve an APP_SLUG already resolved by the caller (e.g. setup-git.sh) so a
# placeholder in app.env cannot clobber it.
_APP_SLUG_ENV="${APP_SLUG:-}"
set -a
# shellcheck source=gh-app/app.env.example
. "${ENV_FILE}"
set +a
if [[ ( -z "${APP_SLUG:-}" || "${APP_SLUG}" == "<"* ) && -n "${_APP_SLUG_ENV}" && "${_APP_SLUG_ENV}" != "<"* ]]; then
  APP_SLUG="${_APP_SLUG_ENV}"
fi

API_BASE="${GH_APP_API_BASE:-https://api.github.com}"
CACHE_FILE="${DIR}/bot-id.cache"

ID="${BOT_USER_ID:-}"
if [[ -n "${ID}" && "${ID}" != "<"* ]]; then
  printf '%s' "${ID}"
  exit 0
fi

if [[ -f "${CACHE_FILE}" ]]; then
  CACHED="$(tr -d '\n \t' < "${CACHE_FILE}")"
  if [[ "${CACHED}" =~ ^[0-9]+$ ]]; then
    printf '%s' "${CACHED}"
    exit 0
  fi
fi

if [[ -z "${APP_SLUG:-}" || "${APP_SLUG}" == "<"* ]]; then
  echo "ERROR: BOT_USER_ID is not set and APP_SLUG is missing." >&2
  echo "Set BOT_USER_ID to the bot account user ID" >&2
  echo "(gh api users/<slug>%5Bbot%5D --jq .id), not APP_ID." >&2
  exit 1
fi

_AUTH_HEADER=()
if [[ -n "${GH_TOKEN:-}" ]]; then
  _AUTH_HEADER=(-H "Authorization: Bearer ${GH_TOKEN}")
elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
  _AUTH_HEADER=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
elif [[ -n "${APP_ID:-}" && "${APP_ID}" != "<"* && -f "${DIR}/get-token.sh" ]]; then
  # No ambient token: mint a short-lived installation token from the App's
  # own credentials so the lookup is authenticated (higher rate limit, and
  # works on runner IPs that exhaust the unauthenticated quota). Best-effort;
  # a missing key or no network leaves _AUTH_HEADER empty.
  _MINTED="$(bash "${DIR}/get-token.sh" 2>/dev/null || true)"
  if [[ -n "${_MINTED}" && "${_MINTED}" != "ERROR"* ]]; then
    _AUTH_HEADER=(-H "Authorization: Bearer ${_MINTED}")
  fi
fi
# -g keeps the encoded [bot] out of curl's URL globbing, and lets the offline
# tests serve the same URL from a file:// fixture.
LOOKUP="$(curl -g -fsSL ${_AUTH_HEADER[@]+"${_AUTH_HEADER[@]}"} -H "Accept: application/vnd.github+json" "${API_BASE}/users/${APP_SLUG}%5Bbot%5D" 2>/dev/null || true)"
# REST answers pretty-printed (a space after the colon), so read the separator
# the way REST actually emits it instead of assuming compact JSON. Take the
# first "id" (the top-level one) so a later field cannot shadow it.
ID="$(printf '%s' "${LOOKUP}" | grep -oE '"id"[[:space:]]*:[[:space:]]*[0-9]+' | head -n 1 | grep -oE '[0-9]+$' || true)"
if [[ -z "${ID}" ]]; then
  echo "ERROR: cannot resolve bot user ID for ${APP_SLUG}[bot] (offline?)." >&2
  echo "Set BOT_USER_ID to the bot account user ID" >&2
  echo "(gh api users/${APP_SLUG}%5Bbot%5D --jq .id), not APP_ID." >&2
  exit 1
fi
printf '%s' "${ID}" > "${CACHE_FILE}" 2>/dev/null || true
printf '%s' "${ID}"
