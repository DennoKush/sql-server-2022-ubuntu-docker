-- =============================================================================
-- create-test-database.sql
-- Creates a small, disposable test database used to confirm the
-- deployment works end-to-end, including data persistence across
-- container restarts.
-- =============================================================================

SET NOCOUNT ON;

-- 1. Create the database only if it does not already exist.
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'DockerTestDB')
BEGIN
    PRINT 'Creating database DockerTestDB...';
    CREATE DATABASE DockerTestDB;
END
ELSE
BEGIN
    PRINT 'Database DockerTestDB already exists — skipping creation.';
END
GO

USE DockerTestDB;
GO

-- 2. Create a dedicated schema rather than using dbo directly.
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'demo')
BEGIN
    EXEC('CREATE SCHEMA demo');
    PRINT 'Created schema demo.';
END
ELSE
BEGIN
    PRINT 'Schema demo already exists — skipping creation.';
END
GO

-- 3. Create the test table.
IF NOT EXISTS (
    SELECT 1 FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = N'demo' AND t.name = N'installation_test'
)
BEGIN
    CREATE TABLE demo.installation_test (
        id            INT IDENTITY(1,1) PRIMARY KEY,
        message       NVARCHAR(200)     NOT NULL,
        created_at    DATETIME2(0)      NOT NULL DEFAULT SYSUTCDATETIME()
    );
    PRINT 'Created table demo.installation_test.';
END
ELSE
BEGIN
    PRINT 'Table demo.installation_test already exists — skipping creation.';
END
GO

-- 4. Insert one test record.
INSERT INTO demo.installation_test (message)
VALUES (N'SQL Server 2022 Docker deployment verified successfully.');
GO

-- 5. Query it back.
PRINT '=== demo.installation_test contents ===';
SELECT id, message, created_at
FROM demo.installation_test
ORDER BY id;
GO

-- 6. Verification summary output.
PRINT '=== Database Verification Summary ===';
SELECT
    DB_NAME()                                   AS current_database,
    (SELECT COUNT(*) FROM demo.installation_test) AS row_count,
    SERVERPROPERTY('Edition')                   AS edition;
GO
