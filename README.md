# Anbernic RG35XX Plus as a pocket Linux server

How I turned an Anbernic RG35XX Plus into an on-the-go terminal and server (SSH, Tailscale,
Claude Code) by customizing Anbernic's **stock Ubuntu 22.04**, after every open-source image
failed to boot on my unit. Notes from November 2026.

> **Does this apply to your device?** Only if mainline-based images (ROCKNIX, muOS, Knulli, the
> Debian ports) don't boot on your RG35XX Plus either. If they do, use one of those: you get a
> modern kernel and no vendor quirks. My unit has a board revision whose LPDDR4 RAM mainline U-Boot
> can't initialize; see [limitations.md](limitations.md).

## The short version

- **Only the stock Anbernic bootloader works on my unit.** Its board revision has LPDDR4 RAM that
  the open-source (mainline) U-Boot can't bring up, so Debian ports, ROCKNIX and other
  mainline-based images never boot. Proven over USB (FEL): see
  [how-we-got-here.md](how-we-got-here.md).
- **So the server is the stock Ubuntu 22.04**, customized offline in a Linux VM: a user of your
  own, key-only SSH, `rg35xx.local`, Claude Code, Tailscale, shell tools.
- **The stock bootloader is picky about the partition table**: clone the stock GPT exactly
  (8 entries, same order and attribute flags), only moving partitions.
- **Never write to your original stock card.** Copy it read-only first; it's your known-good
  reference and your backup.

## What's here

| File | What's in it |
|---|---|
| [system-info.md](system-info.md) | Hardware, OS, partitions, installed software, configuration |
| [connecting.md](connecting.md) | How to talk to it: SSH, Tailscale, USB/FEL, SD cards, the build VM |
| [limitations.md](limitations.md) | What this unit can and can't do, and why |
| [do-not.md](do-not.md) | Things that break it or waste hours |
| [how-we-got-here.md](how-we-got-here.md) | The investigation: every attempt, what failed and the evidence |
| [building-the-image.md](building-the-image.md) | How the working SD card image is built, step by step |
| [scripts/](scripts/) | The build scripts |

## What you need

- An RG35XX Plus and its **original stock SD card**, plus a second microSD card for the server.
- A Mac with Apple Silicon (the steps use `diskutil`, Homebrew and a native arm64
  [Lima](https://lima-vm.io) VM). Any Linux arm64 machine works too with small changes.
- ~60 GB free for the build folder.
- A microSD card reader.

## Adapting it to your setup

The docs and scripts are written from my setup. Change these:

| What | Mine | Yours |
|---|---|---|
| Build folder | an external drive | set `RG35` to any folder, e.g. `export RG35="$HOME/rg35"` |
| Username on the device | `grillermo` | `RG_USER=<name>` when running `build-stock.sh` |
| SSH keys baked in | my machines' keys | put your `*.pub` files in `$RG35/build/keys/` |
| Target card size | 248.3 GB (`248302796800` bytes) | `CARD_BYTES=<bytes>` for `build-stock.sh` and `assemble2.sh` |
| Stock partition offsets | from my 255.9 GB card | read yours with `sudo gpt -r show /dev/diskN` |
| Card reader disk | `disk4`, `disk8`, … | check `diskutil list` **every time**, before any write |
| Timezone / Wi-Fi country | Mexico City / MX | set your own after first boot |

Start with [building-the-image.md](building-the-image.md), and read [do-not.md](do-not.md) before
writing any card.

## Security notes

- The image sets up **passwordless sudo** for your user and **key-only SSH** (root login and
  passwords off). If you'd rather type a password for sudo, give the user one and remove
  `/etc/sudoers.d/<user>`.
- Your stock card's saved Wi-Fi networks (with their passwords) carry over into the image, so
  don't share your built images.

## License

[MIT](LICENSE). No warranty: writing raw SD cards can destroy data if you pick the wrong disk.
