#!/usr/bin/env bash
# Verifies that the shell-portability guidance is present and is keyed to the
# actual running platform rather than a hard-coded "PowerShell" assumption
# (issue #369). Runs on every OS in CI's mock-test job, including Windows.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "${HERE}/.." && pwd)"

fail() { echo "FAIL: $*" >&2; exit 1; }

# The plugin must detect the platform and state whether head/tail/grep exist.
grep -q 'const shellPlatform =' "${REPO}/plugins/gh-app-token.ts" || fail "shellPlatform detection missing"
grep -q 'const headTailGrepAvailability =' "${REPO}/plugins/gh-app-token.ts" || fail "availability detection missing"
grep -q 'Shell environment: this session runs on' "${REPO}/plugins/gh-app-token.ts" || fail "platform-aware rule text missing"

# The global AGENTS.md must keep the same "check your environment first" guidance.
grep -q 'シェルの移植性' "${REPO}/opencode/AGENTS.md" || fail "AGENTS.md shell-portability section missing"
grep -q 'Never use head/tail/grep' "${REPO}/opencode/AGENTS.md" || fail "AGENTS.md never-use guidance missing"

echo "shell-portability rule present"
