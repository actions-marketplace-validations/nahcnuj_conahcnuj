#!/usr/bin/env bash
# conahcnuj reviewer-override flow test (offline).
#
# When the repository owner is not a usable reviewer (e.g. an organisation),
# CONAHCNUJ_REVIEWER lets the operator name a human admin up front. This drives
# the real bin/conahcnuj.sh state machine with that override set and proves the
# driver requests review from the named reviewer instead of the owner.
#
# No secrets, no network.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "${HERE}/.." && pwd)"
DRIVER="${REPO}/bin/conahcnuj.sh"

ROOT="$(mktemp -d)"
WORK="${ROOT}/repo"
trap 'rm -rf "${ROOT}"' EXIT
mkdir -p "${WORK}"

git -C "${WORK}" init -q
git -C "${WORK}" config user.email "test@example.com"
git -C "${WORK}" config user.name "test"
git -C "${WORK}" config commit.gpgsign false
printf 'base\n' > "${WORK}/file.txt"
printf '# Guide\nReviewer override fixture README\n' > "${WORK}/README.md"
git -C "${WORK}" add -A
git -C "${WORK}" commit -qm init

TAPE="${ROOT}/tape.txt"
cat > "${TAPE}" <<'EOF'
{"number": 10, "title": "Reviewer override", "body": "Use the named reviewer.", "labels": [], "state": "open"}
{"data":{"repository":{"defaultBranchRef":{"name":"main","target":{"oid":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}}}}
{"data":{"repository":{"pullRequests":{"nodes":[]}}}}
{"data":{"repository":{"pullRequests":{"nodes":[]}}}}
{"data":{"repository":{"id":"R_kgDOXmplR3p"}}}
{"data":{"createPullRequest":{"pullRequest":{"number":123}}}}
{}
{"data":{"repository":{"pullRequest":{"reviewDecision":"REVIEW_REQUIRED","reviews":{"nodes":[]},"comments":{"nodes":[]},"reviewThreads":{"nodes":[]}}}}}
{"data":{"repository":{"pullRequest":{"mergeable":"MERGEABLE","mergeStateStatus":"BLOCKED","commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"PENDING"}}}]}}}}}
{"data":{"repository":{"pullRequest":{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"SUCCESS"}}}]}}}}}
{}
EOF

export CONAHCNUJ_TEST_MODE=1
export GH_API_TEST_MODE=1
export OPENCODE_TEST_MODE=1
export MOCK_OPENCODE_MODELS="opencode/first"
export CONAHCNUJ_REPO="conahcnuj/conahcnuj"
export CONAHCNUJ_REVIEWER="alice"

unset CONAHCNUJ_COMMIT_MODEL CONAHCNUJ_MODEL_LABEL_FILE CONAHCNUJ_SESSION_MODEL \
  CONAHCNUJ_RUN_TIMEOUT_SECONDS OPENCODE_LAST_MODEL

LOG="${ROOT}/run.log"
RC=0
(
  cd "${WORK}"
  GITHUB_ACTIONS=true CONAHCNUJ_MAX_SECONDS=10 bash "${DRIVER}" 10 < "${TAPE}"
) > "${LOG}" 2>&1 || RC=$?

# Keep the run log silent on success; print it only when the run failed, so a
# failure can be diagnosed without flooding successful CI output.
if [[ ${RC} -ne 0 ]]; then
  echo "----- conahcnuj reviewer-override run log -----"
  cat "${LOG}"
  echo "----------------------------------------------"
fi

[[ ${RC} -eq 0 ]] || { echo "FAIL: driver exited ${RC} (expected 0)"; exit 1; }
grep -q "Assigned alice as reviewer on PR #123" "${LOG}" || { echo "FAIL: the named reviewer was not assigned"; exit 1; }
grep -q "Review requested on PR #123 (reviewer: alice)" "${LOG}" || { echo "FAIL: the PR was not handed to the named reviewer"; exit 1; }
