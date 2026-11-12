# What not to do

## Never

- **Never write to the healthy stock card** (the one the device shipped with; stock layout: `Roms`
  + 6 OS partitions at the end). It's the proof the device works and the only untouched copy. Reading it with
  `dd if=/dev/rdiskN of=<file>` is fine; anything with `of=/dev/...` is not.
- **Never reuse an old `dd` command without re-checking the disk number.** The card reader's
  `/dev/diskN` changes on every insert (`disk4`, `disk8`, ...). Both cards have been `disk8`.
  Guard writes by the target card's exact size, as in
  [building-the-image.md](building-the-image.md#4-write-the-card-run-it-yourself-guarded-by-size).
- **Never hold power 10 s expecting it to turn on** — that's forced power-off. Short press 2–3 s.

## Don't bother (already proven to fail on this unit)

- Mainline-based OSes: the **rg35xxh-debian13** port, **ROCKNIX** (DDR3 and DDR4, with or
  without `dtb.img`), and muOS/Knulli images that use mainline U-Boot. See
  [limitations.md](limitations.md).
- Swapping the bootloader for the DDR3 or DDR4 ROCKNIX U-Boot (the RAM is LPDDR4 anyway).
- Rebuilding upstream U-Boot with the stock `TPR6/TPR11/TPR12` values — still hangs on DRAM.
- Cloudflare WARP on the handheld: not tried, I used Tailscale instead.

## Partition table rules for the stock bootloader

- **Don't let sgdisk lay out the GPT from scratch.** A table with the right sizes but a different
  order (Roms last) and zero attribute flags gave a black screen.
- Clone the stock GPT and only change offsets: keep **8 entries** (a 128-entry table overlaps
  boot0 at 8 KiB), the same **order** (Roms, boot-resource, env, boot, rootfs, appfs, UDISK), the
  same **attribute flags**, partition GUIDs and names. `scripts/relayout.py` does this.
- Keep the partition **numbers**: the kernel and U-Boot use `mmcblk0p5` etc., not labels.
- Don't touch bytes 8 KiB–36 MiB of the card (boot0 + boot_package) except by copying the stock
  ones verbatim.

## On the running system

- Don't `apt full-upgrade` blindly (vendor stack). Install specific packages instead.
- Don't fill the 7 GiB rootfs; use `/mnt/mmc` or `/mnt/data`.
- Don't leave `Roms` unformatted or non-vfat: stock `loadapp.sh` **runs `mkfs.vfat` on it** if it
  can't mount it.
- Don't enable `ufw` without allowing SSH (22/tcp), mosh (60000–61000/udp) and mDNS (5353/udp).
- Don't turn off `systemd-timesyncd`: the clock resets to 2022 without it.

## On the Mac

- Keep build files out of `/tmp` — macOS clears it on reboot. They live on
  `$RG35/`.
- Don't symlink a Lima instance folder; use `LIMA_HOME`.
- Don't connect the device through the dock for FEL; plug it straight into the Mac.
