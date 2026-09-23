#!/bin/bash

# gdb デバッグ用。QEMU は CPU を止めた状態（-S）で起動し、
# TCP 1234 番で gdb の接続を待つ（-s）。
# 別ターミナルで: gdb-multiarch -x debug-6.18.gdb
# nokaslr: vmlinux のシンボルアドレスと実行時アドレスを一致させるため

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
LOG=logs/boot-direct-debug-6.18-${CPU}.log
echo "== kernel: linux-${KERNEL_VERSION} ==" | tee $LOG
echo "== cpu: $CPU ==" | tee -a $LOG
echo "== 別のターミナルで: gdb-multiarch -x debug-6.18.gdb ==" | tee -a $LOG

qemu-system-aarch64 \
    -M virt \
    -cpu $CPU \
    -kernel $KERNEL \
    -initrd ./busybox/rootfs.img \
    -nographic \
    -append "console=ttyAMA0 nokaslr" \
    -s -S \
    -d guest_errors \
    -D logs/qemu/qemu-direct-debug-6.18-${CPU}.log \
    2>&1 | tee -a $LOG
