#!/usr/bin/env bash
# Issue #446: head/tail/grep must work in PowerShell environments where
# conahcnuj runs. On Windows, Git for Windows provides them in usr/bin and
# the opencode plugin injects that directory onto PATH; this test verifies
# the real PowerShell can use them (no test doubles).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "${HERE}/.." && pwd)"

node_platform="$(node -e 'process.stdout.write(process.platform)')"

have_all=0
if command -v head >/dev/null 2>&1 && command -v tail >/dev/null 2>&1 && command -v grep >/dev/null 2>&1; then
  have_all=1
fi

echo "conahcnuj head/tail/grep availability: head/tail/grep all available = ${have_all} (platform=${node_platform})"

case "${node_platform}" in
  linux|darwin)
    [ "${have_all}" = "1" ] || { echo "FAIL: head/tail/grep missing on Unix" >&2; exit 1; }
    ;;
  win32)
    ps=""
    for candidate in pwsh powershell; do
      if command -v "${candidate}" >/dev/null 2>&1; then
        ps="${candidate}"
        break
      fi
    done
    if [ -z "${ps}" ]; then
      echo "SKIP: no PowerShell on this runner"
      exit 0
    fi
    # Simulate the plugin's PATH injection exactly as implemented.
    real_bash="$(find /c/Program\ Files/Git -name bash.exe 2>/dev/null | head -1 || true)"
    if [ -z "${real_bash}" ]; then
      real_bash="$(find /usr/bin -name bash.exe 2>/dev/null | head -1 || true)"
    fi
    if [ -n "${real_bash}" ]; then
      git_root="$(dirname "$(dirname "${real_bash}")")"
      usr_bin_unix="$(cygpath -u "${git_root}" 2>/dev/null || printf '%s' "${git_root}")/usr/bin"
      if [ -d "${usr_bin_unix}" ]; then
        usr_bin="$(cygpath -w "${usr_bin_unix}" 2>/dev/null || printf '%s' "${usr_bin_unix}")"
        ps1_unix="$(mktemp)"
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
        "${ps}" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$(cygpath -w "${ps1_unix}" 2>/dev/null || printf '%s' "${ps1_unix}")" "${usr_bin}"
        echo "PowerShell head/tail/grep OK via conahcnuj PATH injection (${usr_bin})"
        exit 0
      fi
    fi
    # Fallback: just verify head/tail/grep work in PowerShell if on PATH.
    if ! command -v head >/dev/null 2>&1 || ! command -v tail >/dev/null 2>&1 || ! command -v grep >/dev/null 2>&1; then
      echo "SKIP: head/tail/grep not resolvable on this Windows shell"
      exit 0
    fi
    ps1_unix="$(mktemp)"
    trap 'rm -f "${ps1_unix}"' EXIT
    cat > "${ps1_unix}" <<'PS1'
$ErrorActionPreference = 'Stop'
$lines = "alpha`nbeta`ngamma"
$h = @($lines | head -n 1)[0]
$t = @($lines | tail -n 1)[0]
$g = @($lines | grep beta)[0]
if ($h -ne 'alpha') { throw "head: $h" }
if ($t -ne 'gamma') { throw "tail: $t" }
if ($g -ne 'beta') { throw "grep: $g" }
PS1
    "${ps}" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$(cygpath -w "${ps1_unix}" 2>/dev/null || printf '%s' "${ps1_unix}")"
    echo "PowerShell head/tail/grep OK"
    ;;
  *)
    echo "SKIP: unsupported platform ${node_platform}"
    ;;
esac
