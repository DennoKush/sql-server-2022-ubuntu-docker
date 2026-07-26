#!/usr/bin/env bash
# test-connection.sh — read-only: runs sql/verify-installation.sql inside
# the container and prints version/edition/database information.
#
# The sa password is passed to sqlcmd via the SQLCMDPASSWORD environment
# variable on the docker exec call, not as a -P command-line argument, so
# it never appears in `ps` output. It is never printed to the console.
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

CONTAINER_NAME="sqlserver2022"

if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
    echo "Error: .env not found. Run ./scripts/generate-env.sh first." >&2
    exit 1
fi

if [[ ! -f "$PROJECT_ROOT/sql/verify-installation.sql" ]]; then
    echo "Error: sql/verify-installation.sql not found." >&2
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

echo "Running sql/verify-installation.sql inside $CONTAINER_NAME ..."
echo

# Pipe the SQL file over stdin so it does not need to exist inside the
# container filesystem, and pass the password via env var (not -P) so it
# is not visible in the container's process list.
docker exec -i \
    -e SQLCMDPASSWORD="${MSSQL_SA_PASSWORD}" \
    "$CONTAINER_NAME" \
    /opt/mssql-tools18/bin/sqlcmd -S localhost -U "${MSSQL_USER:-sa}" -C \
    < "$PROJECT_ROOT/sql/verify-installation.sql"

echo
echo "Connection test complete."
