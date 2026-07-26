-- =============================================================================
-- restore-database.sql
-- Parameterized restore template, intended to be invoked via sqlcmd with
-- -v variables (see scripts/restore-database.sh). This file is a TEMPLATE:
-- the actual MOVE clauses must be constructed by the calling script after
-- running RESTORE FILELISTONLY, because logical file names vary per backup
-- and cannot be safely hard-coded here.
--
-- Typical invocation performed by scripts/restore-database.sh:
--
--   Step 1 - discover logical file names (read-only, no changes made):
--     sqlcmd -S localhost -U sa -C \
--       -v BackupPath="/var/opt/mssql/backups/DockerTestDB_20260726_141500.bak" \
--       -Q "RESTORE FILELISTONLY FROM DISK = N'$(BackupPath)'"
--
--   Step 2 - perform the restore using the discovered file list:
--     sqlcmd -S localhost -U sa -C -i sql/restore-database.sql \
--       -v DatabaseName="DockerTestDB" \
--       -v BackupPath="/var/opt/mssql/backups/DockerTestDB_20260726_141500.bak" \
--       -v DataFile="DockerTestDB" \
--       -v DataFileTarget="/var/opt/mssql/data/DockerTestDB.mdf" \
--       -v LogFile="DockerTestDB_log" \
--       -v LogFileTarget="/var/opt/mssql/data/DockerTestDB_log.ldf" \
--       -v ReplaceExisting="0"
-- =============================================================================

SET NOCOUNT ON;

PRINT 'Restore plan:';
PRINT '  Database:    $(DatabaseName)';
PRINT '  Source file: $(BackupPath)';
PRINT '  Data file -> $(DataFileTarget)';
PRINT '  Log file  -> $(LogFileTarget)';
PRINT '  REPLACE existing database: $(ReplaceExisting)';

-- The calling script is responsible for confirming with the user BEFORE
-- this file executes. This template does not prompt interactively itself
-- (sqlcmd scripts cannot safely gate on interactive confirmation mid-script).

IF '$(ReplaceExisting)' = '1'
BEGIN
    RESTORE DATABASE [$(DatabaseName)]
    FROM DISK = N'$(BackupPath)'
    WITH
        MOVE '$(DataFile)' TO N'$(DataFileTarget)',
        MOVE '$(LogFile)'  TO N'$(LogFileTarget)',
        REPLACE,
        STATS = 10;
END
ELSE
BEGIN
    RESTORE DATABASE [$(DatabaseName)]
    FROM DISK = N'$(BackupPath)'
    WITH
        MOVE '$(DataFile)' TO N'$(DataFileTarget)',
        MOVE '$(LogFile)'  TO N'$(LogFileTarget)',
        STATS = 10;
END
GO

PRINT 'Restore completed. Verifying database state...';

SELECT name, state_desc
FROM sys.databases
WHERE name = '$(DatabaseName)';
GO
