#!/bin/bash

# QEMU がカーネルを直接起動する版（U-Boot なし、initramfs）。

# 使う Linux カーネルのバージョン（スクリプト名と合わせる）
KERNEL_VERSION=5.4.83
KERNEL=./linux-${KERNEL_VERSION}/arch/arm64/boot/Image

if [ ! -f "$KERNEL" ]; then
    echo "カーネルが見つかりません: $KERNEL" >&2
    exit 1
fi

mkdir -p logs/qemu
LOG=logs/boot-direct-5.4.log
echo "== kernel: linux-${KERNEL_VERSION} ==" | tee $LOG

qemu-system-aarch64 \
    -M virt \
    -cpu cortex-a53 \
    -kernel $KERNEL \
    -initrd ./busybox/rootfs.img \
    -nographic \
    -append "console=ttyAMA0" \
    -d guest_errors \
    -D logs/qemu/qemu-direct-5.4.log \
    2>&1 | tee -a $LOG
