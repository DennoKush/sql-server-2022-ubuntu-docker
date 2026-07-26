#!/usr/bin/env bash
# create-test-database.sh — runs sql/create-test-database.sql inside the
# container to create DockerTestDB, a demo schema, and one test row.
# Intended as a persistence-test fixture (see README "Persistence test").
#
# The sa password is passed via SQLCMDPASSWORD env var, never as a CLI
# argument, and never printed.
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

CONTAINER_NAME="sqlserver2022"

if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
    echo "Error: .env not found. Run ./scripts/generate-env.sh first." >&2
    exit 1
fi

if [[ ! -f "$PROJECT_ROOT/sql/create-test-database.sql" ]]; then
    echo "Error: sql/create-test-database.sql not found." >&2
    exit 1
fi

# shellcheck disable=SC1091
set -a
source "$PROJECT_ROOT/.env"
set +a

if ! docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    echo "Error: container '$CONTAINER_NAME' does not exist. Run ./scripts/start.sh first." >&2
    exit 1
fi

echo "Creating DockerTestDB (idempotent — safe to re-run)..."
echo

docker exec -i \
    -e SQLCMDPASSWORD="${MSSQL_SA_PASSWORD}" \
    "$CONTAINER_NAME" \
    /opt/mssql-tools18/bin/sqlcmd -S localhost -U "${MSSQL_USER:-sa}" -C \
    < "$PROJECT_ROOT/sql/create-test-database.sql"

echo
echo "Done. To test persistence, run:"
echo "  docker compose restart"
echo "  ./scripts/create-test-database.sh   # re-run: should show the existing row, not duplicate the table"
