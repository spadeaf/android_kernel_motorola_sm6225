#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-out}"
ZIP_NAME="${2:-KernelSU-Next-caprip.zip}"

echo "=== Packaging Kernel with AnyKernel3 ==="

if [ ! -f "${OUT_DIR}/arch/arm64/boot/Image" ]; then
    echo "ERROR: Kernel image ${OUT_DIR}/arch/arm64/boot/Image not found!"
    exit 1
fi

AK3_DIR="AnyKernel3"
rm -rf "${AK3_DIR}"
git clone --depth=1 https://github.com/osm0sis/AnyKernel3 "${AK3_DIR}"

# Customize anykernel.sh for caprip
cat << 'EOF' > "${AK3_DIR}/anykernel.sh"
### AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
kernel.string=KernelSU-Next for Moto G30 (caprip) - LineageOS 23.2
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=caprip
device.name2=capri
device.name3=bengal
device.name4=moto g(30)
device.name5=moto g30
supported.versions=11 - 16
supported.patchlevels=
'; } # end properties

# shell variables
block=boot;
is_slot_device=auto;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;

## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh;

## AnyKernel install
split_boot;

flash_boot;
## end install
EOF

# Copy kernel Image
cp "${OUT_DIR}/arch/arm64/boot/Image" "${AK3_DIR}/Image"

# Copy dtb / dtbo if present
if [ -f "${OUT_DIR}/arch/arm64/boot/dtb.img" ]; then
    cp "${OUT_DIR}/arch/arm64/boot/dtb.img" "${AK3_DIR}/dtb"
elif [ -f "${OUT_DIR}/arch/arm64/boot/dtb" ]; then
    cp "${OUT_DIR}/arch/arm64/boot/dtb" "${AK3_DIR}/dtb"
fi

if [ -f "${OUT_DIR}/arch/arm64/boot/dtbo.img" ]; then
    cp "${OUT_DIR}/arch/arm64/boot/dtbo.img" "${AK3_DIR}/dtbo.img"
fi

cd "${AK3_DIR}"
zip -r9 "../${ZIP_NAME}" * -x .git README.md *placeholder
cd ..

echo "=== Successfully created ${ZIP_NAME} ==="
ls -lh "${ZIP_NAME}"
