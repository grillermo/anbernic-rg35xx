# How we got here (2026-11-11)

Goal: use the RG35XX Plus as a pocket terminal/server (SSH, services over Wi-Fi, Claude Code),
not mainly for games.

## 1. Choosing an OS

- Gaming CFWs (muOS, Knulli, ROCKNIX, MinUI) have read-only systems and no package manager, so
  poor fits for a server.
- Picked the **rg35xxh-debian13** port (Debian 13, mainline kernel 7.1.2, U-Boot 2026.01 with
  ROCKNIX H700 patches), built for the RG35XX **H** (sister board).
- Claude Code: Debian 10+/Ubuntu 20.04+ on ARM64 are supported; 1 GB RAM is under the 4 GB spec.
- Cloudflare WARP has arm64 trixie packages, but I went with Tailscale instead.

## 2. Custom Debian image (didn't boot)

Built in a Lima VM by chrooting into the image: my user, SSH keys from my machines,
key-only SSH, Claude Code, Tailscale, shell tools, `rg35xx.local`. Also disabled the H's
`adc-joystick` DT node (Plus has no sticks) and set the Wi-Fi country to MX.

On the device: **nothing** — no LED, no backlight. `wifi.txt` never became `wifi.txt.applied` and
the rootfs never grew, so Linux never started.

## 3. Bootloader swaps (didn't boot)

Swapped only the U-Boot area (8 KiB–1 MiB) for ROCKNIX's DDR3 build, then DDR4 (verified with
`cmp`). Still nothing.

Read the stock boot0 from the healthy card (read-only): **DRAM type 8 = LPDDR4 @ 672 MHz**. So RAM
type wasn't the issue.

A ROCKNIX DDR4 full image also gave a black screen (but that test lacked ROCKNIX's required
`dtb.img`, so on its own it proved nothing).

## 4. FEL over USB (the proof)

Built `sunxi-fel`. FEL worked (`soc=00001823(H616)`).

| SPL | Returns to FEL? | SRAM after | DRAM after |
|---|---|---|---|
| Debian port (LPDDR4) | no — device dropped off USB | — | — |
| ROCKNIX DDR4 | yes | — | write timed out, FEL wedged |
| Upstream U-Boot + stock TPR6/11/12 | yes | `readl 0x20000` OK | `readl 0x40000000` hangs |

Compared stock DRAM params with upstream's defconfig: TPR6/TPR11/TPR12 differ. Using the stock
values didn't help. **Conclusion: mainline DRAM init doesn't work on this board revision.**
(Anbernic has shipped silent revisions before: the early-2026 RG35XX Pro broke muOS/Knulli.)

## 5. Stock Ubuntu, customized (works)

- Copied, read-only, the healthy card's first 36 MiB (boot0 + U-Boot) and its six OS partitions
  (12.4 GB) to files. The stock OS: Ubuntu 22.04, kernel 4.9.170 with TUN, ufw off,
  NetworkManager with my Wi-Fi already saved, `Roms` mounted as vfat by `loadapp.sh`.
- The test card is 248.3 GB vs the stock 255.9 GB, so the OS partitions (which sit at the end of
  the stock card) had to move.
- **Attempt 1 — sgdisk layout, OS partitions first, Roms last, flags 0: black screen.**
- **Attempt 2 — stock GPT cloned, only offsets shifted by 7216 MiB: boots.** (Same order, 8
  entries, attribute flags, GUIDs.)
- Customized in a chroot: user, keys, sudo, sshd hardening, hostname, Avahi, Claude Code 2.1.311,
  Tailscale 1.104.6, tools.

## 6. After first boot

- SSH works; Wi-Fi connected automatically; services up; root and password SSH refused.
- The clock was **2022-04-07 UTC** with NTP off → enabled `systemd-timesyncd`, timezone
  America/Mexico_City.
- Added free disk space to the SSH welcome screen.

## Where things ended up

- The build VM and images take ~58 GB in `$RG35/`. Keep `build/stock/` (12 GB): it's the backup of
  the stock OS.
- Tailscale login and the first `claude` login are done on the device after first boot (see
  [connecting.md](connecting.md)).
