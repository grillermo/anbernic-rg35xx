#!/bin/bash
# Build a customized stock-Anbernic (Ubuntu 22.04) image for the 248.3 GB test card.
# OS partitions move to the front (same partition numbers), Roms (p1) fills the rest.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get -qq install -y gdisk dosfstools e2fsprogs gnupg curl >/dev/null

SRC=/tmp/rg35-build/stock
KEYS=/tmp/rg35-build/keys
OUT=/tmp/rg35-build/out
CARD_BYTES=248302796800
IMG=/work/stock.img
USERNAME=${RG_USER:-grillermo}  # override: RG_USER=<name>
HOST=rg35xx
M=$((1024*1024))
mkdir -p /work "$OUT"

# --- layout (MiB): name, start-on-new-card, size, offset-in-os-parts.bin
#      p2 boot-resource, p3 env, p4 boot, p5 rootfs, p6 appfs, p7 UDISK, p1 Roms
P2=36; P3=68; P4=84; P5=148; P6=7316; P7=11412; P1=12710
rm -f "$IMG"; truncate -s $CARD_BYTES "$IMG"
dd if=$SRC/head-36M.bin of="$IMG" bs=1M count=36 conv=notrunc status=none
cp_part() { dd if=$SRC/os-parts.bin of="$IMG" bs=1M skip="$1" seek="$2" count="$3" conv=notrunc status=none; }
cp_part 0     $P2 32
cp_part 32    $P3 16
cp_part 48    $P4 64
cp_part 112   $P5 7168
cp_part 7280  $P6 4096
cp_part 11376 $P7 1298

S=2048  # sectors per MiB
sgdisk --zap-all "$IMG" >/dev/null 2>&1 || true
sgdisk -o "$IMG" >/dev/null
sgdisk -S 8 "$IMG"
sgdisk -n 1:$((P1*S)):0                      -t 1:0700 -c 1:Roms \
       -n 2:$((P2*S)):$(((P2+32)*S-1))       -t 2:0700 -c 2:boot-resource \
       -n 3:$((P3*S)):$(((P3+16)*S-1))       -t 3:0700 -c 3:env \
       -n 4:$((P4*S)):$(((P4+64)*S-1))       -t 4:0700 -c 4:boot \
       -n 5:$((P5*S)):$(((P5+7168)*S-1))     -t 5:0700 -c 5:rootfs \
       -n 6:$((P6*S)):$(((P6+4096)*S-1))     -t 6:0700 -c 6:appfs \
       -n 7:$((P7*S)):$(((P7+1298)*S-1))     -t 7:0700 -c 7:UDISK \
       "$IMG" >/dev/null
# The 8-entry GPT ends at LBA 3; re-copy 8 KiB..36 MiB (boot0 + boot_package) untouched.
dd if=$SRC/head-36M.bin of="$IMG" bs=8192 skip=1 seek=1 count=$((36*128-1)) conv=notrunc status=none
sgdisk -v "$IMG" | tail -2; sgdisk -p "$IMG" | tail -8
python3 -c "import struct; h=open(\"$IMG\",\"rb\").read(1024)[512:]; print(\"GPT entries_lba\",struct.unpack(\"<Q\",h[72:80])[0],\"n,size\",struct.unpack(\"<II\",h[80:88]))"
cmp <(dd if="$IMG" bs=8192 skip=1 count=4607 status=none) <(dd if=$SRC/head-36M.bin bs=8192 skip=1 count=4607 status=none) && echo "boot0+boot_package intact"

LOOP=$(losetup -fP --show "$IMG")
trap 'umount -R /mnt/rgs 2>/dev/null || true; losetup -d $LOOP 2>/dev/null || true' EXIT
mkfs.vfat -F 32 -n ROMS ${LOOP}p1 >/dev/null
e2fsck -fy ${LOOP}p5 >/dev/null || [ $? -le 1 ]
e2fsck -fy ${LOOP}p6 >/dev/null || [ $? -le 1 ]
e2fsck -fy ${LOOP}p7 >/dev/null || [ $? -le 1 ]

R=/mnt/rgs; mkdir -p $R; mount ${LOOP}p5 $R
for d in dev dev/pts proc sys; do mount --bind /$d $R/$d; done
cp -a $R/etc/resolv.conf $R/etc/resolv.conf.rgbak 2>/dev/null || true
rm -f $R/etc/resolv.conf; cp -L /etc/resolv.conf $R/etc/resolv.conf
printf '#!/bin/sh\nexit 101\n' > $R/usr/sbin/policy-rc.d; chmod +x $R/usr/sbin/policy-rc.d

