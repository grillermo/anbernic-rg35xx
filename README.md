# Anbernic RG35XX Plus — pocket Linux server

What we learned setting up an Anbernic RG35XX Plus as an on-the-go terminal and server
(2026-11-11). The device runs Anbernic's **stock Ubuntu 22.04**, customized, and is reachable at
`ssh grillermo@rg35xx.local`.

| File | What's in it |
|---|---|
| [system-info.md](system-info.md) | Hardware, OS, partitions, installed software, configuration |
| [connecting.md](connecting.md) | How to talk to it: SSH, Tailscale, USB/FEL, SD cards, the build VM |
| [limitations.md](limitations.md) | What this unit can and can't do, and why |
| [do-not.md](do-not.md) | Things that break it or waste hours |
| [how-we-got-here.md](how-we-got-here.md) | The investigation: every attempt, what failed and the evidence |
| [building-the-image.md](building-the-image.md) | How the working SD card image is built, step by step |
| [scripts/](scripts/) | The build scripts. They create user `grillermo`; set `RG_USER=<name>` to use another |

## The short version

- **Only the stock Anbernic bootloader works on this unit.** Its board revision has LPDDR4 RAM
  that the open-source (mainline) U-Boot can't bring up, so Debian ports, ROCKNIX, and other
  mainline-based images never boot. Proven over USB (FEL): see
  [how-we-got-here.md](how-we-got-here.md).
- **So the server is the stock Ubuntu 22.04**, customized offline in a Linux VM: user
  `grillermo`, key-only SSH, `rg35xx.local`, Claude Code, Tailscale, shell tools.
- **The stock bootloader is picky about the partition table**: clone the stock GPT exactly
  (8 entries, same order and attribute flags), only moving partitions.
- **Never write to the "healthy" stock card** (255.9 GB). It's the known-good reference.
- Build files, the stock backup and the VM live on the external drive
  `/Volumes/externo 128GB/rg35/`.
