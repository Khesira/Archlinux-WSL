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

# Runtime Requirements

You need the following tools installed on Windows:

- **WSL**
- **PowerShell**

---

# Quick install

If you only want to install the prepared distribution without building it yourself, download the archlinux.wsl file  
from the latest release and execute it or run the following command:

```powershell
wsl --install --from-file dist\archlinux.wsl
```

After installation, WSL automatically launches the distribution and starts the OOBE setup.

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

OOBE Script:

```
/usr/lib/wsl/oobe.sh
```

Responsibilities:

- Ask for the user locale
- Create sudo access and the first user
- Set the user as default user in ```/etc/wsl.conf```
- Create an SSH key
- Write a basic .bashrc file
- Ask to download optional dotfiles

The script is executed **only once**.

After this process completes, the configuration:

```
defaultUid=1000
```

instructs WSL to automatically start the user created during OOBE and the distribution behaves like a normal Linux system.

---

# Optional dotfiles

During OOBE runs you will be asked to download additional extended configuration.  
Proceeding with yes will download the following files:

## vimrc

It just contains some basic vim settings. Kindly feel free to adjust it to your needs or delete it if you prefer to have the default settings or you are not using vim at all.

## bash_aliases

Since aliases are a very individual thing, the purpose of this file is not to provide you with a best practice bash_aliases file.

It contains a small set of aliases which you might or might not like. In any case, kindly feel free to change and/or extend it to your own likes.

## local_bashrc

This file is sourced by the bashrc which has been written during OOBE.  
In its current state it contains a custom prompt showing additional information:

- Return code of the last command
- Who you are and where
- The active Python venv (only visible if one is active)
- The current working directory
- The active git branch in case you are within a git repository

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

# Build the distribution

Run the PowerShell build script:

```powershell
.\build.ps1
```

If an existing distribution with the same name exists, the script will ask whether it should be removed.

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

# Docker build

The distribution filesystem is defined in the `Dockerfile`.

Example responsibilities:

- install base packages
- configure locales
- copy OOBE script
- configure WSL integration

The Docker image itself is **not used as a runtime container** — it only serves as a build environment for the root filesystem.

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