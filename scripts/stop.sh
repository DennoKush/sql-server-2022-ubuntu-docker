#!/usr/bin/env bash
# stop.sh — stops the SQL Server container without removing it, its
# volume, or any configuration. Data is preserved.
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if ! command -v docker >/dev/null 2>&1; then
    echo "Error: docker is not installed. See docs/02-docker-installation.md" >&2
    exit 1
fi

echo "Stopping SQL Server 2022 container (docker compose stop)..."
echo "(This preserves the container, its data volume, and configuration — it does not remove anything.)"
docker compose stop

echo "Stopped. Start again with: ./scripts/start.sh"
