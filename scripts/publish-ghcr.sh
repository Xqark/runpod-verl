#!/usr/bin/env bash
set -euo pipefail

echo "publish-ghcr.sh is deprecated. Forwarding to scripts/publish-image.sh."
exec ./scripts/publish-image.sh "$@"
