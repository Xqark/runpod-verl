#!/usr/bin/env bash
set -euo pipefail

IMAGE_REPO="${IMAGE_REPO:-docker.io/sparkkkkk/runpod-verl}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
EXTRA_TAG="${EXTRA_TAG:-}"
VERL_BASE_IMAGE="${VERL_BASE_IMAGE:-verlai/verl:app-verl0.5-vllm0.10.0-mcore0.13.0-te2.2}"
VERL_PIP_SPEC="${VERL_PIP_SPEC:-verl}"
SKIP_BUILD="${SKIP_BUILD:-false}"
SKIP_SMOKE="${SKIP_SMOKE:-false}"

if [[ "${SKIP_BUILD}" != "true" ]]; then
  echo "Building ${IMAGE_REPO}:${IMAGE_TAG} for linux/amd64..."
  docker build \
    --platform linux/amd64 \
    --build-arg VERL_BASE_IMAGE="${VERL_BASE_IMAGE}" \
    --build-arg VERL_PIP_SPEC="${VERL_PIP_SPEC}" \
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

echo "Pushing ${IMAGE_REPO}:${IMAGE_TAG}..."
docker push "${IMAGE_REPO}:${IMAGE_TAG}"

if [[ -n "${EXTRA_TAG}" ]]; then
  echo "Pushing ${IMAGE_REPO}:${EXTRA_TAG}..."
  docker push "${IMAGE_REPO}:${EXTRA_TAG}"
fi

echo "Done."
