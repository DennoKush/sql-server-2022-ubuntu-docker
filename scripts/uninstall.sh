#!/usr/bin/env bash
# uninstall.sh — removes the Compose-managed container, in one of two
# explicit modes. Never defaults to deleting data. Never touches Docker
# itself (the engine/daemon) or backup files.
#
# Usage:
#   ./scripts/uninstall.sh --keep-data     # docker compose down
#   ./scripts/uninstall.sh --delete-data   # docker compose down -v (destructive)
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

usage() {
    cat >&2 <<EOF
Usage: $0 --keep-data | --delete-data

  --keep-data     Runs 'docker compose down': removes the container, keeps
                   the sqlserver2022_data volume (your databases) intact.

  --delete-data   Runs 'docker compose down -v': PERMANENTLY DELETES the
                   sqlserver2022_data volume and every database in it.
                   Requires typed confirmation. Backup files under
                   backups/ are never touched by this script.
EOF
    exit 1
}

if [[ $# -ne 1 ]]; then
    usage
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "Error: docker is not installed." >&2
    exit 1
fi

case "$1" in
    --keep-data)
        echo "Mode: keep data."
        echo "This will run: docker compose down"
        echo "The named volume 'sqlserver2022_data' (your databases) will NOT be removed."
        echo "Files under backups/ will NOT be removed."
        echo
        read -r -p "Proceed? [y/N]: " CONFIRM
        if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
            echo "Aborted. No changes made."
            exit 1
        fi
        docker compose down
        echo "Done. Container removed; data volume and backups preserved."
        echo "To redeploy: docker compose up -d"
        ;;

    --delete-data)
        echo "==================== DESTRUCTIVE OPERATION ===================="
        echo "Mode: delete data."
        echo "This will run: docker compose down -v"
        echo
        echo "This PERMANENTLY DELETES the 'sqlserver2022_data' Docker volume,"
        echo "which contains EVERY DATABASE in this SQL Server instance."
        echo "This action CANNOT be undone. There is no recovery except from a"
        echo "backup file you made yourself beforehand under backups/."
        echo
        echo "Files already in backups/ are NOT touched by this script — but"
        echo "nothing will be backed up automatically before deletion either."
        echo "================================================================="
        echo
        read -r -p "Type exactly 'DELETE ALL DATA' to proceed: " CONFIRM
        if [[ "$CONFIRM" != "DELETE ALL DATA" ]]; then
            echo "Confirmation did not match. Aborted — no changes made."
            exit 1
        fi
        docker compose down -v
        echo "Done. Container and data volume removed. Docker itself was not touched."
        ;;

    *)
        usage
        ;;
esac
