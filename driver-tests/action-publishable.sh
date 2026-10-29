#!/usr/bin/env bash
# action.yml must exist at the repository root and be a valid GitHub Actions
# metadata file suitable for GitHub Marketplace publication: a single metadata
# file at the root, a composite `runs.using`, a unique-ish name, description,
# author, and valid branding (icon + color). See:
# https://docs.github.com/en/actions/how-tos/create-and-publish-actions/publish-in-github-marketplace
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "${HERE}/.." && pwd)"
ACTION="${REPO}/action.yml"

[[ -f "${ACTION}" ]] || { echo "FAIL: missing root action.yml (required for Marketplace)"; exit 1; }

python3 - "${ACTION}" <<'PY'
import sys, yaml
path = sys.argv[1]
with open(path) as f:
    d = yaml.safe_load(f)
assert isinstance(d, dict), "action.yml must parse to a mapping"
for key in ("name", "description", "author", "branding", "runs"):
    assert key in d, f"action.yml missing required key: {key}"
assert d["runs"].get("using") in ("composite", "docker", "node12", "node16", "node20"), \
    "runs.using must be a valid action runtime"
branding = d["branding"]
assert "icon" in branding and "color" in branding, "branding must set icon and color"
valid_colors = {"white", "yellow", "blue", "green", "orange", "red", "purple", "gray-dark"}
assert branding["color"] in valid_colors, f"invalid branding color: {branding['color']}"
assert isinstance(d["name"], str) and d["name"].strip(), "name must be non-empty"
print("action.yml Marketplace metadata OK")
PY

# The reusable workflows that carry the real automation must exist and be reusable.
for wf in issue-driver.yml owner-approved-auto-merge.yml; do
  [[ -f "${REPO}/.github/workflows/${wf}" ]] || { echo "FAIL: missing ${wf}"; exit 1; }
  grep -q "workflow_call" "${REPO}/.github/workflows/${wf}" \
    || { echo "FAIL: ${wf} is not a reusable workflow"; exit 1; }
done

echo "action publishable checks passed"