install -d -m 0755 $R/etc/apt/keyrings
curl -fsSL https://downloads.claude.ai/keys/claude-code.asc -o $R/etc/apt/keyrings/claude-code.asc
gpg --show-keys --with-colons $R/etc/apt/keyrings/claude-code.asc | grep -q '^fpr:::::::::31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE:'
echo "deb [signed-by=/etc/apt/keyrings/claude-code.asc] https://downloads.claude.ai/claude-code/apt/stable stable main" > $R/etc/apt/sources.list.d/claude-code.list
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg -o $R/usr/share/keyrings/tailscale-archive-keyring.gpg
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list -o $R/etc/apt/sources.list.d/tailscale.list
cat "$KEYS"/*.pub > $R/tmp/authorized_keys

echo "--- apt sources:"; grep -hvE '^#|^$' $R/etc/apt/sources.list $R/etc/apt/sources.list.d/*.list

chroot $R /bin/bash -euo pipefail <<EOF
export DEBIAN_FRONTEND=noninteractive LC_ALL=C
grep -q universe /etc/apt/sources.list || sed -i -E 's/^(deb .* jammy[a-z-]* main.*)$/\1 universe/' /etc/apt/sources.list
apt-get -qq update
apt-get install -y -qq --no-install-recommends sudo ca-certificates curl gnupg git tmux mosh zsh htop vim ripgrep \
  less avahi-daemon libnss-mdns rsync jq bash-completion locales >/dev/null
apt-get install -y -qq claude-code tailscale >/dev/null
apt-get clean

echo $HOST > /etc/hostname
sed -i 's/ANBERNIC/$HOST/g' /etc/hosts; grep -q $HOST /etc/hosts || echo "127.0.1.1 $HOST" >> /etc/hosts
systemctl enable avahi-daemon tailscaled >/dev/null 2>&1

id $USERNAME >/dev/null 2>&1 || useradd -m -s /bin/zsh $USERNAME
for g in sudo netdev audio video input plugdev; do getent group \$g >/dev/null && usermod -aG \$g $USERNAME; done
echo '$USERNAME ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$USERNAME; chmod 440 /etc/sudoers.d/$USERNAME
install -d -m 700 -o $USERNAME -g $USERNAME /home/$USERNAME/.ssh
install -m 600 -o $USERNAME -g $USERNAME /tmp/authorized_keys /home/$USERNAME/.ssh/authorized_keys; rm /tmp/authorized_keys
cat > /home/$USERNAME/.zshrc <<'ZRC'
HISTFILE=~/.zsh_history; HISTSIZE=10000; SAVEHIST=10000
setopt share_history inc_append_history
autoload -Uz compinit && compinit
PROMPT='%F{green}%n@%m%f:%F{blue}%~%f %# '
export PATH="\$HOME/.local/bin:\$PATH"
ZRC
chown $USERNAME:$USERNAME /home/$USERNAME/.zshrc

cat > /etc/ssh/sshd_config.d/10-rg35xx.conf <<'SSHD'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
SSHD
EOF

rm -f $R/usr/sbin/policy-rc.d $R/etc/resolv.conf
[ -e $R/etc/resolv.conf.rgbak ] || [ -L $R/etc/resolv.conf.rgbak ] && mv $R/etc/resolv.conf.rgbak $R/etc/resolv.conf
echo "--- verify"
chroot $R claude --version; chroot $R tailscale version | head -1; chroot $R id $USERNAME
cat $R/etc/hostname; wc -l < $R/home/$USERNAME/.ssh/authorized_keys; ls -la $R/etc/resolv.conf; df -h $R | tail -1
for d in sys proc dev/pts dev; do umount $R/$d; done; umount $R
e2fsck -fn ${LOOP}p5 | tail -1
losetup -d $LOOP; trap - EXIT

# --- export: front part (everything up to Roms + its FAT metadata) and the backup GPT at the card end
dd if="$IMG" of=$OUT/front.img bs=1M count=$((P1+128)) status=none
dd if="$IMG" of=$OUT/tail-gpt.bin bs=512 skip=$((CARD_BYTES/512-34)) count=34 status=none
ls -l $OUT; sha256sum $OUT/*
