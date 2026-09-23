#!/bin/bash

# TF-A → U-Boot → ディスク（rootdisk-5.4.img）の boot.scr → カーネル → /dev/vda2 をルートにして /sbin/init。
# BL1 → BL2 → BL31（EL3 に常駐）→ BL33（U-Boot, EL2）→ Linux（EL2）の順に動く。
# PSCI（CPU の起動・poweroff など）には QEMU ではなく TF-A の BL31 が応える。
# secure=on: EL3 を有効にする / virtualization=on: EL2 を有効にする
# -m 1024: BL2 が U-Boot を 0x60000000 に置くため、既定の 128MB では足りない
# 終了するときはシェルで poweroff。

# 第1引数で CPU を選ぶ（省略すると cortex-a53。一覧は select-cpu.sh）
. ./select-cpu.sh

# 使う Linux カーネルのバージョン（スクリプト名と合わせる）
# カーネルはディスクイメージの中にある。作り方: ./make-rootdisk.sh 5.4
KERNEL_VERSION=5.4.83
DISK=rootdisk-5.4.img
# a55 / a76 / a710（DynamIQ 世代）では、デバッグビルドの TF-A が起動時のエラッタ表示で
# DSU のレジスタ CLUSTERIDR_EL1 を読み、QEMU が実装していないため BL1 で止まる。
# エラッタ表示は DEBUG=1 と連動していて切れないので、これらはリリースビルドを使う（ログは NOTICE のみ）。
case "$CPU" in
    cortex-a53|cortex-a72) FW=./tf-a/build/qemu/debug/qemu_fw.bios ;;
    *)                     FW=./tf-a/build/qemu/release/qemu_fw.bios ;;
esac

if [ ! -f "$FW" ]; then
    echo "$FW がありません。先に ./make-tfa.sh を実行してください" >&2
    exit 1
fi
if [ ! -f "$DISK" ]; then
    echo "$DISK がありません。先に ./make-rootdisk.sh 5.4 を実行してください" >&2
    exit 1
fi

mkdir -p logs/qemu
LOG=logs/boot-tfa-uboot-rootdisk-5.4-${CPU}.log
echo "== kernel: linux-${KERNEL_VERSION}（$DISK 内）==" | tee $LOG
echo "== cpu: $CPU ==" | tee -a $LOG

qemu-system-aarch64 \
    -M virt,secure=on,virtualization=on \
    -cpu $CPU \
    -m 1024 \
    -bios $FW \
    -drive if=none,file=$DISK,format=raw,id=hd0 \
    -device virtio-blk-device,drive=hd0 \
    -nographic \
    -d guest_errors \
    -D logs/qemu/qemu-tfa-uboot-rootdisk-5.4-${CPU}.log \
    2>&1 | tee -a $LOG
