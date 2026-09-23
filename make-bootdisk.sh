#!/bin/bash

# boot/boot.cmd を boot.scr に変換し、Image・rootfs.img と一緒に
# ext4 パーティション 1 つのディスクイメージ（bootdisk-<版>.img）に入れる。
# 使い方: ./make-bootdisk.sh 5.4   （6.18 / 7.2 も可）
# root 権限不要（mkfs.ext4 -d でディレクトリの中身を直接書き込む）。
set -e
cd "$(dirname "$0")"

VER=$1
case "$VER" in
    5.4)  KERNEL_VERSION=5.4.83 ;;
    6.18) KERNEL_VERSION=6.18.53 ;;
    7.2)  KERNEL_VERSION=7.2.7 ;;
    *)    echo "使い方: $0 {5.4|6.18|7.2}" >&2; exit 1 ;;
esac
KERNEL=./linux-${KERNEL_VERSION}/arch/arm64/boot/Image
[ -f "$KERNEL" ] || { echo "カーネルが見つかりません: $KERNEL" >&2; exit 1; }

MKIMAGE=./u-boot/tools/mkimage
OUT=bootdisk-${VER}.img
STAGE=boot/stage-bootdisk-${VER}
DISK_MB=96
PART_START=2048     # パーティション開始セクタ（1MiB）

$MKIMAGE -A arm64 -O linux -T script -C none -n "boot script" \
    -d boot/boot.cmd boot/boot.scr

rm -rf $STAGE
mkdir -p $STAGE
cp boot/boot.scr $STAGE/
cp $KERNEL $STAGE/
cp busybox/rootfs.img $STAGE/

rm -f $OUT
truncate -s ${DISK_MB}M $OUT
echo "start=${PART_START}, type=83" | sfdisk -q $OUT
mkfs.ext4 -q -F -L boot -E offset=$((PART_START * 512)) -d $STAGE \
    $OUT $(( (DISK_MB - 1) * 1024 ))k

echo "$OUT を作成しました（kernel: linux-${KERNEL_VERSION}）"
