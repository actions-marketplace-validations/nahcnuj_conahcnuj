#!/usr/bin/env bash
# Real-Docker test for docker-run.sh (no mocked docker/wslpath).
#
# The offline test (driver-tests/docker-run.sh) pins argument building and the
# WSL relaunch, but it cannot prove the wrapper actually works: the reported
# failures came from real Docker Desktop, not from the arguments we mocked.
# This test builds the real image and runs the wrapper with an entrypoint
# override, then inspects the container to assert that the target repo, the
# generated app.env and the private key are mounted where the driver expects.
#
# docker-run.sh skips this unless CONAHCNUJ_DOCKER_REAL=1, so the offline
# suite (driver-tests/run.sh) stays runnable without a Docker daemon. CI runs
# it in the dedicated `docker-runner` job.
set -euo pipefail

if [[ "${CONAHCNUJ_DOCKER_REAL:-0}" != "1" ]]; then
  echo "SKIP: set CONAHCNUJ_DOCKER_REAL=1 to run the real-Docker test"
  exit 0
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "FAIL: docker is not installed" >&2
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo "FAIL: cannot reach the Docker daemon" >&2
  exit 1
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "${HERE}/.." && pwd)"
WRAPPER="${REPO}/docker-run.sh"
IMAGE="conahcnuj-runner-test"

ROOT="$(mktemp -d)"
cleanup() {
  rm -rf "${ROOT}"
  docker image rm -f "${IMAGE}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

TARGET="${ROOT}/target"
git init -q "${TARGET}"
printf 'hello\n' > "${TARGET}/hello.txt"

PEM="${ROOT}/app.pem"
printf 'dummy-pem-%s\n' "$$" > "${PEM}"
APP_ENV="${ROOT}/app.env"
cat > "${APP_ENV}" <<EOF
APP_ID="1"
INSTALLATION_ID="2"
APP_SLUG="conahcnuj"
PRIVATE_KEY_PATH="${PEM}"
BASH_EXE="C:/Program Files/Git/bin/bash.exe"
EOF

export OPENCODE_CONFIG_DIR="${ROOT}/no-config"
export OPENCODE_DATA_DIR="${ROOT}/no-data"

# Build the real image and run the wrapper through real Docker. The override
# entrypoint lets us inspect the container instead of launching the driver
# (which would need live GitHub credentials).
out="$(
  CONAHCNUJ_BUILD=1 \
  CONAHCNUJ_IMAGE="${IMAGE}" \
  CONAHCNUJ_TARGET="${TARGET}" \
  CONAHCNUJ_APP_ENV="${APP_ENV}" \
  CONAHCNUJ_ENTRYPOINT=/bin/bash \
  bash "${WRAPPER}" -c '
    set -e
    test -d /work/.git
    test -f /work/hello.txt
    test -x /opt/conahcnuj/bin/conahcnuj.sh
    test -f /opt/conahcnuj/lib/gh-api.sh
    test -f /opt/conahcnuj/gh-app/get-token.sh
    # The plugin tells the agent that `gh` is authenticated, so the image
    # must actually provide it.
    command -v gh >/dev/null
    command -v opencode >/dev/null
    test -f /opt/conahcnuj/gh-app/app.env
    grep -qx "PRIVATE_KEY_PATH=/run/secrets/app.pem" /opt/conahcnuj/gh-app/app.env
    grep -qx "BASH_EXE=/usr/bin/bash" /opt/conahcnuj/gh-app/app.env
    test -r /run/secrets/app.pem
    test ! -w /run/secrets/app.pem
    test ! -w /opt/conahcnuj/gh-app/app.env
    printf "PWD=%s\n" "$(pwd)"
    printf "PEM=%s\n" "$(cat /run/secrets/app.pem)"
  ' 2>&1
)"

grep -q 'PWD=/work' <<<"${out}" || {
  echo "FAIL: container did not start in /work; output:" >&2
  printf '%s\n' "${out}" >&2
  exit 1
}
grep -q "PEM=dummy-pem-$$" <<<"${out}" || {
  echo "FAIL: private key was not mounted read-only at /run/secrets/app.pem; output:" >&2
  printf '%s\n' "${out}" >&2
  exit 1
}

echo "docker-run.sh (real Docker) passed"
