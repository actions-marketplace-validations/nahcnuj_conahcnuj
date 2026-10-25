#!/usr/bin/env bash
# Measures, on the actual host, whether head/tail/grep exist in the current
# shell, and checks that this matches the platform the plugin would report
# (issue #369). On Windows it also runs the commands through the real
# PowerShell with Git for Windows' usr/bin on PATH, the directory the plugin
# injects, so the fix for #446 is verified on the real runner.
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

# Sanity: on a Unix platform the tools must be present. On Windows the
# conahcnuj plugin puts Git for Windows' usr/bin on PATH precisely so the
# PowerShell that opencode spawns can use them; verify that with the real
# PowerShell on the runner instead of a stub.
case "${node_platform}" in
  linux|darwin)
    [ "${have_all}" = "1" ] || { echo "FAIL: head/tail/grep missing on Unix" >&2; exit 1; }
    ;;
  win32)
    usr_bin_unix="$(dirname "$(command -v head)")"
    usr_bin="$(cygpath -w "${usr_bin_unix}" 2>/dev/null || printf '%s' "${usr_bin_unix}")"
    ps=""
    for candidate in pwsh powershell; do
      if command -v "${candidate}" >/dev/null 2>&1; then
        ps="${candidate}"
        break
      fi
    done
    if [ -z "${ps}" ]; then
      echo "SKIP: no PowerShell on this runner"
    else
      ps1_unix="$(mktemp)"
      ps1="$(cygpath -w "${ps1_unix}" 2>/dev/null || printf '%s' "${ps1_unix}")"
      trap 'rm -f "${ps1_unix}"' EXIT
      cat > "${ps1_unix}" <<'PS1'
$ErrorActionPreference = 'Stop'
$env:PATH = $args[0] + ';' + $env:PATH
$lines = "alpha`nbeta`ngamma"
$h = @($lines | head -n 1)[0]
$t = @($lines | tail -n 1)[0]
$g = @($lines | grep beta)[0]
if ($h -ne 'alpha') { throw "head: $h" }
if ($t -ne 'gamma') { throw "tail: $t" }
if ($g -ne 'beta') { throw "grep: $g" }
PS1
      "${ps}" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "${ps1}" "${usr_bin}"
      echo "PowerShell head/tail/grep OK (${usr_bin})"
    fi
    ;;
esac

# The plugin source must still derive its claim from process.platform.
grep -q "process.platform" "${REPO}/plugins/gh-app-token.ts" || {
  echo "FAIL: plugin does not derive the shell rule from process.platform" >&2
  exit 1
}

echo "shell-portability runtime measurement done"
