#!/bin/bash
# Re-assemble with a stock-faithful GPT, reusing the customized partitions from /work/stock.img.
set -euo pipefail
SRC=/tmp/rg35-build/stock; OUT=/tmp/rg35-build/out
CARD_BYTES=248302796800; SECTORS=$((CARD_BYTES/512))
OLD=/work/stock.img; NEW=/work/stock2.img
python3 /tmp/relayout.py $SRC/head-36M.bin $SECTORS /work/gpt-pri.bin /work/gpt-bak.bin
P2NEW=$(python3 - <<EOF
import struct; d=open("/work/gpt-pri.bin","rb").read(); print(struct.unpack("<Q", d[1024+128+32:1024+128+40])[0]//2048)
EOF
)
rm -f $NEW; truncate -s $CARD_BYTES $NEW
dd if=$SRC/head-36M.bin of=$NEW bs=1M count=36 conv=notrunc status=none
dd if=/work/gpt-pri.bin of=$NEW bs=512 count=4 conv=notrunc status=none
dd if=/work/gpt-bak.bin of=$NEW bs=512 seek=$((SECTORS-3)) conv=notrunc status=none
# customized p2..p7 sit contiguously in OLD from 36 MiB, total 12674 MiB, same order/sizes
dd if=$OLD of=$NEW bs=1M skip=36 seek=$P2NEW count=12674 conv=notrunc status=none
sgdisk -v $NEW | tail -3; sgdisk -p $NEW | tail -8
cmp <(dd if=$NEW bs=8192 skip=1 count=4607 status=none) <(dd if=$SRC/head-36M.bin bs=8192 skip=1 count=4607 status=none) && echo "boot0+boot_package intact"
cmp <(dd if=$NEW bs=1M skip=$P2NEW count=12674 status=none) <(dd if=$OLD bs=1M skip=36 count=12674 status=none) && echo "OS partitions match customized build"
LOOP=$(losetup -fP --show $NEW); mkfs.vfat -F 32 -n ROMS ${LOOP}p1 >/dev/null; blkid ${LOOP}p1 ${LOOP}p5; losetup -d $LOOP
rm -f $OUT/front.img $OUT/tail-gpt.bin
dd if=$NEW of=$OUT/front2.img bs=1M count=$((36+128)) status=none
dd if=$NEW of=$OUT/os2.img bs=1M skip=$P2NEW status=none
echo "P2NEW_MIB=$P2NEW"; ls -l $OUT
