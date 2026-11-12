# System information

Measured on the running device on 2026-11-11.

## Hardware

| | |
|---|---|
| Model | Anbernic RG35XX Plus |
| SoC | Allwinner H700 (H616 family, `sun50iw9p1`), 4× Cortex-A53 (`CPU part 0xd03`), 480 MHz–1.416 GHz, governor `performance` |
| RAM | 1 GB **LPDDR4** @ 672 MHz (973 MB visible to Linux, ~700 MB free when idle) |
| Wi-Fi / BT | Realtek RTL8821CS over SDIO (`8821cs` driver), 2.4 + 5 GHz; Bluetooth via `rtl_btlpm` |
| PMIC / battery | AXP717 (`axp2202-battery` in sysfs), 3300–3700 mAh Li-ion |
| Storage | Two microSD slots: **TF1** = OS (boot), **TF2** = extra games/data |
| USB | One USB-C port: charging + OTG data. FEL recovery works over it |
| Display | 640×480 IPS, "old" LCD type per the kernel cmdline (`lcd_type=old`) |
| Serial | UART pads on the board (not used yet) — `console=ttyS0,115200` |

### Stock DRAM parameters (from the stock boot0 on the healthy card)

```
clk 672  type 8 (LPDDR4)  dx_odt 0x08080808  dx_dri 0x0e0e0e0e  ca_dri 0x0e0e
para0 0x7887bbbb  para1 0x30fa  para2 0x04000000
mr1 0x34 mr2 0x1b mr3 0x33 mr4 0x3 mr11 0x4 mr12 0x72 mr14 0x9 mr22 0x24
tpr2 0x1  tpr6 0x42808080  tpr10 0x402f6633  tpr11 0x24272825  tpr12 0x06050606  tpr13 0x2006c61
```

Upstream U-Boot's `anbernic_rg35xx_h700_defconfig` differs in `TPR6` (0x40808080),
`TPR11` (0x1b1f1e1c) and `TPR12` (0x06060606). Even with the stock values, mainline DRAM init fails
on this unit — see [limitations.md](limitations.md).

## Software

| | |
|---|---|
| OS | Ubuntu 22.04 LTS (Jammy), arm64, Anbernic stock image |
| Kernel | `4.9.170` vendor BSP, built 2024-08-21 (no source published). Has TUN built in; no nf_tables, no WireGuard module |
| Bootloader | Allwinner boot0 + U-Boot 2018.05 (2024-08-22), vendor build |
| Hostname | `rg35xx` (mDNS: `rg35xx.local`) |
| Locale | `en_US.UTF-8` (we switched it; stock was `zh_CN.UTF-8` + `LANGUAGE=zh_CN:zh`, backup at `/etc/default/locale.zh-backup`) |
| Timezone | `America/Mexico_City`, NTP via `systemd-timesyncd` (we enabled it; stock had it off) |
| Packages | ~1150 dpkg packages; apt mirrors: tuna.tsinghua.edu.cn (ubuntu-ports) + ports.ubuntu.com security |

### What we added

- User **`grillermo`** (zsh, groups sudo/netdev/audio/video/input/plugdev), **passwordless sudo**
- The SSH public keys of the user's machines (`~/.ssh/authorized_keys`)
- `/etc/ssh/sshd_config.d/10-rg35xx.conf`: `PermitRootLogin no`, `PasswordAuthentication no`
- **Claude Code** from Anthropic's apt repo (stable channel), **Tailscale** from its jammy repo
- git, tmux, mosh, zsh, htop, vim, ripgrep, rsync, jq, avahi-daemon + libnss-mdns
- `/etc/update-motd.d/60-free-space`: SSH welcome shows free space on System and Roms

### Services enabled

ssh, avahi-daemon, tailscaled, NetworkManager, wpa_supplicant, systemd-timesyncd,
systemd-resolved, cron, rsyslog, unattended-upgrades, ModemManager. `ufw` is installed but
**disabled** (`ENABLED=no`).

## Partitions (TF1 card, 248.3 GB)

GPT with only **8 entries** (LBA 2–3) so boot0 can sit at 8 KiB.

| # | Name | Size | FS | Mounted at | Role |
|---|---|---|---|---|---|
| — | (raw) | 36 MiB | — | — | GPT + boot0 @ 8 KiB + U-Boot boot_package @ ~16 MiB |
| p1 | Roms | 218.8 GB | vfat `ROMS` | `/mnt/mmc` | Games/data. Stock `loadapp.sh` mounts it, **formats it if unmountable** |
| p2 | boot-resource | 32 MiB | vfat `Volumn` | — | Boot logo, resources |
| p3 | env | 16 MiB | raw | — | U-Boot env (`root=/dev/mmcblk0p5`) |
| p4 | boot | 64 MiB | Android bootimg | — | Kernel + ramdisk |
| p5 | rootfs | 7 GiB | ext4 `linuxrootfs` | `/` | Ubuntu (2.7 GB free) |
| p6 | appfs | 4 GiB | ext4 `appfs` | `/mnt/vendor` | Stock launcher, emulators, `ctrl/` scripts |
| p7 | UDISK | 1.3 GiB | ext4 | `/mnt/data` | Stock data |

Partition attributes on p2–p6: `0xc000200000000000`; p7: `0xc000000000000000`; p1: `0x200000000000`.
The kernel finds partitions **by number** (`partitions=Roms@mmcblk0p1:...`, `root=/dev/mmcblk0p5`).

## Networks

The Wi-Fi networks saved in NetworkManager on the stock card carried over. On the home LAN it gets
its address by DHCP.
