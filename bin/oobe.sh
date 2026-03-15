#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run this script as root."
  exit 1
fi

prompt_locale() {
    local prompt="$1"
    local default_locale="$2"
    local user_locale

    while true; do
        read -rp "$prompt [default: $default_locale]: " user_locale
        user_locale="${user_locale:-$default_locale}"

        if [[ ! "$user_locale" =~ ^[a-z]{2}_[A-Z]{2}$ ]]; then
            echo "Invalid locale format. Expected format like de_DE or fr_FR." >&2
            continue
        fi

        if ! command grep -Eq "^[[:space:]]*#?[[:space:]]*${user_locale}\.UTF-8[[:space:]]+UTF-8[[:space:]]*$" /etc/locale.gen; then
            echo "Locale ${user_locale}.UTF-8 is not available in /etc/locale.gen." >&2
            continue
        fi

        printf '%s\n' "$user_locale"
        return 0
    done
}

enable_locale() {
    local locale_name="$1"
    sed -i -E "s|^[[:space:]]*#?[[:space:]]*(${locale_name}\.UTF-8[[:space:]]+UTF-8)[[:space:]]*$|\1|" /etc/locale.gen
}

language_locale="$(prompt_locale 'Enter UI language locale (e.g. en_US, de_DE)' 'en_US')"

read -rp "Use a separate locale for date, numbers and currency? [y/N]: " use_regional_locale

regional_locale=""
if [[ "$use_regional_locale" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    regional_locale="$(prompt_locale 'Enter regional locale (e.g. de_DE, fr_FR)' "$language_locale")"
fi

enable_locale "$language_locale"
if [[ -n "$regional_locale" && "$regional_locale" != "$language_locale" ]]; then
    enable_locale "$regional_locale"
fi

locale-gen

{
    echo "LANG=${language_locale}.UTF-8"
    if [[ -n "$regional_locale" ]]; then
        echo "LC_TIME=${regional_locale}.UTF-8"
        echo "LC_NUMERIC=${regional_locale}.UTF-8"
        echo "LC_MONETARY=${regional_locale}.UTF-8"
    fi
} > /etc/locale.conf

if ! getent group wheel >/dev/null; then
  groupadd wheel
fi

while true; do
    read -rp "Enter your username: " username

    if [[ -z "$username" ]]; then
        echo "Username must not be empty."
        continue
    fi

    if id "$username" >/dev/null 2>&1; then
        echo "User '$username' already exists."
        continue
    fi

    break
done

useradd -m -s /bin/bash -G wheel "$username"
passwd "$username"

printf '\n[user]\ndefault=%s\n' "$username" >> /etc/wsl.conf

cat > /etc/sudoers.d/wheel <<'EOF'
%wheel ALL=(ALL:ALL) ALL
EOF
chmod 440 /etc/sudoers.d/wheel

install -d -m 700 -o "$username" -g "$username" "/home/$username/.ssh"

sudo -u "$username" ssh-keygen \
  -t ed25519 \
  -C "$username@$(hostname)" \
  -f "/home/$username/.ssh/id_ed25519"

cat > "/home/$username/.bashrc" <<'EOF'
# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# History
HISTCONTROL=ignoredups:ignorespace
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s histappend
shopt -s checkwinsize

# lesspipe
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# SSH askpass
export SUDO_ASKPASS=/usr/lib/ssh/ssh-askpass

# Editor
export EDITOR='vim'
export SVN_EDITOR='vim'

# WSL graphics
export GALLIUM_DRIVER=d3d12
export LIBVA_DRIVER_NAME=d3d12

# FZF configuration
export FZF_CTRL_R_OPTS="--sort --exact"

if [ -f /usr/share/fzf/key-bindings.bash ]; then
    . /usr/share/fzf/key-bindings.bash
fi

if [ -f /usr/share/fzf/completion.bash ]; then
    . /usr/share/fzf/completion.bash
fi

# WSL2 SSH Agent
if [ -x /usr/bin/wsl2-ssh-agent ]; then
    eval "$(/usr/bin/wsl2-ssh-agent)"
fi

# Bash completion
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
    . /etc/bash_completion
fi

# User aliases
if [ -f "$HOME/.bash_aliases" ]; then
    . "$HOME/.bash_aliases"
fi

# Custom Bash Config
if [ -f "$HOME/.local.bashrc" ]; then
    . "$HOME/.local.bashrc"
fi
EOF

chown "$username:$username" "/home/$username/.bashrc"

read -rp "Download extended bash configs from https://github.com/BluntlyCat/dotfiles? [y/N]: " enable_custom

download_dotfile() {
    local base_url="$1"
    local file="$2"
    local target="/home/$username/.${file}"

    local url="${base_url}/${file}"

    if curl -fsSL "$url" -o "$target"; then
        chown "$username:$username" "$target"
        chmod 644 "$target"
        echo "Installed .$file"
    else
        echo "Warning: Failed to download $file from GitHub."
    fi
}

if [[ "$enable_custom" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    dotfile_url="https://raw.githubusercontent.com/BluntlyCat/dotfiles/main"

    download_dotfile "$dotfile_url" "bash_aliases"
    download_dotfile "$dotfile_url" "local.bashrc"
    download_dotfile "$dotfile_url" "vimrc"
fi

echo "Setup complete. Please restart your WSL distribution to apply the changes."
echo
echo "To restart, type exit and run the following command in PowerShell:"
echo "wsl --terminate ${WSL_DISTRO_NAME}"