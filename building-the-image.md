# Building the working SD card image

How the server card was made, to redo or change it. Everything runs on this Mac (Apple
Silicon) plus the Lima VM; paths are on the external drive:

```
/Volumes/externo 128GB/rg35/
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

Find the healthy card by size (255.9 GB) with `diskutil list`, then:

```bash
sudo dd if=/dev/rdiskN of=stock/head-36M.bin bs=1m count=36
sudo dd if=/dev/rdiskN of=stock/os-parts.bin bs=1m skip=231341 count=12674 status=progress
```

Stock offsets (MiB): Roms 36–231335, boot-resource 231341, env 231373, boot 231389,
rootfs 231453, appfs 238621, UDISK 242717–244015.

## 2. Customize (scripts/build-stock.sh, in the VM as root)

Builds `/work/stock.img`: copies the partitions in, `e2fsck` (the stock partitions need journal
recovery), mounts rootfs (p5), bind-mounts `/dev /proc /sys`, swaps in a working `resolv.conf`,
blocks service starts with `policy-rc.d`, then in a chroot:

- adds Anthropic's apt repo (verifies key fingerprint
  `31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE`) and Tailscale's jammy repo
- `apt-get install` shell tools, avahi, `claude-code`, `tailscale` (no full-upgrade)
- hostname `rg35xx`, user `grillermo`, sudoers, authorized_keys, `.zshrc`, sshd drop-in

Its own GPT step is the one that **didn't boot** — use step 3's layout instead.

## 3. Lay out for the target card (scripts/relayout.py + scripts/assemble2.sh)

`relayout.py <stock-head> <card-sectors> <primary.bin> <backup.bin>` clones the stock GPT for a
different card size: Roms shrinks, p2–p7 shift so UDISK keeps the same gap to the end, and the
header, CRCs and protective MBR are rewritten. `assemble2.sh` builds `/work/stock2.img` from the
stock head + new GPT + the customized partitions, formats Roms FAT32, verifies boot0/U-Boot and
partitions byte-for-byte, and exports `front2.img` and `os2.img`.

For the 248.3 GB card (484966400 sectors): shift 7216 MiB, p2 at 224125 MiB.

## 4. Write the card (user runs it; guarded by size)

```bash
[ "$(diskutil info /dev/disk8 | grep -o '248302796800 Bytes')" = "248302796800 Bytes" ] && diskutil unmountDisk /dev/disk8 && sudo dd if=front2.img of=/dev/rdisk8 bs=1m && sudo dd if=os2.img of=/dev/rdisk8 bs=1m seek=224125 status=progress && sync && diskutil eject /dev/disk8
```

## 5. After first boot (done live over SSH, not in the image yet)

- `systemd-timesyncd` on, timezone America/Mexico_City
- `/etc/update-motd.d/60-free-space`

Fold these into `build-stock.sh` before rebuilding.

## Other scripts kept for reference

- `scripts/customize.sh` — the Debian 13 port customization (that image doesn't boot here)
- `scripts/build-uboot.sh` — upstream TF-A + U-Boot with stock DRAM TPRs (also doesn't boot here)
