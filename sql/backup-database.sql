-- =============================================================================
-- backup-database.sql
-- Parameterized backup template, intended to be invoked via sqlcmd with
-- -v variables (see scripts/backup-database.sh), e.g.:
--
--   sqlcmd -S localhost -U sa -C -i sql/backup-database.sql \
--     -v DatabaseName="DockerTestDB" \
--     -v BackupPath="/var/opt/mssql/backups/DockerTestDB_20260726_141500.bak"
--
-- Do not hard-code a database name or path here — both are supplied
-- externally so this template stays reusable and injection-safe (sqlcmd
-- variables are substituted before parsing, not concatenated as strings
-- inside application code).
-- =============================================================================

SET NOCOUNT ON;

PRINT 'Starting backup of database [$(DatabaseName)] to $(BackupPath) ...';

BACKUP DATABASE [$(DatabaseName)]
TO DISK = N'$(BackupPath)'
WITH
    FORMAT,
    INIT,
    NAME = N'$(DatabaseName)-full-backup',
    SKIP,
    NOREWIND,
    NOUNLOAD,
    STATS = 10;
GO

PRINT 'Backup command completed. Verifying backup set...';

RESTORE VERIFYONLY
FROM DISK = N'$(BackupPath)';
GO

PRINT 'Backup verified successfully.';
