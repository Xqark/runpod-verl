# runpod-verl

Custom Runpod image wrapper for veRL with secure SSH enabled at container startup.

## What this adds on top of the official veRL image

- Starts from the official veRL image (`VERL_BASE_IMAGE`, default `verlai/verl:app-verl0.5-vllm0.10.0-mcore0.13.0-te2.2`).
- Installs and runs OpenSSH server.
- Creates/uses a non-root SSH user (`poduser` by default).
- Enforces key-based SSH auth by default.
- Keeps upstream `CMD` behavior by using an entrypoint wrapper.
- Installs `fish`, `tmux`, `git-lfs`, `sudo`, Codex CLI, and OpenCode CLI.

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
- `ROOT_PASSWORD` (optional; if set, initializes root password)
- `SSH_USER_PASSWORD` (optional; if set, initializes SSH user password)

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

## Security defaults

- Root SSH login disabled.
- Password SSH auth disabled.
- Public-key auth required unless `REQUIRE_SSH_KEY=false` (not recommended).
- Root/SSH user passwords are not set unless you provide `ROOT_PASSWORD` / `SSH_USER_PASSWORD`.
