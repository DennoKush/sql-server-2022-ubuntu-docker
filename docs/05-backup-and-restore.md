# 05 - Backup and Restore

## Where backups live

`docker-compose.yml` mounts the local `./backups` directory into the
container at `/var/opt/mssql/backups`. Any `.bak` file `BACKUP DATABASE`
writes to that container path lands directly in this repository's
`backups/` directory on the host — and is git-ignored (only `.gitkeep` is
tracked), since backups can contain sensitive data and are typically large.

## Creating a backup

```bash
./scripts/backup-database.sh DockerTestDB
```

The script:
1. Validates the database name (alphanumeric/underscore only).
2. Builds a timestamped filename, e.g. `DockerTestDB_20260726_141500.bak`.
3. Runs `sql/backup-database.sql` inside the container via `sqlcmd`,
   passing the database name and target path as `sqlcmd` variables (never
   interpolated into the SQL as raw string concatenation).
4. Confirms the resulting `.bak` file exists under `backups/` and prints
   its path.

No database name defaults implicitly in general use; `DockerTestDB` is
only used as the default when you explicitly run the script with no
arguments, and the script will say so.

## Restoring a backup

**Restoring can overwrite an existing database.** Read the plan the script
prints before confirming.

```bash
./scripts/restore-database.sh backups/DockerTestDB_20260726_141500.bak DockerTestDB
```

The script:
1. Confirms the backup file exists on the host filesystem.
2. Runs `RESTORE FILELISTONLY` against the backup to discover the logical
   file names and types it contains (this varies per backup — it must not
   be hard-coded).
3. Builds the correct `WITH MOVE ... TO ...` clauses from that file list.
4. Prints the full restore plan: source file, target database name, and
   the file mappings it is about to use.
5. Requires you to type an explicit confirmation phrase before proceeding.
6. Does **not** drop or delete any existing database automatically — if
   the target database already exists, `RESTORE DATABASE ... WITH
   REPLACE` is required and the script calls this out explicitly rather
   than assuming it.

## Manual approach (for reference)

```sql
-- Discover logical file names before restoring
RESTORE FILELISTONLY
FROM DISK = '/var/opt/mssql/backups/DockerTestDB_20260726_141500.bak';

-- Restore using the discovered logical names
RESTORE DATABASE DockerTestDB
FROM DISK = '/var/opt/mssql/backups/DockerTestDB_20260726_141500.bak'
WITH MOVE 'DockerTestDB' TO '/var/opt/mssql/data/DockerTestDB.mdf',
     MOVE 'DockerTestDB_log' TO '/var/opt/mssql/data/DockerTestDB_log.ldf',
     REPLACE;
```

See [sql/backup-database.sql](../sql/backup-database.sql) and
[sql/restore-database.sql](../sql/restore-database.sql) for the exact
parameterized templates the scripts use.

## Backup hygiene

- Backups are not automatically rotated or deleted by any script in this
  repository — manage retention yourself.
- Treat `.bak` files as sensitive: they contain full database contents.
- `docker compose down -v` deletes the *volume* (live data), not the
  `backups/` directory — but backups are your recovery path if the volume
  is ever removed, so keep at least one recent backup off the host
  entirely (e.g. copied to external/offsite storage) for anything that
  matters.
