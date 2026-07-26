-- =============================================================================
-- verify-installation.sql
-- Read-only checks confirming SQL Server is installed, running, and healthy.
-- Safe to run at any time; makes no changes to any database.
-- =============================================================================

SET NOCOUNT ON;

PRINT '=== SQL Server Version ===';
SELECT @@VERSION AS server_version;

PRINT '=== Edition / Product Info ===';
SELECT
    SERVERPROPERTY('Edition')          AS edition,
    SERVERPROPERTY('EditionID')        AS edition_id,
    SERVERPROPERTY('ProductVersion')   AS product_version,
    SERVERPROPERTY('ProductLevel')     AS product_level,
    SERVERPROPERTY('ProductUpdateLevel') AS product_update_level,
    SERVERPROPERTY('ServerName')       AS server_name,
    SERVERPROPERTY('MachineName')      AS machine_name,
    SERVERPROPERTY('InstanceName')     AS instance_name;

PRINT '=== Current Database ===';
SELECT DB_NAME() AS current_database;

PRINT '=== Databases and State ===';
SELECT
    name          AS database_name,
    state_desc    AS state,
    recovery_model_desc AS recovery_model,
    create_date
FROM sys.databases
ORDER BY database_id;

PRINT '=== SQL Server Start Time ===';
SELECT sqlserver_start_time
FROM sys.dm_os_sys_info;

PRINT '=== Verification Complete ===';
