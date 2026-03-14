#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run this script as root."
  exit 1
fi

read -rp "Enter your username: " username

if [[ -z "$username" ]]; then
  echo "Username must not be empty."
  exit 1
fi

if id "$username" >/dev/null 2>&1; then
  echo "User '$username' already exists."
  exit 1
fi

useradd -m -s /bin/bash "$username"
passwd "$username"

if ! getent group wheel >/dev/null; then
  groupadd wheel
fi
usermod -aG wheel "$username"

cat > /etc/sudoers.d/wheel <<'EOF'
%wheel ALL=(ALL:ALL) ALL
EOF
chmod 440 /etc/sudoers.d/wheel

install -d -m 700 -o "$username" -g "$username" "/home/$username/.ssh"

sudo -u "$username" ssh-keygen \
  -t ed25519 \
  -C "$username@$(hostname)" \
  -f "/home/$username/.ssh/id_ed25519"

sed -i "s/default=root/default=$username/" /etc/wsl.conf

cat > /home/$username/.bash_colors <<'EOF'
export BLACK='\033[1;30m'
export RED='\033[1;31m'
export GREEN='\033[1;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[1;34m'
export MAGENTA='\033[1;35m'
export CYAN='\033[1;36m'
export GRAY='\033[1;37m'
export DEFAULT='\033[0;39m'
export WHITE='\033[01;00m'
EOF

cat > /home/$username/.bashrc <<'EOF'
# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# don't put duplicate lines in the history. See bash(1) for more options
# ... or force ignoredups and ignorespace
HISTCONTROL=ignoredups:ignorespace

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# enable bash colors
if [ -f $HOME/.bash_colors ]; then
    . $HOME/.bash_colors
fi

# set promt and colors
if [ "$USER" == "root" ]; then
    ucolor="\[$RED\]"
else
    ucolor="\[$GREEN\]"
fi

checked=$(echo "\342\234\223")
ballot=$(echo "\342\234\227")

function __parse_git_branch() {
    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'
}

function __prompt_command() {
    local EXIT="$?"

    if test $EXIT -eq 0; then
        error="\[$WHITE\]$EXIT \[$GREEN\]$checked\[$WHITE\]] "
    else
        error="\[$WHITE\]$EXIT \[$RED\]$ballot\[$WHITE\]] "
    fi

    gitInfo=""
    branch=$(__parse_git_branch)
    if ! test -z "$branch"; then
        gitInfo="\[$MAGENTA\][$branch]"
    fi

    PS1="$error$ucolor\u@$ucolor\h\[$WHITE\]:\[$BLUE\]\w$gitInfo\[$BLUE\]\$ \[$WHITE\]"
    PS2="$error$ucolor# \[$WHITE\]:\[$WHITE\]\W\[$WHITE\]\$ "
}

export PROMPT_COMMAND=__prompt_command

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=always'
    alias fgrep='fgrep --color=always'
    alias egrep='egrep --color=always'
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
    . /etc/bash_completion
fi

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

export EDITOR='vim'
export SVN_EDITOR='vim'

export SUDO_ASKPASS=/usr/bin/ssh-askpass

export GALLIUM_DRIVER=d3d12
export LIBVA_DRIVER_NAME=d3d12

eval "$(/usr/bin/wsl2-ssh-agent)"

source /usr/share/fzf/key-bindings.bash
source /usr/share/fzf/completion.bash
EOF

echo "Setup complete. Please restart your WSL distribution to apply the changes."
echo
echo "To restart, type exit and run the following command in PowerShell:"
echo "wsl --terminate ${WSL_DISTRO_NAME}"