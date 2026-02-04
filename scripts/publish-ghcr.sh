#!/usr/bin/env bash
set -euo pipefail

IMAGE_REPO="${IMAGE_REPO:-ghcr.io/xqark/runpod-verl}"
IMAGE_TAG="${IMAGE_TAG:-main}"
EXTRA_TAG="${EXTRA_TAG:-latest}"
VERL_BASE_IMAGE="${VERL_BASE_IMAGE:-verlai/verl:base-verl0.4-cu124-cudnn9.8-torch2.6-fa2.7.4}"
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

echo "Logging in to GHCR using gh token..."
gh auth token | docker login ghcr.io -u "${GITHUB_USER:-Xqark}" --password-stdin

echo "Pushing ${IMAGE_REPO}:${IMAGE_TAG}..."
docker push "${IMAGE_REPO}:${IMAGE_TAG}"

if [[ -n "${EXTRA_TAG}" ]]; then
  echo "Pushing ${IMAGE_REPO}:${EXTRA_TAG}..."
  docker push "${IMAGE_REPO}:${EXTRA_TAG}"
fi

echo "Done."
