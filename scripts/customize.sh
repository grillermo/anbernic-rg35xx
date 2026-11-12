#!/bin/bash
# Customize the mounted RG35XX Debian rootfs at /mnt/rg (run as root inside the Lima VM).
set -euo pipefail
R=/mnt/rg
KEYS=/tmp/rg35-build/keys
USERNAME=${RG_USER:-grillermo}  # override: RG_USER=<name>
HOST=rg35xx

# --- Device tree: the Plus has no analog sticks; disable the H's adc-joystick node
for dtb in "$R"/boot/sun50i-h700-anbernic-rg35xx-h*.dtb; do
  fdtput -t s "$dtb" /adc-joystick status disabled
  echo "$(basename "$dtb"): adc-joystick -> $(fdtget "$dtb" /adc-joystick status)"
done

# --- Wi-Fi regulatory country
sed -i 's/country=RU/country=MX/' "$R/usr/local/sbin/rg35xxh-wifi-import"

# --- chroot plumbing
for d in dev dev/pts proc sys; do mount --bind "/$d" "$R/$d"; done
cleanup() {
  rm -f "$R/usr/sbin/policy-rc.d"
  if [ -e "$R/etc/resolv.conf.rgbak" ] || [ -L "$R/etc/resolv.conf.rgbak" ]; then
    rm -f "$R/etc/resolv.conf"; mv "$R/etc/resolv.conf.rgbak" "$R/etc/resolv.conf"
  fi
  for d in sys proc dev/pts dev; do umount "$R/$d" || true; done
}
trap cleanup EXIT
mv "$R/etc/resolv.conf" "$R/etc/resolv.conf.rgbak"
cp -L /etc/resolv.conf "$R/etc/resolv.conf"
printf '#!/bin/sh\nexit 101\n' > "$R/usr/sbin/policy-rc.d"; chmod +x "$R/usr/sbin/policy-rc.d"

install -d -m 0755 "$R/etc/apt/keyrings"
curl -fsSL https://downloads.claude.ai/keys/claude-code.asc -o "$R/etc/apt/keyrings/claude-code.asc"
gpg --show-keys --with-colons "$R/etc/apt/keyrings/claude-code.asc" | grep -q '^fpr:::::::::31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE:' \
  || { echo "Claude Code key fingerprint mismatch" >&2; exit 1; }
echo "deb [signed-by=/etc/apt/keyrings/claude-code.asc] https://downloads.claude.ai/claude-code/apt/stable stable main" \
  > "$R/etc/apt/sources.list.d/claude-code.list"
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg -o "$R/usr/share/keyrings/tailscale-archive-keyring.gpg"
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list -o "$R/etc/apt/sources.list.d/tailscale.list"

install -d -m 0700 "$R/root/.ssh-setup"
cat "$KEYS"/*.pub > "$R/root/.ssh-setup/authorized_keys"

chroot "$R" /bin/bash -euxo pipefail <<EOF
export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8
apt-get update
apt-get -y full-upgrade
apt-get install -y --no-install-recommends \
  sudo ca-certificates curl gnupg git tmux mosh zsh htop vim-nox ripgrep less man-db \
  avahi-daemon libnss-mdns locales tzdata bash-completion rsync jq
apt-get install -y claude-code tailscale
apt-get clean

# hostname + mDNS
echo $HOST > /etc/hostname
sed -i 's/rg35xxh/$HOST/g' /etc/hosts
grep -q "$HOST" /etc/hosts || echo "127.0.1.1 $HOST" >> /etc/hosts
systemctl enable avahi-daemon tailscaled

# timezone + locale
ln -sf /usr/share/zoneinfo/America/Mexico_City /etc/localtime
echo America/Mexico_City > /etc/timezone
sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen
echo 'LANG=en_US.UTF-8' > /etc/default/locale

# user
id $USERNAME >/dev/null 2>&1 || useradd -m -s /bin/zsh -G sudo,netdev,audio,video,input $USERNAME
echo '$USERNAME ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$USERNAME && chmod 440 /etc/sudoers.d/$USERNAME
install -d -m 700 -o $USERNAME -g $USERNAME /home/$USERNAME/.ssh
install -m 600 -o $USERNAME -g $USERNAME /root/.ssh-setup/authorized_keys /home/$USERNAME/.ssh/authorized_keys
rm -rf /root/.ssh-setup
cat > /home/$USERNAME/.zshrc <<'ZRC'
HISTFILE=~/.zsh_history; HISTSIZE=10000; SAVEHIST=10000
setopt share_history inc_append_history
autoload -Uz compinit && compinit
PROMPT='%F{green}%n@%m%f:%F{blue}%~%f %# '
export PATH="\$HOME/.local/bin:\$PATH"
ZRC
chown $USERNAME:$USERNAME /home/$USERNAME/.zshrc

# root: lock password, empty keys; SSH key-only, no root
passwd -l root
: > /root/.ssh/authorized_keys
cat > /etc/ssh/sshd_config.d/rg35xxh.conf <<'SSHD'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
SSHD

# LCD console: autologin the user on tty1 (no password exists to type)
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<'GETTY'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USERNAME --noclear %I \$TERM
GETTY
EOF

echo "--- verify"
chroot "$R" claude --version || true
chroot "$R" tailscale version | head -1
chroot "$R" id "$USERNAME"
cat "$R/etc/systemd/system/getty@tty1.service.d/autologin.conf"
wc -l "$R/home/$USERNAME/.ssh/authorized_keys"
df -h "$R"
