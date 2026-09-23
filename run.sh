#!/bin/bash

# QEMU（aarch64 virt）でカーネルを起動する。起動方法・カーネル版・CPU・CPU 数を引数で選ぶ。
#   ./run.sh direct 7.2
#   ./run.sh tfa-uboot-rootdisk 6.18 --cpu a76 --smp 4
# 終了: initramfs 版はシェルで exit（/init の poweroff -f で止まる）、rootdisk 版は poweroff。
# QEMU ごと止めるなら Ctrl-a x。

usage() {
    cat <<EOF
使い方: $0 [オプション] <起動方法> <版>

起動方法:
  direct              QEMU → カーネル（initramfs）
  direct-debug        direct と同じ。CPU を止めて gdb を待つ（gdb-multiarch -x debug-<版>.gdb）
  uboot-qfw           QEMU → U-Boot → fw_cfg 経由でカーネル（initramfs）
  uboot-initrd-disk   QEMU → U-Boot → bootdisk-<版>.img の boot.scr → カーネル（initramfs）
  uboot-rootdisk      QEMU → U-Boot → rootdisk-<版>.img の boot.scr → カーネル（/dev/vda2）
  tfa-uboot-rootdisk  QEMU → TF-A → U-Boot → rootdisk-<版>.img → カーネル（EL2 で起動）

版: 5.4 | 6.18 | 7.2

オプション:
  -c, --cpu CPU   QEMU の -cpu（省略すると cortex-a53。cortex- は省いてもよい）
                  $CPUS
  -s, --smp N     CPU の数（1〜8、省略すると 1）
  -h, --help      この説明を表示する
EOF
}

set -e
cd "$(dirname "$0")"
. ./select-cpu.sh

# ---- 引数 ----
CPU_ARG=
SMP=1
ARGS=()
while [ $# -gt 0 ]; do
    case "$1" in
        -c|--cpu)   [ $# -ge 2 ] || { usage >&2; exit 1; }; CPU_ARG=$2; shift 2 ;;
        --cpu=*)    CPU_ARG=${1#*=}; shift ;;
        -s|--smp)   [ $# -ge 2 ] || { usage >&2; exit 1; }; SMP=$2; shift 2 ;;
        --smp=*)    SMP=${1#*=}; shift ;;
        -h|--help)  usage; exit 0 ;;
        -*)         echo "不明なオプション: $1" >&2; usage >&2; exit 1 ;;
        *)          ARGS+=("$1"); shift ;;
    esac
done
[ ${#ARGS[@]} -eq 2 ] || { usage >&2; exit 1; }
METHOD=${ARGS[0]}
VER=${ARGS[1]}

select_cpu "$CPU_ARG" || exit 1

# 8 まで: virt の既定の割り込みコントローラー GICv2 が扱えるのは 8 CPU まで。
# 9 以上だと QEMU は GICv3 に切り替えてしまい、GICv2 前提でビルドした TF-A と合わなくなる。
case "$SMP" in
    [1-8]) ;;
    *) echo "--smp は 1〜8 で指定してください: $SMP" >&2; exit 1 ;;
esac

case "$VER" in
    5.4)  KERNEL_VERSION=5.4.83 ;;
    6.18) KERNEL_VERSION=6.18.53 ;;
    7.2)  KERNEL_VERSION=7.2.7 ;;
    *)    echo "版が不正です: $VER（5.4 | 6.18 | 7.2）" >&2; exit 1 ;;
esac
KERNEL=./linux-${KERNEL_VERSION}/arch/arm64/boot/Image
DISK=

