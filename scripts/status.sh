#!/usr/bin/env bash
# status.sh — read-only: shows the current status of the Compose stack.
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if ! command -v docker >/dev/null 2>&1; then
    echo "Error: docker is not installed. See docs/02-docker-installation.md" >&2
    exit 1
fi

docker compose ps
