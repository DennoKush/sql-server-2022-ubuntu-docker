# SQL Server 2022 on Ubuntu 24.04 via Docker

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Ubuntu 24.04](https://img.shields.io/badge/Platform-Ubuntu%2024.04-E95420?logo=ubuntu&logoColor=white)](https://releases.ubuntu.com/24.04/)
[![Docker Compose](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)](https://docs.docker.com/compose/)
[![SQL Server 2022 Developer](https://img.shields.io/badge/SQL%20Server-2022%20Developer-CC2927?logo=microsoftsqlserver&logoColor=white)](https://www.microsoft.com/en-us/sql-server/sql-server-2022)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnubash&logoColor=white)](scripts/)
[![Architecture: x86_64](https://img.shields.io/badge/Architecture-x86__64%20%2F%20amd64-555555?logo=amd&logoColor=white)](docs/01-prerequisites.md)

A documented, scriptable deployment of **Microsoft SQL Server 2022
Developer Edition** running in Docker on Ubuntu 24.04 LTS ("noble"), using
the official Microsoft container image.

> **Nothing in this repository has been installed, deployed, started, or
> connected to on your machine by generating these files.** Every command
> shown below is for you to run yourself, deliberately, one step at a
> time. See the "Destructive commands" callouts throughout.

## Overview

Ubuntu 24.04 is not a supported target for a *native* `mssql-server`
package installation (Microsoft's native Linux packages target specific
older LTS releases). Docker sidesteps this entirely: Microsoft ships an
official, supported SQL Server 2022 Linux container image
(`mcr.microsoft.com/mssql/server:2022-latest`) that runs identically
regardless of the host distribution, as long as the host is `x86_64`.
This repository wraps that image in Docker Compose, with the surrounding
scripts, documentation, and safety rails needed for a real (if
development-scoped) deployment.

## Features

- Official Microsoft SQL Server 2022 image, unmodified — no custom
  Dockerfile.
- Docker Compose deployment (Compose Specification, no legacy `version:`
  key).
- Persistent named volume (`sqlserver2022_data`) — databases survive
  `stop`/`start`, container recreation, and image upgrades.
- Port 1433 bound to `127.0.0.1` by default — not reachable remotely
  unless you deliberately change it.
- `.env`-based secret handling — the `sa` password never lives in
  `docker-compose.yml`, is `.gitignore`d, and is generated via a
  no-echo interactive script.
- Docker health check plus a standalone `health-check.sh` for
  operational verification.
- SQL verification scripts (`sql/verify-installation.sql`,
  `test-connection.sh`) to confirm the deployment is actually working,
  not just "running".
- Backup and restore scripts with confirmation gates and no hard-coded
  credentials.
- Troubleshooting and security documentation covering the failure modes
  you're actually likely to hit.

## Prerequisites

- Ubuntu 24.04 LTS ("noble").
- `x86_64` / `amd64` processor (the official image does not support ARM,
  including Apple Silicon, without emulation).
- 4 GB RAM minimum, 8 GB+ recommended.
- 10 GB+ free disk space (more for real datasets).
- Docker Engine + Docker Compose plugin, installed from Docker's official
  `apt` repository — see [docs/02-docker-installation.md](docs/02-docker-installation.md).
- Outbound internet access to pull the image from
  `mcr.microsoft.com`.

Run `./scripts/check-prerequisites.sh` (read-only) to verify all of the
above automatically. Full detail: [docs/01-prerequisites.md](docs/01-prerequisites.md).

## Quick start

Commands below are grouped by whether they only **inspect** your system
or **modify** it. Run them yourself, in order.

```bash
git clone <repository-url>
cd sql-server-2022-ubuntu-docker

# Configure secrets — [MODIFIES: creates .env locally, git-ignored]
cp .env.example .env
chmod 600 .env
nano .env                              # set MSSQL_SA_PASSWORD

# Or, interactively and without echoing the password:
# ./scripts/generate-env.sh            # [MODIFIES: creates .env]

# Inspect only — no changes made
./scripts/check-prerequisites.sh
docker compose config

# Deploy — [MODIFIES: pulls image, creates volume + container]
docker compose pull
docker compose up -d

# Inspect only
docker compose ps
docker compose logs -f sqlserver        # Ctrl-C to stop following
```

Wait for the log line `SQL Server is now ready for client connections.`,
or poll with `./scripts/health-check.sh`.

### Equivalent Makefile workflow

```bash
make check      # read-only
make env        # creates .env interactively
make config     # read-only
make pull       # downloads image
make start      # creates/starts container
make health     # read-only
make verify     # read-only, runs sql/verify-installation.sql
```

Run `make help` (or just `make`) to list all targets.

## Connection details

```text
Server:                    localhost
Port:                      1433 (or your MSSQL_PORT from .env)
Username:                  sa
Password:                  the value you set for MSSQL_SA_PASSWORD in .env
Authentication:            SQL Server Authentication
Encrypt:                   Enabled / Mandatory
Trust server certificate:  Enabled (local development only)
Database:                  master
```

Full walkthroughs for `sqlcmd`, DBeaver, Azure Data Studio, and VS Code's
MSSQL extension: [docs/04-connection-guide.md](docs/04-connection-guide.md).

## Client tools

| Tool | Notes |
|---|---|
| `sqlcmd` | Ships inside the container at `/opt/mssql-tools18/bin/sqlcmd`; wrapped by `scripts/test-connection.sh` |
| DBeaver | Use the "SQL Server" (Microsoft) driver, enable trust-server-certificate for this local setup |
| Azure Data Studio | Verify current product/support status against Microsoft's own documentation before depending on it |
| VS Code (MSSQL extension) | Official Microsoft extension; connect with SQL Login auth |

See [docs/04-connection-guide.md](docs/04-connection-guide.md) for step-by-step setup.

## Management commands

```bash
docker compose start                 # start an existing, stopped container
docker compose stop                  # stop without removing anything
docker compose restart               # restart in place
docker compose ps                    # status
docker compose logs -f sqlserver     # follow logs
docker compose pull                  # fetch newer image (see upgrade guide)
docker compose up -d                 # (re)create/start using current image
```

Or via the equivalent wrapper scripts: `scripts/start.sh`, `stop.sh`,
`restart.sh`, `status.sh`, `logs.sh` — each validates Docker/`.env`
availability first and prints what it's about to do.

## Persistence test

Confirms that data survives container restarts because it lives in the
named volume `sqlserver2022_data`, not inside the container itself:

```bash
./scripts/create-test-database.sh   # creates DockerTestDB + one test row
docker restart sqlserver2022        # [MODIFIES: restarts the container]
./scripts/create-test-database.sh   # re-run: prints the SAME existing row
```

You can also verify manually:

```sql
CREATE DATABASE TestDB;
GO
SELECT name, state_desc FROM sys.databases WHERE name = 'TestDB';
GO
```

Then `docker restart sqlserver2022` and re-run the `SELECT` — `TestDB`
should still be listed as `ONLINE`.

## Data persistence: `down` vs `down -v`

| Command | Container | Data volume (`sqlserver2022_data`) | Backups (`backups/`) |
|---|---|---|---|
| `docker compose down` | Removed | **Preserved** | Untouched |
| `docker compose down -v` | Removed | **PERMANENTLY DELETED** | Untouched |

```bash
# Remove the container, keep all databases — safe, reversible via `up -d`
docker compose down
# equivalently: ./scripts/uninstall.sh --keep-data
```

```bash
# ⚠️  DESTRUCTIVE — permanently deletes every database in this instance.
# Do not run without a recent backup and explicit intent.
docker compose down -v
# equivalently, with a required typed confirmation: ./scripts/uninstall.sh --delete-data
```

**Never run `docker compose down -v` (or `./scripts/uninstall.sh
--delete-data`) without deliberate, explicit confirmation** — there is no
recovery except from a backup you made beforehand.

## Backup and restore

```bash
./scripts/backup-database.sh DockerTestDB     # writes backups/DockerTestDB_<timestamp>.bak
./scripts/restore-database.sh backups/DockerTestDB_20260726_141500.bak DockerTestDB
```

The restore script discovers logical file names via `RESTORE
FILELISTONLY`, prints the full restore plan, and requires you to type a
confirmation phrase before touching anything. Full detail, including the
manual SQL, in [docs/05-backup-and-restore.md](docs/05-backup-and-restore.md).

## Upgrading

```bash
# Back up everything first (see above), then:
docker compose pull
docker compose up -d
```

The named volume is preserved across this — only the container is
replaced. Full procedure and rollback notes:
[docs/06-upgrade-guide.md](docs/06-upgrade-guide.md).

## Security

- **`.env` is git-ignored** and must never be committed — it holds the
  `sa` password in plaintext. Protect it with `chmod 600 .env`.
- **Port 1433 is bound to `127.0.0.1`** by default — not reachable from
  other machines regardless of firewall state. Only change this
  deliberately, and only if you understand the exposure.
- **Docker group membership is root-equivalent** on the host — only grant
  it to trusted users.
- **`sa` password complexity is enforced by SQL Server itself** at
  container startup (8+ chars, 3 of 4 character classes, no "password"
  substring); `scripts/generate-env.sh` pre-checks this client-side.
- **Developer Edition is licensed for development/testing only** — not
  production data or workloads.
- **Backups are your only protection** against `down -v`, volume
  corruption, or disk failure — the named volume alone is not a backup
  strategy.
- **Don't use `sa` from applications** — create least-privilege logins
  per application instead.

Full detail: [docs/08-security-notes.md](docs/08-security-notes.md).

## Troubleshooting

Common issues — unsupported architecture, insufficient memory, container
exit loops, weak passwords, port conflicts, Docker permission errors,
"not ready for connections" races, TLS/certificate trust errors,
`sqlcmd` path differences across image versions, unhealthy container
status, backup-directory permission issues, accidental volume removal,
and ARM/Apple Silicon incompatibility — are all covered in
[docs/07-troubleshooting.md](docs/07-troubleshooting.md).

## Documentation index

| Doc | Covers |
|---|---|
| [docs/01-prerequisites.md](docs/01-prerequisites.md) | System requirements and how to check them |
| [docs/02-docker-installation.md](docs/02-docker-installation.md) | Installing Docker Engine + Compose from Docker's official repo |
| [docs/03-sql-server-deployment.md](docs/03-sql-server-deployment.md) | Step-by-step deployment |
| [docs/04-connection-guide.md](docs/04-connection-guide.md) | `sqlcmd`, DBeaver, Azure Data Studio, VS Code |
| [docs/05-backup-and-restore.md](docs/05-backup-and-restore.md) | Backup/restore procedures and scripts |
| [docs/06-upgrade-guide.md](docs/06-upgrade-guide.md) | Safely upgrading the container image |
| [docs/07-troubleshooting.md](docs/07-troubleshooting.md) | Common problems and fixes |
| [docs/08-security-notes.md](docs/08-security-notes.md) | Hardening and risk notes |

## Repository layout

```text
sql-server-2022-ubuntu-docker/
├── .env.example              # Template — copy to .env, never commit the real one
├── .gitignore
├── LICENSE                   # MIT
├── README.md                 # This file
├── docker-compose.yml        # Service definition
├── Makefile                  # Convenience wrappers around scripts/ and docker compose
├── docs/                     # Numbered, task-oriented documentation (see table above)
├── scripts/                  # Bash automation — deployment, health, backup/restore, uninstall
├── sql/                      # Parameterized .sql templates used by scripts/
├── backups/                  # .bak files land here (git-ignored except .gitkeep)
└── data/                     # Reserved for optional host-side inspection use (git-ignored)
```

## License

MIT — see [LICENSE](LICENSE).
