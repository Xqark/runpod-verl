# Runpod usage notes (opinionated)

This template is opinionated and primarily intended for personal use. The current target is a generic SDPO-capable RunPod image for single-node NVIDIA pods with a workspace checkout, not a self-contained SDPO image. It assumes:

- You want SSH access for development.
- You want a non-root SSH user by default.
- You are comfortable configuring your own keys and environment variables.

## SSH user and auth

- SSH user: `poduser` (not `root`).
- Root SSH login is disabled.
- Password SSH auth is disabled by default; use SSH keys.

Provide your public key via environment variables:

- `SSH_AUTHORIZED_KEYS` (preferred)
- `SSH_PUBLIC_KEY`
- `RUNPOD_PUBLIC_KEY`
- `PUBLIC_KEY`

You only need to set one. If multiple are set, the precedence is:
`SSH_AUTHORIZED_KEYS` → `SSH_PUBLIC_KEY` → `RUNPOD_PUBLIC_KEY` → `PUBLIC_KEY`.

## Optional passwords (not required for SSH)

If you want to set local passwords for `sudo`/`su` inside the container, provide:

- `ROOT_PASSWORD`
- `SSH_USER_PASSWORD`

These are optional. If unset, no passwords are initialized.

## Ports

Expose TCP port `22` for SSH.

## SDPO usage

- The image does not include the SDPO repo itself.
- Clone SDPO into `/workspace/SDPO` on the Pod.
- Install it from the checkout with `pip install -e . --no-deps`, or run `bootstrap-sdpo.sh` to automate that step.
- If you want the helper to install SDPO's pinned Python requirements too, run it with `INSTALL_SDPO_REQUIREMENTS=true`.

This is intended for non-Blackwell NVIDIA RunPod usage with vLLM on a single node. Experiment launch, dataset setup, and model selection are expected to happen manually in `/workspace`.

## Reminder

This image is built for convenience and personal workflows, not for a hardened multi-user environment.
