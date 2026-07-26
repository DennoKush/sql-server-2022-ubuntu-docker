#!/usr/bin/env bash
# backup-database.sh — creates a timestamped .bak file for the given
# database, written to ./backups on the host (mounted into the container
# at /var/opt/mssql/backups).
#
# Usage:
#   ./scripts/backup-database.sh <DatabaseName>
#   ./scripts/backup-database.sh              # defaults to DockerTestDB
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

CONTAINER_NAME="sqlserver2022"
DEFAULT_DB="DockerTestDB"
DB_NAME="${1:-$DEFAULT_DB}"

if [[ "$1" == "" || -z "${1:-}" ]]; then
    echo "No database name given — defaulting to '$DEFAULT_DB' (documented default)."
fi

# Validate database name: letters, digits, underscore only. This value is
# interpolated into a T-SQL identifier ([$(DatabaseName)]) via sqlcmd -v,
# so it must be restricted to safe characters up front.
if [[ ! "$DB_NAME" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "Error: invalid database name '$DB_NAME'. Only letters, digits, and underscores are allowed, and it must not start with a digit." >&2
    exit 1
fi

if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
    echo "Error: .env not found. Run ./scripts/generate-env.sh first." >&2
    exit 1
fi

if [[ ! -f "$PROJECT_ROOT/sql/backup-database.sql" ]]; then
    echo "Error: sql/backup-database.sql not found." >&2
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

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILENAME="${DB_NAME}_${TIMESTAMP}.bak"
CONTAINER_BACKUP_PATH="/var/opt/mssql/backups/${BACKUP_FILENAME}"
HOST_BACKUP_PATH="$PROJECT_ROOT/backups/${BACKUP_FILENAME}"

echo "Backing up database '$DB_NAME' ..."
echo "  Target (container path): $CONTAINER_BACKUP_PATH"
echo "  Target (host path):      $HOST_BACKUP_PATH"
echo

# The SQL template is piped over stdin so it never needs to exist inside
# the container filesystem.
docker exec -i \
    -e SQLCMDPASSWORD="${MSSQL_SA_PASSWORD}" \
    "$CONTAINER_NAME" \
    /opt/mssql-tools18/bin/sqlcmd -S localhost -U "${MSSQL_USER:-sa}" -C \
    -v DatabaseName="$DB_NAME" \
    -v BackupPath="$CONTAINER_BACKUP_PATH" \
    < "$PROJECT_ROOT/sql/backup-database.sql"

echo
if [[ -f "$HOST_BACKUP_PATH" ]]; then
    echo "Backup file confirmed on host: $HOST_BACKUP_PATH"
    ls -lh "$HOST_BACKUP_PATH"
else
    echo "Error: expected backup file was not found at $HOST_BACKUP_PATH" >&2
    exit 1
fi
