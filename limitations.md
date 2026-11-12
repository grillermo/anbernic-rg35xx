# Limitations

## Only the stock bootloader boots this unit

This RG35XX Plus is a board revision whose LPDDR4 the **mainline (open-source) U-Boot SPL can't
initialize**. Tested over USB FEL with three SPLs — the Debian 13 port's, ROCKNIX 20261101 DDR4,
and upstream U-Boot rebuilt with this unit's own stock DRAM timings:

| Step | Result |
|---|---|
| FEL / USB link | OK |
| SPL runs (DRAM init) and returns to FEL | OK (ROCKNIX, upstream); Debian's never returned |
| Chip SRAM readable afterwards | OK |
| **First DRAM access** | **hangs the chip** (all three) |

So, until upstream supports this revision, **none of these boot**: the Debian 13 port
(rg35xxh-debian13), ROCKNIX (DDR3 or DDR4), and any muOS/Knulli/other image built on mainline
U-Boot. It isn't the RAM type (stock boot0 says LPDDR4) and it isn't only the TPR timings.

Likely next step if anyone wants mainline: UART logs from the SPL, then compare stock boot0's DRAM
init (para1/para2, MR values, `tpr13`) against U-Boot's H616 LPDDR4 code.

## Consequences of running the stock OS

- **Kernel 4.9.170, vendor BSP, no source.** No kernel upgrades, no new drivers or modules. No
  nf_tables or WireGuard module (Tailscale uses its userspace WireGuard; TUN is built in, fine).
- **Ubuntu 22.04** — supported until 2027 (standard). Claude Code supports it.
- **Don't do `apt full-upgrade`** blindly: vendor-modified packages and the boot chain aren't from
  Ubuntu; an upgrade could replace something the launcher or boot needs.
- **System partition is 7 GiB with ~2.7 GB free.** Big things go on `/mnt/mmc` (Roms, vfat:
  no Unix permissions or symlinks) or `/mnt/data` (ext4, 1.2 GB).
- **Locale is Chinese** (`zh_CN.UTF-8`) — some command output is in Chinese.
- The stock launcher owns the LCD; there's no text console login on screen.

## Hardware limits

- **1 GB RAM**, no swap. Claude Code wants 4 GB: chat/light edits OK, builds and tests risky.
  Heavy work: SSH from the handheld to a bigger machine.
- 4× Cortex-A53 @ 1.4 GHz: fine for SSH, Syncthing, small web services; slow for compiling.
- Storage is an SD card: slow random I/O, wears out with heavy writes.
- Wi-Fi only (RTL8821CS). The one USB-C port is for charging + OTG.

## The SD card

- My server card is **248.3 GB**, smaller than the stock card (255.9 GB). Partition offsets
  differ from stock — the GPT was cloned and shifted, not copied.
- The clock had no NTP on stock (it booted at 2022-04-07 UTC). Fixed; but if NTP stops working,
  TLS, apt, Tailscale and Claude Code logins fail.
