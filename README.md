# runpod-verl

Custom RunPod image wrapper for veRL with secure SSH enabled at container startup. The current image target is a generic, single-node NVIDIA RunPod environment for SDPO workspace usage with vLLM; it does not bake the SDPO repo into the image.

## What this adds on top of the official veRL image

- Starts from the official veRL image (`VERL_BASE_IMAGE`, default `verlai/verl:app-verl0.5-vllm0.10.0-mcore0.13.0-te2.2`).
- Installs and runs OpenSSH server.
- Creates/uses a non-root SSH user (`poduser` by default).
- Enforces key-based SSH auth by default.
- Keeps upstream `CMD` behavior by using an entrypoint wrapper.
- Installs `fish`, `tmux`, `btop`, `nvtop`, `git`, `git-lfs`, `wget`, `sudo`, and small SDPO-oriented runtime utilities.
- Preinstalls a curated SDPO Python overlay for non-core packages, while leaving the veRL/vLLM/Torch stack to the upstream base image.

## Environment variables

- `SSH_AUTHORIZED_KEYS`: One or more public keys (preferred).
- `SSH_PUBLIC_KEY`: Single public key fallback.
- `RUNPOD_PUBLIC_KEY`: Runpod-style fallback.
- `PUBLIC_KEY`: Generic fallback.

Note: these are **alternative inputs**. You only need to provide one of them. If multiple are set, the image uses this precedence:
`SSH_AUTHORIZED_KEYS` → `SSH_PUBLIC_KEY` → `RUNPOD_PUBLIC_KEY` → `PUBLIC_KEY`.
- `SSH_USER` (default: `poduser`)
- `SSH_UID` (default: `1000`)
- `SSH_GID` (default: `1000`)
- `SSH_PORT` (default: `22`)
- `REQUIRE_SSH_KEY` (default: `true`, enforced in entrypoint)
- `ROOT_PASSWORD` (default: `123456`; initializes root password unless overridden)
- `SSH_USER_PASSWORD` (default: `123456`; initializes SSH user password unless overridden)

## SDPO workflow

This image is intentionally generic. It does not bake the SDPO repo into the image.

To avoid destabilizing the upstream veRL/vLLM stack, the image preinstalls only a curated non-core SDPO Python overlay. Core packages such as `torch`, `vllm`, `ray`, `transformers`, `accelerate`, `datasets`, `numpy`, and `tensordict` are intentionally left to the upstream base image.

The intended workflow on RunPod is:

1. Start a Pod from this image and SSH in as `poduser`.
2. Clone SDPO into `/workspace/SDPO`.
3. Run SDPO commands from that repo checkout.

If you stay inside the SDPO repo, you generally do not need `pip install -e . --no-deps`. The editable install is only useful if you want `import verl` or SDPO entrypoints to work from outside the repo checkout.

This image is aimed at non-Blackwell, single-node NVIDIA RunPod usage with vLLM. Running actual SDPO experiments, choosing the model, and preparing datasets are intentionally left to the workspace on the Pod.

## Local build

```bash
docker build -t runpod-verl:dev \
  --build-arg VERL_BASE_IMAGE=verlai/verl:app-verl0.5-vllm0.10.0-mcore0.13.0-te2.2 .
```

## Local smoke test

```bash
./scripts/smoke-test.sh runpod-verl:dev
```

On Apple Silicon (OrbStack/Docker Desktop), the script auto-selects `linux/amd64`.
You can still force it explicitly:

```bash
TEST_PLATFORM=linux/amd64 ./scripts/smoke-test.sh runpod-verl:dev
```

The smoke test validates container/SSH health and host tools (`git`, `wget`); it does not try to import SDPO or `verl`.

## GitHub Actions (CI)

Workflow: `.github/workflows/build-image.yml` (lightweight validation only)

- Pull requests and `main`: script/file validation checks.

## Publish image to Docker Hub (local)

Use the publish script:

```bash
./scripts/publish-image.sh
```

Optional overrides:

```bash
IMAGE_REPO=docker.io/sparkkkkk/runpod-verl \
IMAGE_TAG=latest \
./scripts/publish-image.sh
```

If you already built locally and only need to push:

```bash
SKIP_BUILD=true SKIP_SMOKE=true ./scripts/publish-image.sh
```

## Runpod template settings

Use your pushed image (for now `docker.io/sparkkkkk/runpod-verl:latest`), then set:

- Exposed TCP ports: `22`
- Container disk and GPU as needed for training
- Env var for key injection: `SSH_AUTHORIZED_KEYS=<your-public-key>`
- Optional overrides: `SSH_USER`, `SSH_UID`, `SSH_GID`, `SSH_PORT`

For SDPO, clone the repo into `/workspace/SDPO` after the Pod starts and install from the workspace checkout rather than rebuilding the image for every SDPO code change.

## Security defaults

- Root SSH login disabled.
- Password SSH auth disabled.
- Public-key auth required unless `REQUIRE_SSH_KEY=false` (not recommended).
- Root/SSH user passwords default to `123456` unless you override `ROOT_PASSWORD` / `SSH_USER_PASSWORD`.
