# Building the working SD card image

How the server card was made, to redo or change it. Everything runs on a Mac (Apple
Silicon) plus the Lima VM. `$RG35` is the build folder (mine is on an external drive; you need
~60 GB free):

```bash
export RG35="$HOME/rg35"   # or wherever you keep it
```

The numbers below (offsets, sizes) are **from my cards** — a 255.9 GB stock card and a 248.3 GB
target card — so treat them as a worked example and read your own.

```
$RG35/
├── build/                    # mounted in the VM at /tmp/rg35-build
│   ├── stock/head-36M.bin    # healthy card bytes 0–36 MiB (GPT + boot0 + U-Boot)
│   ├── stock/os-parts.bin    # healthy card's 6 OS partitions, 12674 MiB, contiguous
│   ├── out/front2.img        # final image: first 164 MiB (GPT, bootloader, Roms FAT)
│   ├── out/os2.img           # final image: OS partitions + backup GPT (written at 224125 MiB)
│   ├── keys/*.pub            # SSH public keys baked into the image
│   └── healthy-head.bin      # first 4 MiB of the healthy card (DRAM params, GPT)
├── scripts/                  # same as ./scripts here
├── tools/sunxi-fel
└── lima-home/rg35/           # the VM (LIMA_HOME=.../lima-home)
```

## 1. Copy the stock OS off the healthy card (read-only)

The "healthy" card is the stock card your device shipped with. Find it by size with
`diskutil list` (mine is 255.9 GB), and read its partition table (read-only):

```bash
sudo gpt -r show /dev/diskN
```

The six OS partitions (boot-resource … UDISK) sit contiguously at the end. On my card they start
at 231341 MiB and span 12674 MiB; replace `skip` and `count` with yours:

```bash
sudo dd if=/dev/rdiskN of=stock/head-36M.bin bs=1m count=36
sudo dd if=/dev/rdiskN of=stock/os-parts.bin bs=1m skip=231341 count=12674 status=progress
```

My stock offsets (MiB): Roms 36–231335, boot-resource 231341, env 231373, boot 231389,
rootfs 231453, appfs 238621, UDISK 242717–244015. The scripts assume the same partition **sizes**
(32, 16, 64, 7168, 4096, 1298 MiB); if your stock image differs, adjust `cp_part` in
`build-stock.sh` and the `12674` in `assemble2.sh`.

## 2. Customize (scripts/build-stock.sh, in the VM as root)

Builds `/work/stock.img`: copies the partitions in, `e2fsck` (the stock partitions need journal
recovery), mounts rootfs (p5), bind-mounts `/dev /proc /sys`, swaps in a working `resolv.conf`,
blocks service starts with `policy-rc.d`, then in a chroot:

- adds Anthropic's apt repo (verifies key fingerprint
  `31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE`) and Tailscale's jammy repo
- `apt-get install` shell tools, avahi, `claude-code`, `tailscale` (no full-upgrade)
- hostname `rg35xx`, user `$RG_USER` (default `grillermo`), sudoers, authorized_keys, `.zshrc`, sshd drop-in

Its own GPT step is the one that **didn't boot** — use step 3's layout instead.

## 3. Lay out for the target card (scripts/relayout.py + scripts/assemble2.sh)

`relayout.py <stock-head> <card-sectors> <primary.bin> <backup.bin>` clones the stock GPT for a
different card size: Roms shrinks, p2–p7 shift so UDISK keeps the same gap to the end, and the
header, CRCs and protective MBR are rewritten. `assemble2.sh` builds `/work/stock2.img` from the
stock head + new GPT + the customized partitions, formats Roms FAT32, verifies boot0/U-Boot and
partitions byte-for-byte, and exports `front2.img` and `os2.img`.

Both scripts take the target card's size in bytes as `CARD_BYTES` (from `diskutil info`). Put
your SSH public keys in `build/keys/*.pub` and choose a username, then in the VM, as root:

```bash
cd /tmp/rg35-build/scripts   # or wherever you copied ./scripts
RG_USER=yourname CARD_BYTES=248302796800 ./build-stock.sh
CARD_BYTES=248302796800 ./assemble2.sh   # prints P2NEW_MIB
```

For my 248.3 GB card (484966400 sectors): shift 7216 MiB, p2 at 224125 MiB.

## 4. Write the card (run it yourself; guarded by size)

Set the three values first: the disk number from `diskutil list` **right now**, the card size in
bytes, and `P2NEW_MIB` from `assemble2.sh`. The command refuses to write unless the size matches.

```bash
DISK=disk8 BYTES=248302796800 P2=224125
[ "$(diskutil info /dev/$DISK | grep -o "$BYTES Bytes")" = "$BYTES Bytes" ] && diskutil unmountDisk /dev/$DISK && sudo dd if=front2.img of=/dev/r$DISK bs=1m && sudo dd if=os2.img of=/dev/r$DISK bs=1m seek=$P2 status=progress && sync && diskutil eject /dev/$DISK
```

## 5. After first boot (done live over SSH, not in the image yet)

- `systemd-timesyncd` on, timezone America/Mexico_City
- `/etc/update-motd.d/60-free-space`

Fold these into `build-stock.sh` before rebuilding.

## Other scripts kept for reference

- `scripts/customize.sh` — the Debian 13 port customization (that image doesn't boot here)
- `scripts/build-uboot.sh` — upstream TF-A + U-Boot with stock DRAM TPRs (also doesn't boot here)
