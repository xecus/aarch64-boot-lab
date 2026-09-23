#!/bin/bash

# U-Boot 経由で起動する版。
# -kernel / -initrd / -append は QEMU の fw_cfg 経由で U-Boot に渡され、
# U-Boot の bootflow（qfw）が自動で読み込んで booti する。

# 第1引数で CPU を選ぶ（省略すると cortex-a53。一覧は select-cpu.sh）
. ./select-cpu.sh

# 使う Linux カーネルのバージョン（スクリプト名と合わせる）
KERNEL_VERSION=7.2.7
KERNEL=./linux-${KERNEL_VERSION}/arch/arm64/boot/Image

if [ ! -f "$KERNEL" ]; then
    echo "カーネルが見つかりません: $KERNEL" >&2
    exit 1
fi

mkdir -p logs/qemu
LOG=logs/boot-uboot-qfw-7.2-${CPU}.log
echo "== kernel: linux-${KERNEL_VERSION} ==" | tee $LOG
echo "== cpu: $CPU ==" | tee -a $LOG

qemu-system-aarch64 \
    -M virt \
    -cpu $CPU \
    -bios ./u-boot/u-boot.bin \
    -kernel $KERNEL \
    -initrd ./busybox/rootfs.img \
    -nographic \
    -append "console=ttyAMA0" \
    -d guest_errors \
    -D logs/qemu/qemu-uboot-qfw-7.2-${CPU}.log \
    2>&1 | tee -a $LOG
