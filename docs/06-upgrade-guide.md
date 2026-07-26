# 06 - Upgrade Guide

This covers upgrading the SQL Server **container image** (e.g. picking up
a new cumulative update within the 2022 line). The named volume
(`sqlserver2022_data`) is preserved across this process, so your databases
are not lost — but you must still back up first, because upgrades are
harder to reverse than to redo.

## Before you start

1. **Take a backup of every database you care about.**
   See [05-backup-and-restore.md](05-backup-and-restore.md).
2. Confirm the current version, for your own records:

   ```bash
   docker exec -it sqlserver2022 \
     /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C \
     -Q "SELECT @@VERSION;"
   ```

3. Read Microsoft's release notes for the target image tag before
   upgrading, particularly for any breaking changes.

## Upgrade procedure

```bash
# 1. Pull the latest image for the 2022 line
docker compose pull                 # [MODIFIES — downloads new image layers]

# 2. Recreate the container using the new image, keeping the same volume
docker compose up -d                # [MODIFIES — replaces container only]

# 3. Watch startup and confirm health
docker compose logs -f sqlserver    # [READ-ONLY]
./scripts/health-check.sh           # [READ-ONLY]
```

Because the named volume `sqlserver2022_data` is declared external to the
container's lifecycle, `docker compose up -d` after a `pull` replaces only
the container — your databases on disk are untouched by this step.

## Pinning a specific version instead of `2022-latest`

For reproducible deployments, consider changing the `image:` tag in
`docker-compose.yml` from `2022-latest` to a specific dated tag (see
Microsoft's container registry / release notes for exact tag names), then
running the same `pull` + `up -d` sequence. This makes upgrades a
deliberate, reviewable change (a one-line diff) rather than an implicit
"latest wins" pull.

## After upgrading

```bash
./scripts/test-connection.sh        # [READ-ONLY]
```

Confirm your key databases are present and queryable:

```sql
SELECT name, state_desc FROM sys.databases;
```

## Rolling back

If an upgrade causes problems:

1. Change `image:` back to the previous known-good tag (or `2022-latest`
   if you were already tracking it and the issue is unrelated to version).
2. `docker compose pull && docker compose up -d`.
3. If the volume's data files were touched by the newer version in a way
   the older version can't read (uncommon within a single major version,
   but possible), restore from the backup you took in step 1 above.

This is precisely why taking a backup before upgrading is not optional.
