# 04 - Connection Guide

## Connection parameters

Once the container is running and healthy, use these settings from any
client on the same host (recall that port 1433 is bound to `127.0.0.1` by
default, so only local clients can connect):

```text
Server:                 localhost
Port:                   1433  (or the value of MSSQL_PORT in your .env)
Username:               sa
Password:               the value you set for MSSQL_SA_PASSWORD in .env
Authentication:         SQL Server Authentication
Encrypt:                Enabled / Mandatory
Trust server certificate: Enabled (local development only — the container
                           uses a self-signed certificate)
Database:               master (or any database you create)
```

## `sqlcmd` (from inside the container)

The official image ships `sqlcmd` under `mssql-tools18` at:

```text
/opt/mssql-tools18/bin/sqlcmd
```

(Older images used `/opt/mssql-tools/bin/sqlcmd` without the `18` suffix
and without requiring `-C`/`-N` for encryption; if you're on an older
image, adjust accordingly.)

Example — do not put the password on the command line or shell history;
`sqlcmd` will prompt for it interactively if you omit `-P`:

```bash
docker exec -it sqlserver2022 \
  /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C
```

Or use the wrapper script, which reads the password securely from `.env`:

```bash
./scripts/test-connection.sh
```

## `sqlcmd` (from the host, if installed)

If you install the `mssql-tools18` package on the Ubuntu host itself, you
can connect the same way but targeting `localhost,1433`:

```bash
sqlcmd -S localhost,1433 -U sa -C
```

## DBeaver

1. **Database → New Database Connection → SQL Server** (Microsoft SQL
   Server driver, not the "jTDS" legacy driver).
2. Host: `localhost`, Port: `1433`, Database: `master`.
3. Authentication: SQL Server Authentication — username `sa`, password from
   your `.env`.
4. Under the **SSL** or **Driver properties** tab, set `encrypt=true` and
   `trustServerCertificate=true` (this mirrors `-C` in `sqlcmd`, and is
   appropriate for this local, self-signed-certificate deployment only).
5. Test Connection, then Finish.

## Azure Data Studio

Azure Data Studio can connect to SQL Server 2022 using the same
parameters (Server: `localhost,1433`, Authentication type: SQL Login).

Note on product status: verify Azure Data Studio's current support and
release status directly from Microsoft's official documentation before
relying on it for new work, as tooling support timelines change over time
and are not something this repository can guarantee to be current.

## Visual Studio Code (MSSQL extension)

1. Install the official **SQL Server (mssql)** extension from Microsoft.
2. Command Palette → **MS SQL: Connect**.
3. Server: `localhost,1433`; Authentication Type: `SQL Login`;
   User name: `sa`; Password: from `.env`; Encrypt: `Mandatory` (or
   `Optional` with "Trust Server Certificate" enabled for this local,
   self-signed setup).
4. Save the connection profile (optionally without the password, so it
   prompts each time).

## A note on credentials in GUI tools

Most GUI clients store saved passwords in their own local credential
store. Treat any machine where you've saved the `sa` password in a GUI
tool as holding a copy of that secret, and rotate the password if that
machine's user profile is ever shared or compromised.
