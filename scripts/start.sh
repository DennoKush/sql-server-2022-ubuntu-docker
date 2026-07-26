#!/usr/bin/env bash
# start.sh — starts (creates if needed) the SQL Server container via
# `docker compose up -d`. Safe to re-run; Compose reconciles state.
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if ! command -v docker >/dev/null 2>&1; then
    echo "Error: docker is not installed. See docs/02-docker-installation.md" >&2
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    echo "Error: 'docker compose' plugin is not available. See docs/02-docker-installation.md" >&2
    exit 1
fi

if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
    echo "Error: .env not found. Run ./scripts/generate-env.sh or 'cp .env.example .env' first." >&2
    exit 1
fi

echo "Starting SQL Server 2022 container (docker compose up -d)..."
docker compose up -d

echo "Started. Check status with: ./scripts/status.sh"
echo "Follow logs with:          ./scripts/logs.sh"
echo "Check health with:         ./scripts/health-check.sh"
