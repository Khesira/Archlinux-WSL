FROM archlinux:latest

COPY --chmod=755 bin/oobe.sh /usr/lib/wsl/oobe.sh
COPY --chmod=555 etc/wsl-distribution.conf /etc/wsl-distribution.conf
COPY --chmod=555 icon/archlinux.png /usr/share/icons/default/archlinux.png

RUN pacman -Syu --noconfirm && \
  pacman -S --noconfirm \
    base \
    base-devel \
    dbus \
    dbus-broker-units \
    sudo \
    ca-certificates \
    openssh \
    vim \
    iproute2 \
    procps-ng \
    less \
    which \
    inetutils \
    git \
    curl \
    tmux \
    wget \
    xdg-utils \
    mesa \
    vulkan-dzn \
    vulkan-icd-loader \
    python \
    go \
    fzf \
    x11-ssh-askpass \
    bash \
    bash-completion && \
  pacman -Scc --noconfirm && \
  useradd -m -s /bin/bash builduser && \
  printf 'builduser ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/builduser && \
  chmod 440 /etc/sudoers.d/builduser && \
  mkdir -p /tmp/build && \
  chown -R builduser:builduser /tmp/build && \
  sudo -u builduser bash -lc '\
    cd /tmp/build && \
    git clone https://aur.archlinux.org/wsl2-ssh-agent.git && \
    cd wsl2-ssh-agent && \
    makepkg -fsri --noconfirm' && \
  rm -rf /tmp/build && \
  userdel -r builduser && \
  rm -f /etc/sudoers.d/builduser && \
  rm -rf /var/cache/pacman/pkg/* && \
  sed -i -E 's/^#(en_US\.UTF-8 UTF-8)/\1/' /etc/locale.gen && \
  locale-gen && \
  printf '%s\n' \
    'LANG=en_US.UTF-8' \
    'LC_TIME=en_US.UTF-8' \
    'LC_NUMERIC=en_US.UTF-8' \
    'LC_MONETARY=en_US.UTF-8' \
    > /etc/locale.conf && \
  printf '%s\n' \
    '[boot]' \
    'systemd=true' \
    > /etc/wsl.conf && \
  sed -i '/^[[:space:]]*NoExtract[[:space:]]*=/d' /etc/pacman.conf && \
  systemctl mask systemd-firstboot.service && \
  systemctl mask systemd-resolved.service && \
  systemctl mask systemd-networkd.service && \
  systemctl mask systemd-tmpfiles-setup.service && \
  systemctl mask systemd-tmpfiles-clean.service && \
  systemctl mask systemd-tmpfiles-clean.timer && \
  systemctl mask systemd-tmpfiles-setup-dev-early.service && \
  systemctl mask systemd-tmpfiles-setup-dev.service && \
  systemctl mask tmp.mount

CMD ["/bin/bash"]
