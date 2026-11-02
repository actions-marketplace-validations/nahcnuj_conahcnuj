#!/usr/bin/env bash
# verify_app_repo_access / gh_api_installation_repo_access test (offline).
#
# An installation token only reaches the repositories selected for the App
# installation. Targeting any other repository makes branch and pull-request
# creation fail with FORBIDDEN, which used to burn a whole run and file a
# misleading "no model completed the work" bug report (issue #841). The guard
# reads the installation's repository list and stops such a run before the
# bug-report trap with a clear configuration error, while an unreadable answer
# only warns (it must not block a run that might still work).
#
# Sources bin/conahcnuj.sh via CONAHCNUJ_IMPORT=1 (main() must not run) and
# stubs the HTTP layer, so no network is needed.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "${HERE}/.." && pwd)"

ROOT="$(mktemp -d)"
trap 'rm -rf "${ROOT}"' EXIT

cd "${ROOT}" || exit 1
CONAHCNUJ_IMPORT=1
CONAHCNUJ_TEST_MODE=0
# shellcheck source=bin/conahcnuj.sh
. "${REPO}/bin/conahcnuj.sh"

# The mocked HTTP layer returns the next queued response, one per call, so a
# test can exercise pagination. GH_API_TEST_MODE would do the same from stdin,
# but the guard is a plain function here and queuing is clearer. The call count
# lives in a file because gh_api_call runs inside a command substitution (a
# subshell), where a shell variable would not survive to the next call.
MOCK_RESPONSES=()
MOCK_CALLS_FILE="${ROOT}/calls"
MOCK_FAIL_AT=0
mock_reset() {
  : > "${MOCK_CALLS_FILE}"
}
mock_calls() {
  wc -l < "${MOCK_CALLS_FILE}" | tr -d ' '
}
gh_api_call() {
  local calls
  calls="$(mock_calls)"
  calls=$((calls + 1))
  printf 'x\n' >> "${MOCK_CALLS_FILE}"
  if [[ "${MOCK_FAIL_AT}" -ne 0 && "${calls}" -ge "${MOCK_FAIL_AT}" ]]; then
    return 1
  fi
  printf '%s\n' "${MOCK_RESPONSES[${calls} - 1]}"
}

page_with() {
  local total="${1}" full="${2}"
  printf '{"total_count":%s,"repositories":[{"full_name":"nahcnuj/other"},{"full_name":"%s"}]}' "${total}" "${full}"
}

page_without() {
  local total="${1}"
  printf '{"total_count":%s,"repositories":[{"full_name":"nahcnuj/other"},{"full_name":"nahcnuj/another"}]}' "${total}"
}

# 1. The target is on the (only) page: accessible.
MOCK_RESPONSES=("$(page_with 2 "nahcnuj/vigilant-fiesta")")
mock_reset
[[ "$(gh_api_installation_repo_access "nahcnuj" "vigilant-fiesta")" == "yes" ]] || {
  echo "FAIL: a repository in the installation was reported as missing" >&2
  exit 1
}

# 2. The target is absent from a single page: not accessible.
MOCK_RESPONSES=("$(page_without 2)")
mock_reset
[[ "$(gh_api_installation_repo_access "nahcnuj" "vigilant-fiesta")" == "no" ]] || {
  echo "FAIL: a repository outside the installation was not reported as missing" >&2
  exit 1
}

# 2b. A near-miss name must not match: dots in a repository name are literal,
#     not "any character" (a regex match would let a run proceed only to fail
#     with FORBIDDEN again).
MOCK_RESPONSES=("$(page_with 2 "nahcnuj/vigilantXfiesta")")
mock_reset
[[ "$(gh_api_installation_repo_access "nahcnuj" "vigilant.fiesta")" == "no" ]] || {
  echo "FAIL: a similar repository name was taken for the target" >&2
  exit 1
}

# 3. Pagination: the target is on the second page, so the first page's absence
#    must not be taken as the answer.
MOCK_RESPONSES=("$(page_without 150)" "$(page_with 150 "nahcnuj/vigilant-fiesta")")
mock_reset
[[ "$(gh_api_installation_repo_access "nahcnuj" "vigilant-fiesta")" == "yes" ]] || {
  echo "FAIL: the installation list was not paginated" >&2
  exit 1
}
[[ "$(mock_calls)" -eq 2 ]] || { echo "FAIL: expected 2 pages, saw $(mock_calls)" >&2; exit 1; }

# 4. An unreadable list is not a definite "no".
MOCK_RESPONSES=("")
mock_reset
MOCK_FAIL_AT=1
[[ "$(gh_api_installation_repo_access "nahcnuj" "vigilant-fiesta")" == "unknown" ]] || {
  echo "FAIL: a failed API call was reported as a definite answer" >&2
  exit 1
}
MOCK_FAIL_AT=0

# 5. An accessible target passes the guard silently.
MOCK_RESPONSES=("$(page_with 2 "nahcnuj/vigilant-fiesta")")
mock_reset
(
  verify_app_repo_access "nahcnuj/vigilant-fiesta"
) >"${ROOT}/ok.log" 2>&1 || {
  echo "FAIL: an accessible repository was rejected: $(cat "${ROOT}/ok.log")" >&2
  exit 1
}
[[ ! -s "${ROOT}/ok.log" ]] || { echo "FAIL: the accessible case was noisy: $(cat "${ROOT}/ok.log")" >&2; exit 1; }

# 6. An inaccessible target stops the run and says what to do.
MOCK_RESPONSES=("$(page_without 2)")
mock_reset
rc=0
(
  verify_app_repo_access "nahcnuj/vigilant-fiesta"
) >"${ROOT}/missing.log" 2>&1 || rc=$?
[[ ${rc} -ne 0 ]] || { echo "FAIL: an inaccessible repository was accepted" >&2; exit 1; }
grep -q "cannot access nahcnuj/vigilant-fiesta" "${ROOT}/missing.log" || {
  echo "FAIL: the error does not name the target: $(cat "${ROOT}/missing.log")" >&2
  exit 1
}
grep -q "Install the App on nahcnuj/vigilant-fiesta" "${ROOT}/missing.log" || {
  echo "FAIL: the error does not tell the maintainer what to do: $(cat "${ROOT}/missing.log")" >&2
  exit 1
}

# 7. An unreadable answer only warns, so a transient API failure cannot block a
#    run that might still work.
MOCK_RESPONSES=("")
mock_reset
MOCK_FAIL_AT=1
(
  verify_app_repo_access "nahcnuj/vigilant-fiesta"
) >"${ROOT}/unknown.log" 2>&1 || {
  echo "FAIL: an unreadable answer blocked the run: $(cat "${ROOT}/unknown.log")" >&2
  exit 1
}
grep -q "could not confirm the App installation can access nahcnuj/vigilant-fiesta" "${ROOT}/unknown.log" || {
  echo "FAIL: the unreadable case did not warn: $(cat "${ROOT}/unknown.log")" >&2
  exit 1
}
MOCK_FAIL_AT=0

# 8. No target: the guard stays out of the way and makes no API call.
mock_reset
(
  verify_app_repo_access ""
) >"${ROOT}/empty.log" 2>&1 || {
  echo "FAIL: an empty target was rejected: $(cat "${ROOT}/empty.log")" >&2
  exit 1
}
[[ "$(mock_calls)" -eq 0 ]] || { echo "FAIL: an empty target made an API call" >&2; exit 1; }

echo "conahcnuj App repository-access guard passed"