# ---- 起動方法ごとの QEMU の引数 ----
MACHINE=virt
QEMU_ARGS=()
case "$METHOD" in
    direct|direct-debug)
        # QEMU がカーネルを直接起動する（U-Boot なし、initramfs）。
        APPEND="console=ttyAMA0"
        if [ "$METHOD" = direct-debug ]; then
            # QEMU は CPU を止めた状態（-S）で起動し、TCP 1234 番で gdb の接続を待つ（-s）。
            # nokaslr: vmlinux のシンボルアドレスと実行時アドレスを一致させるため
            APPEND="$APPEND nokaslr"
            QEMU_ARGS+=(-s -S)
        fi
        QEMU_ARGS+=(-kernel $KERNEL -initrd ./busybox/rootfs.img -append "$APPEND")
        ;;
    uboot-qfw)
        # -kernel / -initrd / -append は QEMU の fw_cfg 経由で U-Boot に渡され、
        # U-Boot の bootflow（qfw）が自動で読み込んで booti する。
        QEMU_ARGS+=(-bios ./u-boot/u-boot.bin
                    -kernel $KERNEL -initrd ./busybox/rootfs.img -append "console=ttyAMA0")
        ;;
    uboot-initrd-disk|uboot-rootdisk|tfa-uboot-rootdisk)
        # U-Boot がディスク上の boot.scr を見つけて起動する。カーネルはディスクイメージの中にある。
        # -kernel / -initrd は渡さない（渡すと fw_cfg 経由の起動が先に選ばれるため）。
        #   initrd-disk: bootdisk-<版>.img（Image + rootfs.img を initramfs として読み込む）
        #   rootdisk:    rootdisk-<版>.img（p1 の Image を起動し、/dev/vda2 をルートにして /sbin/init）
        if [ "$METHOD" = uboot-initrd-disk ]; then
            DISK=bootdisk-$VER.img
            MAKE_DISK="./make-bootdisk.sh $VER"
        else
            DISK=rootdisk-$VER.img
            MAKE_DISK="./make-rootdisk.sh $VER"
        fi
        [ -f "$DISK" ] || { echo "$DISK がありません。先に $MAKE_DISK を実行してください" >&2; exit 1; }

        if [ "$METHOD" = tfa-uboot-rootdisk ]; then
            # BL1 → BL2 → BL31（EL3 に常駐）→ BL33（U-Boot, EL2）→ Linux（EL2）の順に動く。
            # PSCI（CPU の起動・poweroff など）には QEMU ではなく TF-A の BL31 が応える。
            # secure=on: EL3 を有効にする / virtualization=on: EL2 を有効にする
            # -m 1024: BL2 が U-Boot を 0x60000000 に置くため、既定の 128MB では足りない
            #
            # a55 / a76 / a710（DynamIQ 世代）では、デバッグビルドの TF-A が起動時のエラッタ表示で
            # DSU のレジスタ CLUSTERIDR_EL1 を読み、QEMU が実装していないため BL1 で止まる。
            # エラッタ表示は DEBUG=1 と連動していて切れないので、これらはリリースビルドを使う（ログは NOTICE のみ）。
            case "$CPU" in
                cortex-a53|cortex-a72) FW=./tf-a/build/qemu/debug/qemu_fw.bios ;;
                *)                     FW=./tf-a/build/qemu/release/qemu_fw.bios ;;
            esac
            [ -f "$FW" ] || { echo "$FW がありません。先に ./make-tfa.sh を実行してください" >&2; exit 1; }
            MACHINE=virt,secure=on,virtualization=on
            QEMU_ARGS+=(-m 1024 -bios $FW)
        else
            QEMU_ARGS+=(-bios ./u-boot/u-boot.bin)
        fi
        QEMU_ARGS+=(-drive if=none,file=$DISK,format=raw,id=hd0
                    -device virtio-blk-device,drive=hd0)
        ;;
    *)
        echo "起動方法が不正です: $METHOD" >&2
        usage >&2
        exit 1
        ;;
esac

if [ -z "$DISK" ] && [ ! -f "$KERNEL" ]; then
    echo "カーネルが見つかりません: $KERNEL" >&2
    exit 1
fi

# ---- ログ ----
# CPU ごと（--smp 2 以上なら CPU 数も）に別のファイルにして、並べて比べられるようにする
NAME=$METHOD-$VER-$CPU
[ "$SMP" -eq 1 ] || NAME=$NAME-smp$SMP
mkdir -p logs/qemu
LOG=logs/boot-$NAME.log
if [ -n "$DISK" ]; then
    echo "== kernel: linux-${KERNEL_VERSION}（$DISK 内）==" | tee $LOG
else
    echo "== kernel: linux-${KERNEL_VERSION} ==" | tee $LOG
fi
echo "== cpu: $CPU x $SMP ==" | tee -a $LOG
if [ "$METHOD" = direct-debug ]; then
    echo "== 別のターミナルで: gdb-multiarch -x debug-$VER.gdb ==" | tee -a $LOG
fi

qemu-system-aarch64 \
    -M $MACHINE \
    -cpu $CPU \
    -smp $SMP \
    "${QEMU_ARGS[@]}" \
    -nographic \
    -d guest_errors \
    -D logs/qemu/qemu-$NAME.log \
    2>&1 | tee -a $LOG
