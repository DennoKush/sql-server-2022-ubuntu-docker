#!/usr/bin/env bash
# restore-database.sh — restores a .bak file into a target database.
#
# Usage:
#   ./scripts/restore-database.sh <backup-file> <TargetDatabaseName>
#
# Restoring can OVERWRITE an existing database. This script:
#   1. Validates the backup file exists.
#   2. Runs RESTORE FILELISTONLY (read-only) to discover logical file names.
#   3. Builds the MOVE clauses from that discovery.
#   4. Prints the full restore plan.
#   5. Requires an explicit typed confirmation before restoring.
#   6. Refuses to silently REPLACE an existing database — it tells you to
#      pass --replace explicitly if that's what you intend.
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

CONTAINER_NAME="sqlserver2022"
REPLACE_EXISTING="0"
ARGS=()

for arg in "$@"; do
    case "$arg" in
        --replace)
            REPLACE_EXISTING="1"
            ;;
        *)
            ARGS+=("$arg")
            ;;
    esac
done

if [[ "${#ARGS[@]}" -lt 2 ]]; then
    echo "Usage: $0 <backup-file-path-or-name> <TargetDatabaseName> [--replace]" >&2
    echo "Example: $0 backups/DockerTestDB_20260726_141500.bak DockerTestDB" >&2
    exit 1
fi

BACKUP_ARG="${ARGS[0]}"
DB_NAME="${ARGS[1]}"

if [[ ! "$DB_NAME" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "Error: invalid database name '$DB_NAME'. Only letters, digits, and underscores are allowed." >&2
    exit 1
fi

# Resolve the backup file relative to the project root if a bare filename
# or a backups/-relative path was given.
if [[ -f "$BACKUP_ARG" ]]; then
    HOST_BACKUP_PATH="$(cd "$(dirname "$BACKUP_ARG")" && pwd)/$(basename "$BACKUP_ARG")"
elif [[ -f "$PROJECT_ROOT/backups/$(basename "$BACKUP_ARG")" ]]; then
    HOST_BACKUP_PATH="$PROJECT_ROOT/backups/$(basename "$BACKUP_ARG")"
else
    echo "Error: backup file not found: $BACKUP_ARG" >&2
    exit 1
fi

BACKUP_FILENAME="$(basename "$HOST_BACKUP_PATH")"
CONTAINER_BACKUP_PATH="/var/opt/mssql/backups/${BACKUP_FILENAME}"

if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
    echo "Error: .env not found. Run ./scripts/generate-env.sh first." >&2
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

run_sqlcmd() {
    docker exec -i \
        -e SQLCMDPASSWORD="${MSSQL_SA_PASSWORD}" \
        "$CONTAINER_NAME" \
        /opt/mssql-tools18/bin/sqlcmd -S localhost -U "${MSSQL_USER:-sa}" -C "$@"
}

echo "Step 1/4: Discovering logical file names via RESTORE FILELISTONLY (read-only)..."
FILELIST_OUTPUT="$(run_sqlcmd -h -1 -W -Q "SET NOCOUNT ON; RESTORE FILELISTONLY FROM DISK = N'${CONTAINER_BACKUP_PATH}';")"

# FILELISTONLY's first two columns are LogicalName and PhysicalName,
# space/tab-delimited by sqlcmd's default formatting. We take the first
# row as the data file and the second as the log file, which matches
# standard single-file-group SQL Server backups. Backups with additional
# filegroups need manual restoration — this script intentionally does not
# guess at more complex layouts.
DATA_LOGICAL="$(awk 'NR==1{print $1}' <<< "$FILELIST_OUTPUT")"
LOG_LOGICAL="$(awk 'NR==2{print $1}' <<< "$FILELIST_OUTPUT")"

if [[ -z "$DATA_LOGICAL" || -z "$LOG_LOGICAL" ]]; then
    echo "Error: could not determine logical file names from RESTORE FILELISTONLY output:" >&2
    echo "$FILELIST_OUTPUT" >&2
    exit 1
fi

DATA_TARGET="/var/opt/mssql/data/${DB_NAME}.mdf"
LOG_TARGET="/var/opt/mssql/data/${DB_NAME}_log.ldf"

echo
echo "Step 2/4: Restore plan"
echo "  Backup file (container path): $CONTAINER_BACKUP_PATH"
echo "  Backup file (host path):      $HOST_BACKUP_PATH"
echo "  Target database:              $DB_NAME"
echo "  Data file:  $DATA_LOGICAL -> $DATA_TARGET"
echo "  Log file:   $LOG_LOGICAL -> $LOG_TARGET"
if [[ "$REPLACE_EXISTING" == "1" ]]; then
    echo "  REPLACE existing database:    YES (--replace was passed)"
else
    echo "  REPLACE existing database:    NO"
fi
echo

EXISTING_DB="$(run_sqlcmd -h -1 -W -Q "SET NOCOUNT ON; SELECT name FROM sys.databases WHERE name = '${DB_NAME}';" 2>/dev/null | tr -d '[:space:]')"
if [[ -n "$EXISTING_DB" ]]; then
    if [[ "$REPLACE_EXISTING" != "1" ]]; then
        echo "Error: database '$DB_NAME' already exists. This restore would need to overwrite it." >&2
        echo "Re-run with --replace to explicitly allow overwriting the existing database." >&2
        exit 1
    else
        echo "WARNING: database '$DB_NAME' already exists and WILL BE OVERWRITTEN."
    fi
fi

echo "Step 3/4: Confirmation required."
echo "Type exactly: RESTORE ${DB_NAME}"
read -r -p "> " CONFIRMATION
if [[ "$CONFIRMATION" != "RESTORE ${DB_NAME}" ]]; then
    echo "Confirmation did not match. Aborted — no changes made."
    exit 1
fi

echo
echo "Step 4/4: Restoring..."
run_sqlcmd \
    -v DatabaseName="$DB_NAME" \
    -v BackupPath="$CONTAINER_BACKUP_PATH" \
    -v DataFile="$DATA_LOGICAL" \
    -v DataFileTarget="$DATA_TARGET" \
    -v LogFile="$LOG_LOGICAL" \
    -v LogFileTarget="$LOG_TARGET" \
    -v ReplaceExisting="$REPLACE_EXISTING" \
    < "$PROJECT_ROOT/sql/restore-database.sql"

echo
echo "Restore complete for database '$DB_NAME'."
