#!/bin/bash

# 2 パーティション構成のディスクイメージ（rootdisk-<版>.img）を作る。
#   p1 (64MiB, ext4 "boot"):   boot.scr, Image
#   p2 (残り, ext4 "rootfs"):  busybox/_install + boot/rootfs-etc の /etc
# 使い方: ./make-rootdisk.sh 5.4   （6.18 / 7.2 も可）
# root 権限不要。/dev は空にしておき、カーネルの devtmpfs が自動でマウントする。
# 作り直すと、ゲストの中で書いたファイルは消える。
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
OUT=rootdisk-${VER}.img
DISK_MB=160
P1_START=2048                  # セクタ（1MiB）
P1_SECTORS=$((64 * 2048))      # 64MiB（6.18 以降の Image は約 50MB）
P2_START=$((P1_START + P1_SECTORS))
P2_SECTORS=$((DISK_MB * 2048 - P2_START))

BOOT_STAGE=boot/stage-rootdisk-boot-${VER}
ROOT_STAGE=boot/stage-rootdisk-rootfs-${VER}

# p1 の中身
$MKIMAGE -A arm64 -O linux -T script -C none -n "boot script (rootdisk)" \
    -d boot/boot-rootdisk.cmd boot/boot-rootdisk.scr
rm -rf $BOOT_STAGE
mkdir -p $BOOT_STAGE
cp boot/boot-rootdisk.scr $BOOT_STAGE/boot.scr
cp $KERNEL $BOOT_STAGE/

# p2 の中身（デバイスノードは root でないとコピーできないので dev は除外）
rm -rf $ROOT_STAGE
mkdir -p $ROOT_STAGE
(cd busybox/_install && tar cf - --exclude=./dev --exclude=./init .) | (cd $ROOT_STAGE && tar xf -)
mkdir -p $ROOT_STAGE/{dev,proc,sys,tmp,root}
cp -r boot/rootfs-etc $ROOT_STAGE/etc

# ディスクイメージ
rm -f $OUT
truncate -s ${DISK_MB}M $OUT
sfdisk -q $OUT <<PART
start=${P1_START}, size=${P1_SECTORS}, type=83
start=${P2_START}, size=${P2_SECTORS}, type=83
PART
mkfs.ext4 -q -F -L boot   -E offset=$((P1_START * 512)) -d $BOOT_STAGE \
    $OUT $((P1_SECTORS / 2))k
mkfs.ext4 -q -F -L rootfs -E offset=$((P2_START * 512)) -d $ROOT_STAGE \
    $OUT $((P2_SECTORS / 2))k

echo "$OUT を作成しました（kernel: linux-${KERNEL_VERSION}）"
