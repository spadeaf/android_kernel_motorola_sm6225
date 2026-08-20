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

# Remove repository metadata and documentation
rm -rf "${AK3_DIR}/.git" "${AK3_DIR}/.github" "${AK3_DIR}/README.md"

# Customize anykernel.sh for caprip (Moto G30)
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
device.name2=caprip_retail
device.name3=lineage_caprip
device.name4=capri
device.name5=bengal
device.name6=moto g(30)
device.name7=moto g30
device.name8=XT2129-2
device.name9=XT2129-1
supported.versions=11 - 16
supported.patchlevels=
'; } # end properties

# boot shell variables (MUST BE UPPERCASE for AnyKernel3 core)
BLOCK=/dev/block/bootdevice/by-name/boot;
IS_SLOT_DEVICE=1;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh;

## AnyKernel install
dump_boot;

write_boot;
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

# Copy kernel modules if present
if [ -d "${OUT_DIR}/modules/lib/modules" ]; then
    echo "=== Packaging compiled kernel modules ==="
    mkdir -p "${AK3_DIR}/modules/vendor/lib/modules"
    find "${OUT_DIR}/modules/lib/modules" -name "*.ko" -exec cp {} "${AK3_DIR}/modules/vendor/lib/modules/" \;
    find "${AK3_DIR}/modules/vendor/lib/modules" -name "*.ko" -exec llvm-strip --strip-unneeded {} + 2>/dev/null || true
    sed -i 's/do.modules=0/do.modules=1/' "${AK3_DIR}/anykernel.sh"
fi

# Set proper executable permissions
chmod 755 "${AK3_DIR}/anykernel.sh"
chmod 755 "${AK3_DIR}/META-INF/com/google/android/update-binary"
chmod 755 "${AK3_DIR}"/tools/*

# Remove any old zip
rm -f "${ZIP_NAME}"

# Package with Python zipfile to ensure proper POSIX permissions and deflate compression
python3 -c "
import os, zipfile, stat

src_dir = '${AK3_DIR}'
output_zip = '${ZIP_NAME}'

with zipfile.ZipFile(output_zip, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
    for root, dirs, files in os.walk(src_dir):
        rel_root = os.path.relpath(root, src_dir)
        if rel_root != '.':
            zinfo = zipfile.ZipInfo(rel_root + '/')
            zinfo.external_attr = (stat.S_IFDIR | 0o755) << 16
            zf.writestr(zinfo, '')

        for f in files:
            if f.endswith('placeholder'):
                continue
            file_path = os.path.join(root, f)
            rel_file = os.path.relpath(file_path, src_dir)
            st = os.stat(file_path)
            mode = st.st_mode & 0o777
            zinfo = zipfile.ZipInfo(rel_file)
            zinfo.external_attr = (stat.S_IFREG | mode) << 16
            with open(file_path, 'rb') as fp:
                zf.writestr(zinfo, fp.read(), compress_type=zipfile.ZIP_DEFLATED)
"

echo "=== Verifying flashable zip contents ==="
unzip -l "${ZIP_NAME}" | grep "META-INF/com/google/android/update-binary" || (echo "ERROR: update-binary missing from root of zip!" && exit 1)

echo "=== Successfully created and verified ${ZIP_NAME} ==="
ls -lh "${ZIP_NAME}"
