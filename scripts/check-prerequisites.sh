#!/usr/bin/env bash
# check-prerequisites.sh
#
# Inspects the host system and reports whether it meets the requirements
# for deploying SQL Server 2022 via Docker. This script is READ-ONLY: it
# never installs, modifies, or configures anything.
#
# Exit code: 0 if no critical failures, non-zero if any critical
# prerequisite is missing.
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Minimum recommended resources.
MIN_MEM_MB=4096
MIN_DISK_GB=10

PASS=0
WARN=0
FAIL=0

pass() { printf '  [PASS] %s\n' "$1"; PASS=$((PASS + 1)); }
warn() { printf '  [WARN] %s\n' "$1"; WARN=$((WARN + 1)); }
fail() { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }

echo "=== SQL Server 2022 Docker Deployment — Prerequisite Check ==="
echo "(read-only: this script makes no changes to your system)"
echo

# -----------------------------------------------------------------------
# Operating system
# -----------------------------------------------------------------------
echo "-- Operating System --"
if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    if [[ "${ID:-}" == "ubuntu" ]]; then
        if [[ "${VERSION_ID:-}" == "24.04" ]]; then
            pass "Ubuntu ${VERSION_ID} (${VERSION_CODENAME:-unknown}) detected"
        else
            warn "Ubuntu detected but version is ${VERSION_ID:-unknown}, not 24.04 (project was validated on 24.04)"
        fi
    else
        warn "Non-Ubuntu distribution detected: ${ID:-unknown} (project targets Ubuntu 24.04)"
    fi
else
    warn "/etc/os-release not found — cannot confirm OS"
fi
echo

# -----------------------------------------------------------------------
# Architecture
# -----------------------------------------------------------------------
echo "-- CPU Architecture --"
ARCH="$(uname -m)"
if [[ "$ARCH" == "x86_64" || "$ARCH" == "amd64" ]]; then
    pass "Architecture is $ARCH"
else
    fail "Architecture is $ARCH — the official SQL Server image requires x86_64/amd64"
fi
echo

# -----------------------------------------------------------------------
# Memory
# -----------------------------------------------------------------------
echo "-- Memory --"
if command -v free >/dev/null 2>&1; then
    MEM_TOTAL_MB="$(free -m | awk '/^Mem:/{print $2}')"
    if [[ "$MEM_TOTAL_MB" -ge "$MIN_MEM_MB" ]]; then
        pass "Total memory ${MEM_TOTAL_MB} MiB (>= ${MIN_MEM_MB} MiB recommended minimum)"
    else
        warn "Total memory ${MEM_TOTAL_MB} MiB is below the recommended ${MIN_MEM_MB} MiB — SQL Server may be unstable"
    fi
else
    warn "'free' command not available — cannot check memory"
fi
echo

# -----------------------------------------------------------------------
# Disk space (checked against this project's directory, and Docker's
# default data root if it exists)
# -----------------------------------------------------------------------
echo "-- Disk Space --"
check_disk() {
    local path="$1" label="$2"
    if [[ -e "$path" ]]; then
        local avail_kb avail_gb
        avail_kb="$(df -Pk "$path" | awk 'NR==2{print $4}')"
        avail_gb=$((avail_kb / 1024 / 1024))
        if [[ "$avail_gb" -ge "$MIN_DISK_GB" ]]; then
            pass "$label: ${avail_gb} GiB available (>= ${MIN_DISK_GB} GiB recommended)"
        else
            warn "$label: only ${avail_gb} GiB available (< ${MIN_DISK_GB} GiB recommended)"
        fi
    fi
}
check_disk "$PROJECT_ROOT" "Project directory ($PROJECT_ROOT)"
check_disk "/var/lib/docker" "Docker data root (/var/lib/docker)"
echo

# -----------------------------------------------------------------------
# Docker
# -----------------------------------------------------------------------
echo "-- Docker Engine --"
if command -v docker >/dev/null 2>&1; then
    DOCKER_VERSION="$(docker --version 2>/dev/null || true)"
    pass "Docker installed: $DOCKER_VERSION"
else
    fail "Docker is not installed — see docs/02-docker-installation.md"
fi
echo

echo "-- Docker Compose Plugin --"
if docker compose version >/dev/null 2>&1; then
    COMPOSE_VERSION="$(docker compose version 2>/dev/null || true)"
    pass "Docker Compose plugin available: $COMPOSE_VERSION"
else
    fail "Docker Compose plugin ('docker compose') is not available — see docs/02-docker-installation.md"
fi
echo

# -----------------------------------------------------------------------
# Docker daemon access (without sudo)
# -----------------------------------------------------------------------
echo "-- Docker Daemon Access --"
if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
        pass "Docker daemon is reachable without sudo"
    else
        warn "Docker daemon not reachable as current user — you may need 'sudo', group membership, or a new login session (see docs/02-docker-installation.md)"
    fi
fi
echo

# -----------------------------------------------------------------------
# Port 1433
# -----------------------------------------------------------------------
echo "-- Port 1433 Availability --"
if command -v ss >/dev/null 2>&1; then
    if ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE '(^|:)1433$'; then
        warn "Something is already listening on port 1433 — set MSSQL_PORT in .env to an alternate port, or stop the conflicting service"
    else
        pass "Port 1433 is free"
    fi
else
    warn "'ss' command not available — cannot check port 1433"
fi
echo

# -----------------------------------------------------------------------
# Required project files
# -----------------------------------------------------------------------
echo "-- Required Project Files --"
required_files=(
    "docker-compose.yml"
    ".env.example"
)
for f in "${required_files[@]}"; do
    if [[ -f "$PROJECT_ROOT/$f" ]]; then
        pass "Found $f"
    else
        fail "Missing $f"
    fi
done

if [[ -f "$PROJECT_ROOT/.env" ]]; then
    pass "Found .env (ready to deploy)"
else
    warn ".env not found yet — run ./scripts/generate-env.sh or 'cp .env.example .env'"
fi
echo

# -----------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------
echo "=== Summary ==="
echo "  Passed:   $PASS"
echo "  Warnings: $WARN"
echo "  Failed:   $FAIL"
echo

if [[ "$FAIL" -gt 0 ]]; then
    echo "Result: FAIL — resolve the failed items above before deploying."
    exit 1
fi

echo "Result: OK — no critical prerequisites missing."
exit 0
