#!/usr/bin/env bash
# action.yml is a setup script, not the old `exit 255` stub: it verifies the
# Getting started steps (App secrets, installation token, slug, bot id,
# optional auto-merge) and exits 0 when the repository is ready. setup.yml
# exposes the same check as a reusable workflow (workflow_call) so callers do
# not need a copy of the driver. This test pins that contract offline.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "${HERE}/.." && pwd)"
ACTION="${REPO}/action.yml"
SETUP="${REPO}/.github/workflows/setup.yml"

[[ -f "${ACTION}" ]] || { echo "FAIL: missing ${ACTION}" >&2; exit 1; }
[[ -f "${SETUP}" ]] || { echo "FAIL: missing ${SETUP}" >&2; exit 1; }

# The stub must be gone and the action must be composite.
if grep -q 'exit 255' "${ACTION}"; then
  echo "FAIL: action.yml still contains the exit 255 stub" >&2
  exit 1
fi
grep -Eq '^[[:space:]]*using:[[:space:]]*composite' "${ACTION}" \
  || { echo "FAIL: action.yml must be a composite action" >&2; exit 1; }

# GitHub does not expose the `secrets` context to composite actions (using it
# is a parse error, so nothing runs). Secrets must arrive through inputs.
if grep -Eq '\$\{\{[[:space:]]*secrets\.' "${ACTION}"; then
  echo "FAIL: action.yml must not read the secrets context; pass secrets as inputs" >&2
  exit 1
fi

# Getting started step 3: the three required secrets are checked.
for name in APP_ID INSTALLATION_ID PRIVATE_KEY; do
  grep -q "${name}" "${ACTION}" \
    || { echo "FAIL: action.yml does not check ${name}" >&2; exit 1; }
done

# Getting started steps 1-3: token/slug/bot checks prove the App exists and is
# installed on the repository.
for script in get-token.sh app-slug.sh bot-user-id.sh; do
  grep -q "${script}" "${ACTION}" \
    || { echo "FAIL: action.yml does not run ${script}" >&2; exit 1; }
done

# Getting started step 4: auto-merge is checked (optional, warned, not failed).
grep -q 'allow_auto_merge' "${ACTION}" \
  || { echo "FAIL: action.yml does not check allow_auto_merge" >&2; exit 1; }

# Readiness means normal termination, explicitly.
grep -Eq '^[[:space:]]*exit 0[[:space:]]*$' "${ACTION}" \
  || { echo "FAIL: action.yml must exit 0 when the setup is ready" >&2; exit 1; }

# setup.yml is a reusable workflow carrying the same check.
grep -Eq '^[[:space:]]*workflow_call:' "${SETUP}" \
  || { echo "FAIL: setup.yml must be callable as a reusable workflow" >&2; exit 1; }
for name in APP_ID INSTALLATION_ID PRIVATE_KEY; do
  grep -q "${name}" "${SETUP}" \
    || { echo "FAIL: setup.yml does not accept the ${name} secret" >&2; exit 1; }
done
grep -Eq '^[[:space:]]*uses:[[:space:]]*\./$' "${SETUP}" \
  || { echo "FAIL: setup.yml must run the root action with 'uses: ./'" >&2; exit 1; }
for name in APP_ID INSTALLATION_ID PRIVATE_KEY; do
  grep -q "secrets.${name}" "${SETUP}" \
    || { echo "FAIL: setup.yml must pass secrets.${name} to the action" >&2; exit 1; }
done

# Checkout in the reusable workflow must be pinned to a full-length SHA, like
# every other actions/* reference in this repository.
if ! grep -Eq 'uses:[[:space:]]*actions/checkout@[0-9a-f]{40}[[:space:]]*$' "${SETUP}"; then
  echo "FAIL: setup.yml checkout must be pinned to a full-length SHA" >&2
  exit 1
fi

echo "action setup test passed"
