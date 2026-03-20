#!/usr/bin/env bash
set -euo pipefail

SDPO_REPO="${SDPO_REPO:-https://github.com/lasgroup/SDPO.git}"
SDPO_REF="${SDPO_REF:-main}"
SDPO_DIR="${SDPO_DIR:-/workspace/SDPO}"
INSTALL_SDPO_REQUIREMENTS="${INSTALL_SDPO_REQUIREMENTS:-false}"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required but not installed." >&2
  exit 1
fi

if [[ ! -d "${SDPO_DIR}/.git" ]]; then
  echo "Cloning SDPO into ${SDPO_DIR}..."
  git clone --depth 1 --branch "${SDPO_REF}" "${SDPO_REPO}" "${SDPO_DIR}"
else
  echo "Using existing SDPO checkout at ${SDPO_DIR}"
fi

cd "${SDPO_DIR}"

echo "Installing SDPO package in editable mode without dependencies..."
python -m pip install --no-deps -e .

if [[ "${INSTALL_SDPO_REQUIREMENTS}" == "true" ]]; then
  echo "Installing SDPO pinned Python requirements..."
  python -m pip install -r requirements.txt
fi

echo "Bootstrap complete."
