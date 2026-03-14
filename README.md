# Archlinux WSL Distribution Builder

This project builds a custom **Arch Linux distribution for WSL** using Docker and packages it as a `.wsl` file that can be installed directly via `wsl.exe`.

The resulting distribution includes:

- A minimal Arch Linux base system
- Preinstalled packages useful for development
- Proper locale configuration
- A **WSL OOBE (Out-Of-Box Experience)** script to create the initial user
- Optional integration features like `wsl2-ssh-agent`

The distribution is built reproducibly using Docker.

---

# How it works

The build pipeline looks like this:

Dockerfile
->
Docker image
->
docker export
->
rootfs.tar
->
archlinux.wsl
->
wsl --install --from-file

The `.wsl` file is simply a **tar archive containing the Linux root filesystem**.  
WSL can install such archives directly.

---

# Requirements

You need the following tools installed on Windows:

- **Docker**
- **WSL**
- **PowerShell**

WSL does **not** need to be fully configured beforehand, since the build process runs entirely through Docker.

---

# Build the distribution

Run the PowerShell build script:

```powershell
.\build.ps1
```

The script will:

1. Build the Docker image
2. Create a container from the image
3. Export the container filesystem
4. Package it as `dist/archlinux.wsl`
5. Install the distribution via `wsl.exe`

---

# Output

Build artifacts are written to:

```
dist/
  archlinux.wsl
```

This file can be distributed and installed on other machines.

---

# Installing the distribution manually

If you already have the `.wsl` file, install it with:

```powershell
wsl --install --from-file dist\archlinux.wsl --name Archlinux
```

After installation, WSL automatically launches the distribution.

---

# First Boot (OOBE)

The distribution uses the WSL **Out-Of-Box Experience (OOBE)** mechanism.

Configuration file:

```
/etc/wsl-distribution.conf
```

Example:

```ini
[oobe]
command=/usr/lib/wsl/oobe.sh
defaultUid=1000
```

During the first startup:

1. `oobe.sh` is executed
2. The script prompts for a username
3. The user account is created
4. WSL sets the default user

After this process completes, the distribution behaves like a normal Linux system.

---

# OOBE script

Location:

```
/usr/lib/wsl/oobe.sh
```

Typical responsibilities:

- create the first user
- configure sudo access
- configure shell environment
- optional setup tasks

Example logic:

```
prompt for username
create user
set password
configure environment
exit
```

The script is executed **only once**.

---

# Restart behavior

The OOBE script should **not attempt to restart WSL itself**.

Instead, the configuration uses:

```
defaultUid=1000
```

which instructs WSL to automatically start the user created during OOBE.

---

# Docker build

The distribution filesystem is defined in the `Dockerfile`.

Example responsibilities:

- install base packages
- configure locales
- copy OOBE script
- configure WSL integration

The Docker image itself is **not used as a runtime container** — it only serves as a build environment for the root filesystem.

---

# Project structure

```
.
├── Dockerfile
├── build.ps1
├── README.md
├── bin/
│   └── oobe.sh
├── icon/
│   └── archlinux.png
└── dist/
    └── archlinux.wsl
```

---

# Key design decisions

## Docker for reproducible builds

Using Docker ensures:

- deterministic builds
- isolated package installation
- reproducible root filesystem

---

## `.wsl` instead of `.tar`

WSL can install distributions directly from `.wsl` packages.

Internally they are simply tar archives containing the root filesystem.

---

## OOBE instead of manual setup

Using `wsl-distribution.conf` allows a clean first-run setup without requiring the user to manually execute initialization scripts.

---

# Development

Rebuild the distribution with:

```powershell
.\build.ps1
```

If an existing distribution with the same name exists, the script will ask whether it should be removed.

---

# Cleaning old builds

To force a fresh Docker build:

```powershell
docker build --no-cache
```

To remove build caches:

```powershell
docker builder prune
```

---

# License

This project follows the licenses of the included software, primarily the Arch Linux packages.