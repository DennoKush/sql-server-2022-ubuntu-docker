#!/usr/bin/env bash
# logs.sh — read-only: streams logs from the sqlserver service.
# Press Ctrl-C to stop following.
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if ! command -v docker >/dev/null 2>&1; then
    echo "Error: docker is not installed. See docs/02-docker-installation.md" >&2
    exit 1
fi

docker compose logs -f sqlserver
