# 02 - Docker Installation (Ubuntu 24.04 "noble")

**These commands are for you to run manually in your own terminal.**
Nothing in this repository executes them automatically, and they require
`sudo`, which this project's tooling will never invoke on your behalf.

This procedure installs Docker Engine and the Docker Compose plugin from
Docker's **official Ubuntu apt repository** — not the outdated `docker.io`
package shipped in Ubuntu's default repositories.

Skip this entire page if `docker --version` and `docker compose version`
already succeed on your machine.

## 1. Remove conflicting packages

Older Docker-related packages can conflict with the official Docker Engine
packages.

```bash
for pkg in docker.io docker-doc docker-compose docker-compose-v2 \
           podman-docker containerd runc; do
  sudo apt-get remove -y "$pkg"
done
```

It is normal for some of these to report "not installed" — that is not an
error.

## 2. Install required packages

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
```

## 3. Add Docker's official GPG signing key

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

## 4. Add the Docker apt repository for Ubuntu Noble

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu noble stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```

## 5. Install Docker Engine

```bash
sudo apt-get install -y \
  docker-ce docker-ce-cli containerd.io
```

## 6. Install the Docker Compose plugin

The Compose plugin is normally installed alongside Docker Engine via the
`docker-compose-plugin` package (bundled by `docker-ce` on recent releases,
but install it explicitly to be certain):

```bash
sudo apt-get install -y docker-compose-plugin
```

## 7. Verify the installation

```bash
docker --version
docker compose version
sudo systemctl enable --now docker
sudo systemctl status docker --no-pager
```

You should see Docker's version string, Compose's version string (as a
plugin, invoked as `docker compose`, not `docker-compose`), and an
`active (running)` service status.

## 8. (Optional) Add your user to the `docker` group

By default, only `root` and members of the `docker` group can talk to the
Docker daemon. Without this step you would need `sudo` before every
`docker` command.

```bash
sudo usermod -aG docker "$USER"
```

### Security implications of `docker group` membership

Membership in the `docker` group is **effectively equivalent to passwordless
root** on the host. A user in this group can mount the host's root
filesystem into a container and read/write anything as root, bypass most
access controls, and access other containers' data. Only add trusted local
users to this group, and treat it with the same caution as `sudo` access.

### Logout / login requirement

Group membership changes do not apply to already-running shells or
sessions. After running `usermod -aG docker "$USER"`, you must do one of:

```bash
newgrp docker      # applies the new group to the CURRENT shell only
```

or fully log out and log back in (recommended for GUI sessions, SSH
sessions, and anything other than a quick one-off terminal check). Do not
assume the group change is active until you have verified it:

```bash
groups
docker info >/dev/null 2>&1 && echo OK || echo "still needs sudo or new session"
```

## Next step

Continue to [03-sql-server-deployment.md](03-sql-server-deployment.md).
