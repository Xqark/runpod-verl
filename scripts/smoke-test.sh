#!/usr/bin/env bash
set -euo pipefail

IMAGE_REF="${1:-}"
if [[ -z "${IMAGE_REF}" ]]; then
  echo "Usage: $0 <image-ref>" >&2
  exit 1
fi

TEST_KEY="${TEST_KEY:-ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGoGzY6T5i5aR5bHnJyxZn3MCSX2DL8dj7qP/2Qwcn6T codex-smoke}"
TEST_PLATFORM="${TEST_PLATFORM:-}"
if [[ -z "${TEST_PLATFORM}" ]]; then
  case "$(uname -m)" in
    arm64|aarch64) TEST_PLATFORM="linux/amd64" ;;
  esac
fi

run_args=(-d)
if [[ -n "${TEST_PLATFORM}" ]]; then
  run_args+=(--platform "${TEST_PLATFORM}")
fi

CONTAINER_ID="$(docker run "${run_args[@]}" \
  -e SSH_AUTHORIZED_KEYS="${TEST_KEY}" \
  -e REQUIRE_SSH_KEY=true \
  "${IMAGE_REF}" \
  bash -lc 'python -c "import verl; print(verl.__name__)" && sleep infinity')"

cleanup() {
  docker rm -f "${CONTAINER_ID}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 3

docker exec "${CONTAINER_ID}" bash -lc 'sshd -t'
docker exec "${CONTAINER_ID}" bash -lc 'pgrep -x sshd >/dev/null'
docker exec "${CONTAINER_ID}" bash -lc 'test -s /home/poduser/.ssh/authorized_keys'
