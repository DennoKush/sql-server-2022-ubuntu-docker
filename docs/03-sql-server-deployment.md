# 03 - SQL Server Deployment

This page walks through deploying SQL Server 2022 Developer Edition using
the `docker-compose.yml` in this repository. Commands that only **inspect**
configuration are marked accordingly; commands that **change state** on your
machine are marked as well.

## 1. Configure environment variables

Copy the template and protect it before editing:

```bash
cp .env.example .env       # creates your local, git-ignored .env  [MODIFIES]
chmod 600 .env              # owner-only read/write               [MODIFIES]
nano .env                   # set MSSQL_SA_PASSWORD, etc.          [MODIFIES]
```

Alternatively, use the interactive helper, which prompts for the password
without echoing it to the terminal or shell history:

```bash
./scripts/generate-env.sh   # [MODIFIES — creates .env]
```

See [.env.example](../.env.example) for the full list of variables and
SQL Server's password complexity rules.

## 2. Check prerequisites

```bash
./scripts/check-prerequisites.sh   # [READ-ONLY]
```

This confirms architecture, OS version, memory, disk space, Docker
availability, and port 1433 availability without changing anything.

## 3. Review the resolved configuration

```bash
docker compose config   # [READ-ONLY]
```

This renders the final Compose configuration with all environment
variables substituted (except that `MSSQL_SA_PASSWORD` will appear in the
output on your local terminal — do not paste this output anywhere public).

## 4. Pull the image

```bash
docker compose pull   # [MODIFIES — downloads image layers]
```

Downloads `mcr.microsoft.com/mssql/server:2022-latest` from Microsoft
Container Registry. No custom image is built; the official image is used
unmodified.

## 5. Start the container

```bash
docker compose up -d   # [MODIFIES — creates & starts container + volume]
```

This creates:
- The named volume `sqlserver2022_data` (first run only)
- The container `sqlserver2022`, bound to `127.0.0.1:1433` on the host

## 6. Watch it come up

```bash
docker compose ps                      # [READ-ONLY]
docker compose logs -f sqlserver       # [READ-ONLY, streams until Ctrl-C]
```

Wait for a log line similar to:

```text
SQL Server is now ready for client connections.
```

Or use the bundled health check, which polls automatically:

```bash
./scripts/health-check.sh   # [READ-ONLY]
```

## 7. Verify with a real query

```bash
./scripts/test-connection.sh   # [READ-ONLY]
```

This runs `sql/verify-installation.sql` inside the container and prints
version/edition information. See
[04-connection-guide.md](04-connection-guide.md) for manual connection
instructions and GUI client setup.

## What's next

- Create a test database and confirm persistence:
  see the "Persistence test" section in the main [README.md](../README.md).
- Set up backups: [05-backup-and-restore.md](05-backup-and-restore.md).
- Review hardening notes: [08-security-notes.md](08-security-notes.md).
