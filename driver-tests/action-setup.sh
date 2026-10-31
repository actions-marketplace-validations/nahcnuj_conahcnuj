#!/usr/bin/env bash
# action.yml is a setup script: it verifies the Getting started steps (App
# secrets, installation token, slug, bot id, optional auto-merge) and exits 0
# when the repository is ready. setup.yml exposes the same check as a reusable
# workflow. This test exercises the run blocks' behaviour end-to-end with
# mocked scripts and gh, rather than just grepping the YAML.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "${HERE}/.." && pwd)"
ACTION="${REPO}/action.yml"
SETUP="${REPO}/.github/workflows/setup.yml"

[[ -f "${ACTION}" ]] || { echo "FAIL: missing ${ACTION}" >&2; exit 1; }
[[ -f "${SETUP}" ]] || { echo "FAIL: missing ${SETUP}" >&2; exit 1; }

ROOT="$(mktemp -d)"
trap 'rm -rf "${ROOT}"' EXIT

# Stage the gh-app scripts the action invokes, plus a cache-friendly layout.
STAGE="${ROOT}/action"
mkdir -p "${STAGE}/gh-app"
cp "${REPO}/gh-app/get-token.sh" "${REPO}/gh-app/app-slug.sh" \
   "${REPO}/gh-app/bot-user-id.sh" "${STAGE}/gh-app/"

# --- success scenario -------------------------------------------------------
export ACTION_PATH="${STAGE}"
export RUNNER_TEMP="${ROOT}/rt"
mkdir -p "${RUNNER_TEMP}"
export APP_ID="12345"
export INSTALLATION_ID="67890"
export PRIVATE_KEY="dummy-key"
export APP_SLUG="conahcnuj"
export GITHUB_STEP_SUMMARY="${ROOT}/summary"
export GITHUB_REPOSITORY="owner/repo"
: > "${GITHUB_STEP_SUMMARY}"

# Seed the caches so no network / real key is needed (mirrors gh-app tests).
printf '%s|%s\n' "$(( $(date +%s) + 3600 ))" "ghs_faketoken" \
  > "${STAGE}/gh-app/token.cache"
printf '99999' > "${STAGE}/gh-app/bot-id.cache"

# Mock gh: auto-merge enabled.
mkdir -p "${ROOT}/bin"
cat > "${ROOT}/bin/gh" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == "api" ]]; then
  printf 'true\n'
  exit 0
fi
echo "unexpected gh args: $*" >&2
exit 1
MOCK
chmod +x "${ROOT}/bin/gh"
export PATH="${ROOT}/bin:${PATH}"

# Extract every run: | block from action.yml into one executable script.
RUN="${ROOT}/run.sh"
awk '
  /^[[:space:]]*run:[[:space:]]*\|/ { inblock=1; next }
  inblock {
    if ($0 ~ /^[[:space:]]*$/) { print ""; next }
    if ($0 ~ /^        /) { sub(/^        /, ""); print; next }
    inblock=0
  }
' "${ACTION}" > "${RUN}"
[[ -s "${RUN}" ]] || { echo "FAIL: no run blocks extracted" >&2; exit 1; }
bash -n "${RUN}" || { echo "FAIL: extracted run block is not valid bash" >&2; exit 1; }

bash "${RUN}" || { echo "FAIL: setup run blocks did not succeed" >&2; exit 1; }
grep -q "conahcnuj setup verified: ready to run." "${GITHUB_STEP_SUMMARY}" \
  || { echo "FAIL: readiness message missing" >&2; exit 1; }
echo "PASS: setup succeeds when ready"

# --- missing input fails ----------------------------------------------------
export APP_ID=""
export GITHUB_STEP_SUMMARY="${ROOT}/summary2"
: > "${GITHUB_STEP_SUMMARY}"
set +e
bash "${RUN}" >/dev/null 2>&1
rc=$?
set -e
if [[ "${rc}" -eq 0 ]]; then
  echo "FAIL: missing app-id should fail" >&2
  exit 1
fi
echo "PASS: missing input fails"

# --- setup.yml reusable workflow contract -----------------------------------
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
if ! grep -Eq 'uses:[[:space:]]*actions/checkout@[0-9a-f]{40}[[:space:]]*$' "${SETUP}"; then
  echo "FAIL: setup.yml checkout must be pinned to a full-length SHA" >&2
  exit 1
fi
# composite + no secrets context in action
grep -Eq '^[[:space:]]*using:[[:space:]]*composite' "${ACTION}" \
  || { echo "FAIL: action.yml must be a composite action" >&2; exit 1; }
if grep -Eq '\$\{\{[[:space:]]*secrets\.' "${ACTION}"; then
  echo "FAIL: action.yml must not read the secrets context" >&2
  exit 1
fi

echo "action setup test passed"
