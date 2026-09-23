#!/bin/bash

# run-direct-5.4.sh と同じ構成（linux-5.4.83）で QEMU が生成するデバイスツリーを取り出し、
# 読める形（.dts）に変換する。QEMU は dumpdtb 後すぐ終了する。
qemu-system-aarch64 \
    -M virt,dumpdtb=virt.dtb \
    -cpu cortex-a53 \
    -kernel ./linux-5.4.83/arch/arm64/boot/Image \
    -initrd ./busybox/rootfs.img \
    -nographic \
    -append "console=ttyAMA0"

# dtc はカーネルのソースに入っているものを使う（apt の device-tree-compiler でも可）
DTC=./linux-5.4.83/scripts/dtc/dtc
$DTC -I dtb -O dts -o virt.dts virt.dtb && echo "virt.dtb / virt.dts を作成しました"
