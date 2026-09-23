#!/bin/bash

# TF-A → U-Boot → ディスク（rootdisk-5.4.img）の boot.scr → カーネル → /dev/vda2 をルートにして /sbin/init。
# BL1 → BL2 → BL31（EL3 に常駐）→ BL33（U-Boot, EL2）→ Linux（EL2）の順に動く。
# PSCI（CPU の起動・poweroff など）には QEMU ではなく TF-A の BL31 が応える。
# secure=on: EL3 を有効にする / virtualization=on: EL2 を有効にする
# -m 1024: BL2 が U-Boot を 0x60000000 に置くため、既定の 128MB では足りない
# 終了するときはシェルで poweroff。

# 使う Linux カーネルのバージョン（スクリプト名と合わせる）
# カーネルはディスクイメージの中にある。作り方: ./make-rootdisk.sh 5.4
KERNEL_VERSION=5.4.83
DISK=rootdisk-5.4.img
FW=./tf-a/build/qemu/debug/qemu_fw.bios

if [ ! -f "$FW" ]; then
    echo "$FW がありません。先に ./make-tfa.sh を実行してください" >&2
    exit 1
fi
if [ ! -f "$DISK" ]; then
    echo "$DISK がありません。先に ./make-rootdisk.sh 5.4 を実行してください" >&2
    exit 1
fi

mkdir -p logs/qemu
LOG=logs/boot-tfa-uboot-rootdisk-5.4.log
echo "== kernel: linux-${KERNEL_VERSION}（$DISK 内）==" | tee $LOG

qemu-system-aarch64 \
    -M virt,secure=on,virtualization=on \
    -cpu cortex-a53 \
    -m 1024 \
    -bios $FW \
    -drive if=none,file=$DISK,format=raw,id=hd0 \
    -device virtio-blk-device,drive=hd0 \
    -nographic \
    -d guest_errors \
    -D logs/qemu/qemu-tfa-uboot-rootdisk-5.4.log \
    2>&1 | tee -a $LOG
