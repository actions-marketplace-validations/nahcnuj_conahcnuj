#!/usr/bin/env bash
# Verify head/tail/grep are usable in the shell the driver runs in (the same
# environment an issue-drive round executes under). #446 / PR #447 review.
set -euo pipefail

# The driver and its coding agent rely on these being present; on Windows the
# plugin injects Git for Windows' usr/bin, on Unix they are part of coreutils.
for cmd in head tail grep; do
  command -v "${cmd}" >/dev/null 2>&1 || { echo "FAIL: ${cmd} not found" >&2; exit 1; }
done

out="$(printf 'alpha\nbeta\ngamma\n' | head -n 1)"
[[ "${out}" == "alpha" ]] || { echo "FAIL: head: ${out}" >&2; exit 1; }

out="$(printf 'alpha\nbeta\ngamma\n' | tail -n 1)"
[[ "${out}" == "gamma" ]] || { echo "FAIL: tail: ${out}" >&2; exit 1; }

out="$(printf 'alpha\nbeta\ngamma\n' | grep beta)"
[[ "${out}" == "beta" ]] || { echo "FAIL: grep: ${out}" >&2; exit 1; }

echo "head/tail/grep usable in issue-drive shell"
