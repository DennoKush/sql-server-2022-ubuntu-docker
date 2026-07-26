#!/usr/bin/env bash
# generate-env.sh
#
# Interactively creates .env from .env.example, prompting for the SQL
# Server sa password without echoing it and without ever printing it back
# or leaving it in shell history. Run this yourself; nothing else in this
# repository invokes it automatically.
#
# Refuses to overwrite an existing .env.
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"
ENV_EXAMPLE="$PROJECT_ROOT/.env.example"

if [[ -f "$ENV_FILE" ]]; then
    echo "Error: $ENV_FILE already exists. Refusing to overwrite it." >&2
    echo "Delete or rename it yourself first if you intend to regenerate it." >&2
    exit 1
fi

if [[ ! -f "$ENV_EXAMPLE" ]]; then
    echo "Error: template file not found at $ENV_EXAMPLE" >&2
    exit 1
fi

# Basic client-side complexity check. SQL Server performs the
# authoritative check at container startup; this is only a fast local
# sanity check to avoid an obviously-doomed round trip.
password_meets_complexity() {
    local pw="$1"
    local categories=0
    [[ "$pw" =~ [A-Z] ]] && categories=$((categories + 1))
    [[ "$pw" =~ [a-z] ]] && categories=$((categories + 1))
    [[ "$pw" =~ [0-9] ]] && categories=$((categories + 1))
    [[ "$pw" =~ [^a-zA-Z0-9] ]] && categories=$((categories + 1))

    if [[ ${#pw} -lt 8 ]]; then
        echo "Password must be at least 8 characters (16+ recommended)." >&2
        return 1
    fi
    if [[ "$categories" -lt 3 ]]; then
        echo "Password must include at least 3 of: uppercase, lowercase, digit, symbol." >&2
        return 1
    fi
    if [[ "${pw,,}" == *password* ]]; then
        echo "Password must not contain the word 'password'." >&2
        return 1
    fi
    return 0
}

echo "=== Generate .env for SQL Server 2022 Docker deployment ==="
echo "This will create $ENV_FILE"
echo "The password you enter will NOT be echoed to the screen and will NOT be printed by this script."
echo

SA_PASSWORD=""
SA_PASSWORD_CONFIRM=""

while true; do
    read -r -s -p "Enter a new sa password: " SA_PASSWORD
    echo
    read -r -s -p "Confirm sa password: " SA_PASSWORD_CONFIRM
    echo

    if [[ "$SA_PASSWORD" != "$SA_PASSWORD_CONFIRM" ]]; then
        echo "Passwords do not match. Try again." >&2
        continue
    fi

    if ! password_meets_complexity "$SA_PASSWORD"; then
        echo "Try again." >&2
        continue
    fi

    break
done

read -r -p "Enter the host port to bind (default 1433): " MSSQL_PORT_INPUT
MSSQL_PORT_VALUE="${MSSQL_PORT_INPUT:-1433}"

echo
read -r -p "Write .env with these settings? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborted. No file was written."
    exit 1
fi

# Write without ever echoing the password to the terminal.
{
    echo "MSSQL_SA_PASSWORD=${SA_PASSWORD}"
    echo "MSSQL_PORT=${MSSQL_PORT_VALUE}"
    echo "MSSQL_DATABASE=master"
    echo "MSSQL_USER=sa"
} > "$ENV_FILE"

chmod 600 "$ENV_FILE"

# Clear sensitive variables from the shell as a defensive measure.
unset SA_PASSWORD SA_PASSWORD_CONFIRM

echo
echo "Created $ENV_FILE with permissions 600."
echo "The password was not printed and is not present in shell history from this script."
echo "Next: ./scripts/check-prerequisites.sh, then docker compose up -d"
