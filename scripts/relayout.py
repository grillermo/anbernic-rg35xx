#!/usr/bin/env python3
"""Clone the stock 8-entry GPT for a smaller card: same order, GUIDs and attributes;
Roms shrinks, partitions 2-7 shift down so UDISK keeps its distance from the card end.
Usage: relayout.py <stock-head.bin> <card-sectors> <out-primary.bin(LBA0-3)> <out-backup.bin(last 3 LBAs)>"""
import struct, sys, zlib

head, sectors, out_pri, out_bak = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
d = bytearray(open(head, "rb").read(4 * 512))
h = d[512:512 + 92]
old_backup = struct.unpack("<Q", h[32:40])[0]
old_last_usable = struct.unpack("<Q", h[48:56])[0]
n, esz = struct.unpack("<II", h[80:88])
assert (n, esz) == (8, 128)

new_backup = sectors - 1
new_last_usable = new_backup - (old_backup - old_last_usable)
ents = bytearray(d[1024:1024 + n * esz])

def get(i):  return struct.unpack("<QQ", ents[i*esz+32:i*esz+48])
def put(i, f, l): ents[i*esz+32:i*esz+48] = struct.pack("<QQ", f, l)

udisk_last = get(6)[1]
shift = (old_last_usable - udisk_last) - (new_last_usable - udisk_last)  # = old_last_usable - new_last_usable
shift = old_last_usable - new_last_usable
assert shift % 2048 == 0, shift
for i in range(1, 7):
    f, l = get(i); put(i, f - shift, l - shift)
rf, rl = get(0); put(0, rf, rl - shift)
print("shift sectors", shift, "=", shift // 2048, "MiB")
for i in range(7):
    f, l = get(i); name = ents[i*esz+56:i*esz+128].decode("utf-16le").rstrip("\0")
    print(f"  {i+1} {name:13} first={f} last={l} ({(l-f+1)//2048} MiB)")

ecrc = zlib.crc32(bytes(ents)) & 0xffffffff

def header(cur, alt, entries_lba):
    hh = bytearray(h)
    struct.pack_into("<QQ", hh, 24, cur, alt)
    struct.pack_into("<Q", hh, 48, new_last_usable)
    struct.pack_into("<Q", hh, 72, entries_lba)
    struct.pack_into("<I", hh, 88, ecrc)
    struct.pack_into("<I", hh, 16, 0)
    struct.pack_into("<I", hh, 16, zlib.crc32(bytes(hh)) & 0xffffffff)
    return bytes(hh) + b"\0" * (512 - 92)

# protective MBR: size of the 0xEE partition
mbr = bytearray(d[:512])
struct.pack_into("<I", mbr, 446 + 12, min(sectors - 1, 0xffffffff))
pri = bytes(mbr) + header(1, new_backup, 2) + bytes(ents) + b"\0" * (1024 - len(ents))
open(out_pri, "wb").write(pri)
# backup: entries at new_backup-2, header at new_backup
bak = bytes(ents) + b"\0" * (1024 - len(ents)) + header(new_backup, 1, new_backup - 2)
open(out_bak, "wb").write(bak)
print("Roms new last", get(0)[1], "| p2 start", get(1)[0], "=", get(1)[0] // 2048, "MiB")
