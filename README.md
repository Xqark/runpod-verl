# runpod-verl

Custom Runpod image wrapper for veRL with secure SSH enabled at container startup.

## What this adds on top of the official veRL image

- Starts from the official veRL image (`VERL_BASE_IMAGE`, default `verlai/verl:base-verl0.4-cu124-cudnn9.8-torch2.6-fa2.7.4`).
- Installs and runs OpenSSH server.
- Creates/uses a non-root SSH user (`poduser` by default).
- Enforces key-based SSH auth by default.
- Keeps upstream `CMD` behavior by using an entrypoint wrapper.

## Environment variables

- `SSH_AUTHORIZED_KEYS`: One or more public keys (preferred).
- `SSH_PUBLIC_KEY`: Single public key fallback.
- `RUNPOD_PUBLIC_KEY`: Runpod-style fallback.
- `PUBLIC_KEY`: Generic fallback.
- `SSH_USER` (default: `poduser`)
- `SSH_UID` (default: `1000`)
- `SSH_GID` (default: `1000`)
- `SSH_PORT` (default: `22`)
- `REQUIRE_SSH_KEY` (default: `true`)
- `VERL_PIP_SPEC` build arg (default: `verl`, can be pinned like `verl==0.7.0`)

## Local build

```bash
docker build -t runpod-verl:dev \
  --build-arg VERL_BASE_IMAGE=verlai/verl:base-verl0.4-cu124-cudnn9.8-torch2.6-fa2.7.4 \
  --build-arg VERL_PIP_SPEC='verl' .
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

## GitHub Actions (CI)

Workflow: `.github/workflows/build-image.yml` (lightweight validation only)

- Pull requests and `main`: script/file validation checks.

## Publish image to GHCR (local)

Use the publish script:

```bash
./scripts/publish-ghcr.sh
```

Optional overrides:

```bash
IMAGE_REPO=ghcr.io/xqark/runpod-verl \
IMAGE_TAG=main \
EXTRA_TAG=latest \
GITHUB_USER=Xqark \
VERL_PIP_SPEC='verl' \
./scripts/publish-ghcr.sh
```

## Runpod template settings

Use your pushed image, then set:

- Exposed TCP ports: `22`
- Container disk and GPU as needed for training
- Env var for key injection: `SSH_AUTHORIZED_KEYS=<your-public-key>`
- Optional overrides: `SSH_USER`, `SSH_UID`, `SSH_GID`, `SSH_PORT`

## Security defaults

- Root SSH login disabled.
- Password SSH auth disabled.
- Public-key auth required unless `REQUIRE_SSH_KEY=false` (not recommended).
