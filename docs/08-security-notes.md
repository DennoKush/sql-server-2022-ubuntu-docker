# 08 - Security Notes

## Why `.env` must never be committed

`.env` holds the `sa` password in plaintext. Git history is effectively
permanent — even a later "remove the secret" commit leaves it recoverable
in earlier commits/reflog/forks. `.gitignore` in this repository excludes
`.env` by name; only `.env.example` (a template with a placeholder) is
tracked. If a real password is ever accidentally committed, treat it as
compromised: rotate it, and consider the repository's history tainted.

## Why port 1433 is bound to `127.0.0.1`

`docker-compose.yml` binds as `127.0.0.1:${MSSQL_PORT}:1433`, not
`0.0.0.0:${MSSQL_PORT}:1433`. This means SQL Server is reachable only from
processes on the same host — not from other machines on your LAN or the
internet — regardless of your firewall configuration. This is the
project's default because SQL Server should never be directly exposed to
untrusted networks.

## Risks of exposing SQL Server to the internet

If you deliberately change the binding to `0.0.0.0` (or otherwise expose
port 1433 publicly), you take on:
- Continuous credential-stuffing / brute-force attempts against `sa`.
- A large historical record of SQL Server CVEs and exploitation attempts
  targeting internet-facing instances.
- Regulatory/compliance exposure if the instance holds any real data.

If you genuinely need remote access, prefer a VPN, SSH tunnel, or
Docker/host firewall rules scoped to specific trusted source IPs — never a
bare public bind for anything beyond a deliberately disposable, empty
instance.

## Risks of Docker group membership

As covered in
[02-docker-installation.md](02-docker-installation.md#security-implications-of-docker-group-membership),
membership in the `docker` group is equivalent to root on the host. Treat
it accordingly — don't add it to service accounts or users you don't
fully trust.

## Password complexity requirements

SQL Server enforces (and this project documents, in
[.env.example](../.env.example)) Windows-style password complexity: 8+
characters (16+ recommended), at least 3 of {uppercase, lowercase, digit,
symbol}, and not containing the word "password". `scripts/generate-env.sh`
performs a basic client-side check before writing `.env`, but the
authoritative check happens inside SQL Server at container startup.

## Developer Edition licensing limitations

`MSSQL_PID=Developer` is free to use but licensed by Microsoft **for
development and testing only** — not for production workloads or
production data. Review Microsoft's current SQL Server licensing terms
before using this deployment for anything beyond development/testing, and
switch to an appropriately licensed edition/PID if you move toward
production use.

## Importance of backups

The named volume protects data across container restarts, `stop`/`start`,
and image upgrades — but it does **not** protect against `docker compose
down -v`, accidental volume deletion, host disk failure, or any bug that
corrupts data in place. Regular backups to `backups/` (and ideally copied
off-host) are the only real protection against those scenarios. See
[05-backup-and-restore.md](05-backup-and-restore.md).

## Why the `sa` account should not be used by applications

`sa` is a fixed-name, maximally privileged account and therefore a
standing high-value target. For anything beyond initial setup and
administration:
1. Create a dedicated SQL login per application/service.
2. Grant only the permissions that login actually needs (least privilege)
   on the specific database(s) it uses.
3. Rotate application credentials independently of the `sa` password.
4. Keep `sa` itself reserved for administrative tasks, ideally used
   rarely and audited when it is.

## Summary checklist

- [ ] `.env` is not tracked by Git (`git status` should never show it).
- [ ] `.env` permissions are `600`.
- [ ] Port 1433 stays bound to `127.0.0.1` unless remote access is a
      deliberate, explicit requirement.
- [ ] `sa` password meets complexity requirements and is unique to this
      deployment.
- [ ] Regular backups exist and have been test-restored at least once.
- [ ] Application code uses dedicated least-privilege logins, not `sa`.
- [ ] This deployment is understood to be Developer Edition — development
      and testing only.
