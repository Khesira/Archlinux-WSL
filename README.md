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

# Runtime Requirements

You need the following tools installed on Windows:

- **WSL**
- **PowerShell**

---

# Quick install

If you only want to install the prepared distribution without building it yourself, download the archlinux.wsl file from the latest release and execute it

After installation, WSL automatically launches the distribution and starts the OOBE setup.

---

# Using the Windows SSH Agent with `wsl2-ssh-agent`

The distribution includes **`wsl2-ssh-agent`**, which allows WSL to use the **Windows OpenSSH agent**.

This enables sharing SSH keys between Windows and WSL. The keys remain stored on the Windows side and are made available to WSL through the agent.

The feature is optional. If you want to use it, you need to configure the Windows OpenSSH components.

## 1. Install OpenSSH components

Install the OpenSSH components on Windows if they are not already present.

You can install them via **Windows Settings → Optional Features** or with PowerShell:

    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

This installs the Windows OpenSSH tools including `ssh-agent` and `ssh-add`.

## 2. Generate an SSH key

Create an SSH key on Windows:

    ssh-keygen -t ed25519

The key will be stored in:

    %USERPROFILE%\.ssh\

## 3. Enable the Windows SSH Agent service

Open **Services** and set the **OpenSSH Authentication Agent** to start automatically.

Alternatively configure it via PowerShell:

    Set-Service ssh-agent -StartupType Automatic
    Start-Service ssh-agent

## 4. Add your key to the agent

Add the key to the Windows SSH agent:

    ssh-add $env:USERPROFILE\.ssh\id_ed25519

Once the key is loaded, it will be available inside WSL through `wsl2-ssh-agent`.

You can verify this from WSL:

    ssh-add -l

If the agent is configured correctly, the loaded keys from Windows will appear in the list.

## Additional reference

For more details about managing SSH keys on Windows, see the Microsoft documentation:

https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement

---

# Build Requirements

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