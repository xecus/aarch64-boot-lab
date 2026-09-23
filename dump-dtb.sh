#!/bin/bash

# ./run.sh direct 5.4 と同じ構成（linux-5.4.83）で QEMU が生成するデバイスツリーを取り出し、
# 読める形（.dts）に変換する。QEMU は dumpdtb 後すぐ終了する。
# 第1引数で CPU を選ぶ（省略すると cortex-a53。一覧は select-cpu.sh）。
# cortex-a53 以外では virt-<CPU>.dtb / virt-<CPU>.dts に書き出す。
. ./select-cpu.sh
select_cpu "$1" || { echo "使い方: $0 [CPU]" >&2; exit 1; }

if [ "$CPU" = cortex-a53 ]; then
    OUT=virt
else
    OUT=virt-$CPU
fi

qemu-system-aarch64 \
    -M virt,dumpdtb=$OUT.dtb \
    -cpu $CPU \
    -kernel ./linux-5.4.83/arch/arm64/boot/Image \
    -initrd ./busybox/rootfs.img \
    -nographic \
    -append "console=ttyAMA0"

# dtc はカーネルのソースに入っているものを使う（apt の device-tree-compiler でも可）
DTC=./linux-5.4.83/scripts/dtc/dtc
$DTC -I dtb -O dts -o $OUT.dts $OUT.dtb && echo "$OUT.dtb / $OUT.dts を作成しました"
