# Runpod usage notes (opinionated)

This template is opinionated and primarily intended for personal use. It assumes:

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

## Reminder

This image is built for convenience and personal workflows, not for a hardened multi-user environment.
