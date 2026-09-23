#!/bin/bash

# U-Boot がディスク（bootdisk-6.18.img）上の boot.scr を見つけて起動する版（initramfs）。
# -kernel / -initrd は渡さない（渡すと fw_cfg 経由の起動が先に選ばれるため）。

# 使う Linux カーネルのバージョン（スクリプト名と合わせる）
# カーネルはディスクイメージの中にある。作り方: ./make-bootdisk.sh 6.18
KERNEL_VERSION=6.18.53
DISK=bootdisk-6.18.img

if [ ! -f "$DISK" ]; then
    echo "$DISK がありません。先に ./make-bootdisk.sh 6.18 を実行してください" >&2
    exit 1
fi

mkdir -p logs/qemu
LOG=logs/boot-uboot-initrd-disk-6.18.log
echo "== kernel: linux-${KERNEL_VERSION}（$DISK 内）==" | tee $LOG

qemu-system-aarch64 \
    -M virt \
    -cpu cortex-a53 \
    -bios ./u-boot/u-boot.bin \
    -drive if=none,file=$DISK,format=raw,id=hd0 \
    -device virtio-blk-device,drive=hd0 \
    -nographic \
    -d guest_errors \
    -D logs/qemu/qemu-uboot-initrd-disk-6.18.log \
    2>&1 | tee -a $LOG
