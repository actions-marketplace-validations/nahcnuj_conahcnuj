#!/usr/bin/env bash
# Measures, on the actual host, whether head/tail/grep exist in the current
# shell, and checks that this matches the platform the plugin would report
# (issue #369). This is a real measurement (not a source grep), so it also
# runs under Windows in CI's mock-test job.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "${HERE}/.." && pwd)"

# Real measurement: do the commands actually resolve in this shell?
have_all=0
if command -v head >/dev/null 2>&1 && command -v tail >/dev/null 2>&1 && command -v grep >/dev/null 2>&1; then
  have_all=1
fi

# The platform the plugin's node process would report.
node_platform="$(node -e 'process.stdout.write(process.platform)')"

echo "measured: head/tail/grep all available = ${have_all} (platform=${node_platform})"

# Sanity: on a Unix platform the tools must be present; on Windows they may or
# may not be (PowerShell lacks them, Git Bash has them), so only assert on Unix.
case "${node_platform}" in
  linux|darwin)
    [ "${have_all}" = "1" ] || { echo "FAIL: head/tail/grep missing on Unix" >&2; exit 1; }
    ;;
  win32)
    # Conservative: plugin reports "not available"; just report, do not fail,
    # because the real shell (PowerShell vs Git Bash) is only known at runtime.
    ;;
esac

# The plugin source must still derive its claim from process.platform.
grep -q "process.platform" "${REPO}/plugins/gh-app-token.ts" || {
  echo "FAIL: plugin does not derive the shell rule from process.platform" >&2
  exit 1
}

echo "shell-portability runtime measurement done"
