#!/usr/bin/env bash
set -euo pipefail

IMAGE_REPO="${IMAGE_REPO:-docker.io/sparkkkkk/runpod-verl}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
EXTRA_TAG="${EXTRA_TAG:-}"
VERL_BASE_IMAGE="${VERL_BASE_IMAGE:-verlai/verl:app-verl0.5-vllm0.10.0-mcore0.13.0-te2.2}"
SKIP_BUILD="${SKIP_BUILD:-false}"
SKIP_SMOKE="${SKIP_SMOKE:-false}"
PUSH_RETRIES="${PUSH_RETRIES:-5}"
PUSH_RETRY_DELAY="${PUSH_RETRY_DELAY:-5}"

push_with_retry() {
  local ref="$1"
  local attempt
  for attempt in $(seq 1 "${PUSH_RETRIES}"); do
    echo "Pushing ${ref} (attempt ${attempt}/${PUSH_RETRIES})..."
    if docker push "${ref}"; then
      return 0
    fi
    if [[ "${attempt}" -lt "${PUSH_RETRIES}" ]]; then
      echo "Push failed; retrying in ${PUSH_RETRY_DELAY}s..."
      sleep "${PUSH_RETRY_DELAY}"
    fi
  done
  echo "Push failed after ${PUSH_RETRIES} attempts: ${ref}" >&2
  return 1
}

if [[ "${SKIP_BUILD}" != "true" ]]; then
  echo "Building ${IMAGE_REPO}:${IMAGE_TAG} for linux/amd64..."
  docker build \
    --platform linux/amd64 \
    --build-arg VERL_BASE_IMAGE="${VERL_BASE_IMAGE}" \
    -t "${IMAGE_REPO}:${IMAGE_TAG}" \
    .
fi

if [[ "${SKIP_SMOKE}" != "true" ]]; then
  echo "Running smoke test..."
  ./scripts/smoke-test.sh "${IMAGE_REPO}:${IMAGE_TAG}"
fi

if [[ -n "${EXTRA_TAG}" ]]; then
  docker tag "${IMAGE_REPO}:${IMAGE_TAG}" "${IMAGE_REPO}:${EXTRA_TAG}"
fi

if [[ -n "${DOCKERHUB_TOKEN:-}" ]]; then
  echo "Logging in to Docker Hub using DOCKERHUB_TOKEN..."
  printf '%s' "${DOCKERHUB_TOKEN}" | docker login docker.io -u "${DOCKERHUB_USER:-sparkkkkk}" --password-stdin
else
  echo "Using existing Docker login session."
fi

push_with_retry "${IMAGE_REPO}:${IMAGE_TAG}"

if [[ -n "${EXTRA_TAG}" ]]; then
  push_with_retry "${IMAGE_REPO}:${EXTRA_TAG}"
fi

echo "Done."
