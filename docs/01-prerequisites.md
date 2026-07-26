# 01 - Prerequisites

This page lists everything that must be true about the host machine before
you attempt to deploy SQL Server 2022 in Docker. All commands on this page
are **read-only / inspection commands** — none of them modify the system.

## Target environment

| Item | Requirement |
|---|---|
| Operating system | Ubuntu 24.04.3 LTS ("noble") |
| Architecture | `x86_64` / `amd64` (SQL Server's Linux container does **not** support ARM, including Apple Silicon, without emulation) |
| Memory | 4 GB minimum for SQL Server itself; 8 GB+ recommended for comfortable development use |
| Disk space | At least 10 GB free for the image, container, and initial data files; more if you plan to load real datasets |
| Docker Engine | Installed via Docker's official `apt` repository (see [02-docker-installation.md](02-docker-installation.md)) |
| Docker Compose plugin | `docker compose` (v2, plugin form) — not the legacy standalone `docker-compose` |
| Network | Outbound internet access to pull `mcr.microsoft.com/mssql/server:2022-latest` |

## Checking each requirement manually

These are the same checks performed automatically by
[`scripts/check-prerequisites.sh`](../scripts/check-prerequisites.sh). None
of them change system state.

### Operating system and version

```bash
cat /etc/os-release
```

Look for `ID=ubuntu` and `VERSION_ID="24.04"`.

### CPU architecture

```bash
uname -m
```

Expected output: `x86_64`. Anything else (e.g. `aarch64`) is **not supported**
by the official SQL Server Linux container without emulation, and emulation
is not recommended for anything beyond light experimentation.

### Memory

```bash
free -h
```

Look at the `total` column for `Mem:`. SQL Server will start with less than
4 GB but may be unstable under load; the container also imposes its own
internal memory ceiling relative to what the host reports.

### Disk space

```bash
df -h /
```

Check the `Avail` column on the filesystem that will hold Docker's data
directory (`/var/lib/docker` by default) and this project's directory.

### Docker presence

```bash
docker --version
docker compose version
```

If either command fails with "command not found", follow
[02-docker-installation.md](02-docker-installation.md).

### Docker group / permissions

```bash
groups "$USER"
docker info >/dev/null 2>&1 && echo "Docker accessible without sudo" || echo "Docker requires sudo or group membership"
```

### Port availability

```bash
ss -ltn 'sport = :1433'
```

If this prints a line, something is already listening on port 1433 —
either change `MSSQL_PORT` in `.env` or stop the conflicting service.

## Next step

Once these checks pass, continue to
[02-docker-installation.md](02-docker-installation.md) if Docker is not yet
installed, or directly to
[03-sql-server-deployment.md](03-sql-server-deployment.md) if it is.
