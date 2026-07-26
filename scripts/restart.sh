#!/usr/bin/env bash
# restart.sh — restarts the SQL Server container in place.
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if ! command -v docker >/dev/null 2>&1; then
    echo "Error: docker is not installed. See docs/02-docker-installation.md" >&2
    exit 1
fi

echo "Restarting SQL Server 2022 container (docker compose restart)..."
docker compose restart

echo "Restarted. Check status with: ./scripts/status.sh"
