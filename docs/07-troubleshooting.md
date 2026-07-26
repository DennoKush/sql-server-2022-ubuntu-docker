# 07 - Troubleshooting

## Unsupported CPU architecture

**Symptom:** `docker compose pull` fails, or the container exits
immediately, on non-`x86_64` hardware (e.g. `aarch64`, Apple Silicon).

**Cause:** The official SQL Server Linux image is built for `amd64` only.

**Fix:** Deploy on `x86_64`/`amd64` hardware, or an `x86_64` VM. Emulation
via QEMU is technically possible but not recommended — expect severe
performance problems and is out of scope for this project.

## Apple Silicon / ARM compatibility

Same root cause as above. If you are on an Apple Silicon Mac or an ARM VM,
run this stack on an `x86_64` host or VM instead (e.g. a cloud instance or
an Intel/AMD machine). Do not attempt to "make it work" via emulation for
anything beyond brief, disposable experiments.

## Insufficient memory

**Symptom:** Container starts, then crashes or becomes unresponsive under
light load; SQL Server error log mentions memory pressure.

**Fix:** Confirm available memory with `free -h`. SQL Server needs at
least ~2 GB to start reliably and considerably more for real workloads.
Close other memory-heavy processes, or move to a host with more RAM.

## Container exits immediately after starting

**Check the logs first — this almost always explains it:**

```bash
docker compose logs sqlserver
```

Common causes:
- `ACCEPT_EULA` not set to `Y`.
- `MSSQL_SA_PASSWORD` missing, empty, or failing complexity requirements
  (see next item).
- Corrupted or incompatible data files in the volume from a much older
  SQL Server version.

## Weak `sa` password rejected at startup

**Symptom:** Log shows an error about the password not meeting policy
requirements, and the container exits.

**Fix:** Edit `.env` and set a password that is at least 8 characters
(16+ recommended) and includes at least 3 of: uppercase, lowercase,
digits, symbols, and does not contain the word "password". Then:

```bash
docker compose down
docker compose up -d
```

## Port 1433 already in use

**Symptom:** `docker compose up -d` fails with a "port is already
allocated" or bind error.

**Diagnose:**

```bash
ss -ltn 'sport = :1433'
```

**Fix:** Either stop whatever else is using port 1433, or change
`MSSQL_PORT` in `.env` to a free port (e.g. `14330`) and re-run
`docker compose up -d`.

## Docker permission denied

**Symptom:** `docker: permission denied while trying to connect to the
Docker daemon socket`.

**Cause:** Your user isn't in the `docker` group, or the group membership
hasn't taken effect in the current shell.

**Fix:** See [02-docker-installation.md](02-docker-installation.md) step 8.
Try `newgrp docker`, or fully log out and back in. Confirm with
`groups` and a non-destructive command like `docker info`.

## SQL Server not ready for connections yet

**Symptom:** Connections are refused immediately after `docker compose up
-d`.

**Cause:** SQL Server takes some time (often 10-30+ seconds) to initialize
on first start.

**Fix:** Wait for `docker compose logs -f sqlserver` to show "SQL Server
is now ready for client connections", or poll with
`./scripts/health-check.sh`, which is designed exactly for this.

## TLS / certificate errors from clients

**Symptom:** Client reports a certificate trust error when connecting.

**Cause:** The container generates a self-signed certificate by default.

**Fix:** For this local development deployment, enable "Trust server
certificate" (equivalent to `sqlcmd -C`) in your client. Do **not** carry
this setting into a production deployment with a real, trusted
certificate.

## `sqlcmd` path differences

Newer SQL Server images (2022 and later) ship `sqlcmd` under
`/opt/mssql-tools18/bin/sqlcmd` and default to requiring encryption,
hence the `-C` flag used throughout this repository's scripts. Older
images used `/opt/mssql-tools/bin/sqlcmd` (no `18` suffix) without that
requirement. If a command in this repo's docs fails with "no such file or
directory", check which tools directory actually exists inside your
container:

```bash
docker exec -it sqlserver2022 ls /opt/ | grep mssql-tools
```

and adjust the path accordingly.

## Container marked "unhealthy"

**Diagnose:**

```bash
docker inspect --format='{{json .State.Health}}' sqlserver2022 | python3 -m json.tool
```

Common causes: SQL Server still starting (wait past `start_period`), wrong
password in the healthcheck's environment vs. the actual `sa` password
(these should always match since both come from `.env`), or SQL Server
genuinely failing internally — check `docker compose logs sqlserver` for
the real error.

## Permission issues on the backup directory

**Symptom:** `BACKUP DATABASE` fails writing to
`/var/opt/mssql/backups/...`.

**Cause:** The container runs SQL Server as a non-root user (`mssql`); if
the host `backups/` directory has restrictive ownership/permissions that
don't allow that UID to write, the backup fails.

**Fix:** Check current permissions with `ls -ld backups/` and adjust as
needed for your environment; avoid overly permissive modes like `777` —
prefer group-based or ACL-based access appropriate to your host's user
model.

## Accidental database volume removal

**Symptom:** All databases are gone after some Docker command.

**Cause:** Almost always `docker compose down -v` (or a manual
`docker volume rm sqlserver2022_data`), which deletes the named volume
that holds `/var/opt/mssql`, including all databases.

**Recovery:** Restore from your most recent backup in `backups/` (see
[05-backup-and-restore.md](05-backup-and-restore.md)). There is no
recovery path if no backup exists — this is precisely why `down -v` is
gated behind explicit confirmation in `scripts/uninstall.sh` and the
Makefile's `destroy` target.
