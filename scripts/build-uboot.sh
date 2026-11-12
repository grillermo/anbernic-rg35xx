#!/bin/bash
# Build TF-A BL31 + mainline U-Boot for the H700 RG35XX family with this unit's stock DRAM timings.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
sudo apt-get -qq update
sudo apt-get -qq install -y build-essential bc bison flex libssl-dev python3-dev python3-setuptools \
  python3-pyelftools swig device-tree-compiler libgnutls28-dev uuid-dev git >/dev/null
W=$HOME/ub && mkdir -p "$W" && cd "$W"
[ -d tfa ] || git clone -q --depth 1 https://github.com/ARM-software/arm-trusted-firmware tfa
[ -d u-boot ] || git clone -q --depth 1 https://github.com/u-boot/u-boot u-boot
make -C tfa -j4 PLAT=sun50i_h616 DEBUG=0 bl31 >/dev/null
BL31=$W/tfa/build/sun50i_h616/release/bl31.bin
cd u-boot
make -s anbernic_rg35xx_h700_defconfig
./scripts/config --set-val DRAM_SUNXI_TPR6 0x42808080 \
                 --set-val DRAM_SUNXI_TPR11 0x24272825 \
                 --set-val DRAM_SUNXI_TPR12 0x06050606
make -s olddefconfig
grep -E 'DRAM_(CLK|SUNXI_TPR(6|11|12)|SUNXI_DX|SUNXI_CA)' .config
make -s -j4 BL31="$BL31" SCP=/dev/null
OUT=/tmp/rg35-build/uboot-stocktpr-with-spl.bin
cp u-boot-sunxi-with-spl.bin "$OUT"
ls -l "$OUT"; strings "$OUT" | grep -m2 'U-Boot SPL'
