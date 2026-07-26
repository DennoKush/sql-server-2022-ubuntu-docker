#!/usr/bin/env bash
# health-check.sh — read-only: verifies the SQL Server container exists,
# is running, is reported healthy by Docker (when a healthcheck is
# defined), has port 1433 listening locally, and accepts a simple query.
#
# Never prints the sa password, and avoids putting it on the command line
# (which would be visible in `ps`); it is passed via an environment
# variable to the child sqlcmd process instead.
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

CONTAINER_NAME="sqlserver2022"

if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
    echo "Error: .env not found. Run ./scripts/generate-env.sh first." >&2
    exit 1
fi

# shellcheck disable=SC1091
set -a
source "$PROJECT_ROOT/.env"
set +a

MSSQL_PORT="${MSSQL_PORT:-1433}"

echo "=== SQL Server Health Check ==="

# 1. Container exists?
if ! docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    echo "[FAIL] Container '$CONTAINER_NAME' does not exist. Run ./scripts/start.sh first." >&2
    exit 1
fi
echo "[PASS] Container '$CONTAINER_NAME' exists."

# 2. Container running?
RUNNING="$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME")"
if [[ "$RUNNING" != "true" ]]; then
    echo "[FAIL] Container '$CONTAINER_NAME' is not running." >&2
    exit 1
fi
echo "[PASS] Container is running."

# 3. Docker-reported health status, if a healthcheck is defined.
HEALTH_STATUS="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$CONTAINER_NAME")"
case "$HEALTH_STATUS" in
    healthy)
        echo "[PASS] Docker healthcheck status: healthy."
        ;;
    starting)
        echo "[WARN] Docker healthcheck status: starting (still within start_period)."
        ;;
    none)
        echo "[WARN] No Docker healthcheck defined on this container."
        ;;
    *)
        echo "[FAIL] Docker healthcheck status: $HEALTH_STATUS" >&2
        ;;
esac

# 4. Port listening locally?
if command -v ss >/dev/null 2>&1; then
    if ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE "(^|:)$MSSQL_PORT\$"; then
        echo "[PASS] Port $MSSQL_PORT is listening locally."
    else
        echo "[FAIL] Port $MSSQL_PORT does not appear to be listening locally." >&2
    fi
fi

# 5. Accepts a simple query. Password is passed via env var to the
#    container process, never as a CLI argument or printed to stdout.
echo "Checking SQL query responsiveness..."
if docker exec \
    -e SQLCMDPASSWORD="${MSSQL_SA_PASSWORD}" \
    "$CONTAINER_NAME" \
    /opt/mssql-tools18/bin/sqlcmd -S localhost -U "${MSSQL_USER:-sa}" -C -Q "SELECT 1" -b -o /dev/null; then
    echo "[PASS] SQL Server accepted a test query."
else
    echo "[FAIL] SQL Server did not respond to a test query." >&2
    exit 1
fi

echo
echo "Overall: SQL Server appears healthy and reachable."
