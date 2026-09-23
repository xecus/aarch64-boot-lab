#!/bin/bash

# TF-A（Trusted Firmware-A）を QEMU virt 向けにビルドし、
# BL1 + FIP（BL2・BL31・BL33=U-Boot）を連結した qemu_fw.bios を作る。
# 使い方: ./make-tfa.sh
# U-Boot を作り直したら、これも実行し直す（u-boot.bin が FIP に入るため）。
set -e
cd "$(dirname "$0")"

UBOOT=./u-boot/u-boot.bin
[ -d tf-a ] || { echo "tf-a/ がありません。README の手順で取得してください" >&2; exit 1; }
[ -f "$UBOOT" ] || { echo "U-Boot が見つかりません: $UBOOT" >&2; exit 1; }

# デバッグ版とリリース版の両方を作る。出力先は tf-a/build/qemu/{debug,release}/
# DEBUG=1: 起動ログ（INFO）が詳しく出る。cortex-a53 / cortex-a72 で使う
# DEBUG=0: ログは NOTICE のみ。cortex-a55 / a76 / a710 で使う（理由は run.sh の tfa-uboot-rootdisk）
for DEBUG in 1 0; do
    make -C tf-a CROSS_COMPILE=aarch64-linux-gnu- PLAT=qemu DEBUG=$DEBUG \
        BL33=$(realpath $UBOOT) all fip -j$(nproc)
done

echo "tf-a/build/qemu/{debug,release}/qemu_fw.bios を作成しました"
