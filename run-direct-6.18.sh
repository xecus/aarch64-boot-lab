#!/bin/bash

# QEMU がカーネルを直接起動する版（U-Boot なし、initramfs）。

# 第1引数で CPU を選ぶ（省略すると cortex-a53。一覧は select-cpu.sh）
. ./select-cpu.sh

# 使う Linux カーネルのバージョン（スクリプト名と合わせる）
KERNEL_VERSION=6.18.53
KERNEL=./linux-${KERNEL_VERSION}/arch/arm64/boot/Image

if [ ! -f "$KERNEL" ]; then
    echo "カーネルが見つかりません: $KERNEL" >&2
    exit 1
fi

mkdir -p logs/qemu
LOG=logs/boot-direct-6.18-${CPU}.log
echo "== kernel: linux-${KERNEL_VERSION} ==" | tee $LOG
echo "== cpu: $CPU ==" | tee -a $LOG

qemu-system-aarch64 \
    -M virt \
    -cpu $CPU \
    -kernel $KERNEL \
    -initrd ./busybox/rootfs.img \
    -nographic \
    -append "console=ttyAMA0" \
    -d guest_errors \
    -D logs/qemu/qemu-direct-6.18-${CPU}.log \
    2>&1 | tee -a $LOG
