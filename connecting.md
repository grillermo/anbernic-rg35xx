# How to talk to it

## SSH (normal use)

```bash
ssh <user>@rg35xx.local
```

- Key-only. Root login and passwords are off. Works from any machine whose key is in
  `~/.ssh/authorized_keys`.
- `rg35xx.local` is mDNS (Avahi). If it doesn't resolve, use the DHCP address your router
  gave it.
- The welcome screen shows free disk space (System and Roms).
- `mosh <user>@rg35xx.local` also works (mosh is installed; ufw is off).
- Non-interactive commands: `command ssh -o BatchMode=yes <user>@rg35xx.local '<cmd>'`.

## Tailscale (away from home)

The image ships it installed and running, **not logged in**. Once, on the device:

```bash
sudo tailscale up
```

Open the printed link to authorize. The kernel has TUN built in, so normal (kernel) mode works.

## Claude Code

`claude` is on the PATH. First run asks to log in (needs the clock to be right — NTP is on now).
1 GB RAM is well under the 4 GB requirement: fine for chat and light edits, risky for builds.
For heavy work, SSH from the handheld to a bigger machine instead.

## The built-in console

The stock launcher owns the screen. There's no Linux login on the LCD.

## SD cards

- **TF1** (the slot the device boots from) holds the OS. **TF2** is extra storage.
- On macOS, card readers show up as `/dev/diskN`. The number changes every time a card is
  inserted (it's been both `disk4` and `disk8`), so **check `diskutil list` by size every time**:
  - the server card (test card): **248.3 GB** (`248302796800` bytes)
  - the healthy stock card: **255.9 GB** — never write to it
- macOS can't mount ext4; the FAT partitions (`ROMS`, `Volumn`) do mount.
- Writing raw cards needs `sudo`, so run those commands yourself in a terminal.

## USB-C / FEL (low-level recovery)

The H700 drops into **FEL** (USB recovery in the boot ROM) when it finds no bootable card:

1. Remove both cards. Connect USB-C straight to the Mac (a data cable, not via a dock).
2. **Short-press** power 2–3 s. (Holding ~10 s forces power-off.) Screen stays black; the orange
   LED is only the charger.
3. The Mac sees USB vendor `0x1f3a` (decimal `7994`):
   `ioreg -p IOUSB -l -w0 | grep '"idVendor" = 7994'`

Tool: `sunxi-fel`, built from source (no Homebrew formula) at
`$RG35/tools/sunxi-fel` (needs `brew install libusb dtc pkgconf`).

```bash
F="$RG35/tools/sunxi-fel"
"$F" ver                 # AWUSBFEX soc=00001823(H616)
"$F" readl 0x00020000    # SRAM read, always safe
"$F" spl <u-boot-sunxi-with-spl.bin>   # run SPL (DRAM init) and return to FEL
```

- A DRAM access that hangs wedges FEL; power-cycle (hold 10 s, then short press) to recover.
- macOS has no `timeout`; use `perl -e 'alarm shift; exec @ARGV' 10 <cmd>`.
- FEL gives no boot log. For that you need the **UART** pads (3.3 V USB-serial adapter,
  115200 baud) — requires opening the device.

## The build VM (Lima)

A Debian 13 arm64 VM used to edit images (loop mounts, chroot). It lives in the build folder `$RG35`:

```bash
export LIMA_HOME="$RG35/lima-home"
limactl start rg35
limactl shell rg35
```

- `$RG35/build` is mounted **writable** at `/tmp/rg35-build` inside the VM.
- Lima ignores instance folders that are symlinks — that's why it has its own `LIMA_HOME`.
- Native arm64 on Apple Silicon: chrooting into the device's arm64 rootfs needs no emulation.
