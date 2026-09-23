# aarch64-boot-lab

QEMU の aarch64 `virt` マシン上で、Linux カーネルの起動の流れを試す実験環境。

- カーネル: Linux 5.4.83 / 6.18.53 / 7.2.7（すべて `defconfig`）
- ファームウェア: TF-A v2.15.0（`PLAT=qemu`、EL3）
- ブートローダー: U-Boot v2024.01（`qemu_arm64_defconfig`）
- ユーザーランド: BusyBox 1.32（static リンク）
- 起動方法を 5 通り用意し、gdb でカーネルの入口から `/init` までを追える

## 動作確認した環境

| 項目 | バージョン |
|---|---|
| ホスト | Ubuntu 24.04 (x86_64) |
| クロスコンパイラ | aarch64-linux-gnu-gcc 13.3.0 |
| QEMU | 8.2.2 |

## ディレクトリ構成

```
.
├── run-*.sh              起動スクリプト（起動方法 × カーネル版）
├── make-bootdisk.sh      bootdisk-<版>.img を作る（U-Boot + initramfs 用）
├── make-rootdisk.sh      rootdisk-<版>.img を作る（U-Boot + ディスク上の rootfs 用）
├── make-tfa.sh           TF-A をビルドし、U-Boot と連結した qemu_fw.bios を作る
├── debug-<版>.gdb        run-direct-debug-<版>.sh 用の gdb スクリプト
├── dump-dtb.sh           QEMU virt のデバイスツリーを virt.dtb / virt.dts に書き出す
├── virt.dts              ↑ の出力（読む用）
├── configs/              .config（linux-<版> / u-boot-v2024.01 / busybox-1.32）
├── boot/
│   ├── boot.cmd          U-Boot ブートスクリプト（initramfs 版）
│   ├── boot-rootdisk.cmd U-Boot ブートスクリプト（/dev/vda2 をルートにする版）
│   ├── initramfs-init    initramfs の /init（busybox/_install/init にコピーする）
│   └── rootfs-etc/       rootdisk の /etc（inittab, init.d/rcS）
├── logs/                 実行ログ（git 管理外）
│   └── qemu/             QEMU の -D 出力（guest_errors）
│
│  ── 以下はセットアップで用意する（git 管理外）──
├── linux-5.4.83/ linux-6.18.53/ linux-7.2.7/
├── u-boot/
├── tf-a/
└── busybox/
```

## セットアップ

以下はすべてリポジトリのトップ（このファイルがある場所）で作業する。

### 1. パッケージ

```sh
sudo apt install \
    build-essential gcc-aarch64-linux-gnu \
    flex bison bc libssl-dev libelf-dev libncurses-dev \
    libgnutls28-dev uuid-dev python3-setuptools swig \
    qemu-system-arm gdb-multiarch \
    cpio e2fsprogs fdisk git wget
```

### 2. Linux カーネル

3 つの版とも手順は同じ。設定は `defconfig` のままで、virtio-blk・ext4・devtmpfs・デバッグ情報が入っている。

```sh
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.4.83.tar.xz
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.18.53.tar.xz
wget https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.2.7.tar.xz
tar xf linux-5.4.83.tar.xz
tar xf linux-6.18.53.tar.xz
tar xf linux-7.2.7.tar.xz
```

それぞれのディレクトリ（`linux-5.4.83/` など）に入って、次の 4 つを実行する。

```sh
export ARCH="arm64"
export CROSS_COMPILE="aarch64-linux-gnu-"
make defconfig
make -j `getconf _NPROCESSORS_ONLN` Image dtbs modules
```

`make defconfig` を実行してできた `.config` を `configs/linux-<版>.config` に保存している。同じ設定でビルドし直すときは、`make defconfig` の代わりに次を実行する。

```sh
cp ../configs/linux-7.2.7.config .config
make olddefconfig
```

設定を変えたら、`.config` を `configs/` にコピーし直してコミットする。

使うファイル:
- `linux-<版>/arch/arm64/boot/Image`: QEMU / U-Boot に渡すカーネル
- `linux-<版>/vmlinux`: gdb のシンボル
- `linux-5.4.83/scripts/dtc/dtc`: `dump-dtb.sh` で使う

### 3. U-Boot

```sh
git clone https://source.denx.de/u-boot/u-boot.git   # 旧 URL: git://git.denx.de/u-boot.git
cd u-boot
git checkout v2024.01
make CROSS_COMPILE=aarch64-linux-gnu- qemu_arm64_defconfig
make CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)
cd ..
```

できた `.config` は `configs/u-boot-v2024.01.config` に保存している（`qemu_arm64_defconfig` のまま）。

使うファイル:
- `u-boot/u-boot.bin`: QEMU の `-bios` に渡す
- `u-boot/tools/mkimage`: `boot/*.cmd` を `boot.scr` に変換する（`make-*.sh` が使う）

### 4. BusyBox と initramfs

```sh
git clone https://git.busybox.net/busybox
cd busybox
git checkout origin/1_32_stable
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
make defconfig
make menuconfig
```

menuconfig で次の 2 つを変える。

- `Settings` → `Build static binary (no shared libs)` を **有効**（`CONFIG_STATIC=y`）
- `Networking Utilities` → `tc` を **無効**（新しいカーネルヘッダーではビルドが通らない）

変更後の `.config` は `configs/busybox-1.32.config` に保存している。menuconfig の代わりに `cp ../configs/busybox-1.32.config .config` としてもよい。

```sh
make -j$(nproc)
make install          # _install/ にルートファイルシステムができる
```

`_install/` に initramfs 用のファイルを足す。

```sh
cd _install
mkdir -p proc sys dev
sudo mknod -m 600 dev/console c 5 1
sudo mknod -m 644 dev/null    c 1 3

cp ../../boot/initramfs-init init
chmod +x init

find . | cpio -o -H newc > ../rootfs.img
cd ../..
```

`busybox/rootfs.img` が initramfs になる。`_install/` を書き換えたら、`find ... | cpio ...` を実行し直す。

### 5. TF-A（TF-A 経由の起動を使う場合）

```sh
git clone --depth 1 --branch v2.15.0 https://review.trustedfirmware.org/TF-A/trusted-firmware-a tf-a
./make-tfa.sh
```

`make-tfa.sh` の中身は次のとおり。BL33（EL3 を抜けたあとに動くプログラム）として U-Boot を FIP に入れる。

```sh
make -C tf-a CROSS_COMPILE=aarch64-linux-gnu- PLAT=qemu DEBUG=1 \
    BL33=$(realpath u-boot/u-boot.bin) all fip
```

`tf-a/build/qemu/debug/qemu_fw.bios`（`bl1.bin` の後ろに `fip.bin` を連結したもの）ができ、これを QEMU の `-bios` に渡す。U-Boot を作り直したら `./make-tfa.sh` も実行し直す。

### 6. ディスクイメージ（U-Boot のディスク起動を使う場合）

```sh
for v in 5.4 6.18 7.2; do
    ./make-bootdisk.sh $v    # → bootdisk-<版>.img
    ./make-rootdisk.sh $v    # → rootdisk-<版>.img
done
```

root 権限は不要（`mkfs.ext4 -d` でディレクトリの中身を直接書き込む）。カーネルや `rootfs.img` を作り直したら、こちらも作り直す。rootdisk を作り直すと、ゲストの中で書いたファイルは消える。

## 起動方法

どのスクリプトも `<版>` は `5.4` / `6.18` / `7.2`。

| スクリプト | 流れ | ルートファイルシステム |
|---|---|---|
| `run-direct-<版>.sh` | QEMU → カーネル | initramfs（`rootfs.img`） |
| `run-uboot-qfw-<版>.sh` | QEMU → U-Boot → fw_cfg 経由でカーネル | initramfs |
| `run-uboot-initrd-disk-<版>.sh` | QEMU → U-Boot → `bootdisk` の `boot.scr` → カーネル | initramfs（ディスクから読み込む） |
| `run-uboot-rootdisk-<版>.sh` | QEMU → U-Boot → `rootdisk` p1 の `boot.scr` → カーネル | `/dev/vda2`（ext4）、busybox init |
| `run-tfa-uboot-rootdisk-<版>.sh` | QEMU → TF-A（BL1 → BL2 → BL31）→ U-Boot → `rootdisk` の `boot.scr` → カーネル | `/dev/vda2`（ext4）、busybox init |
| `run-direct-debug-<版>.sh` | `run-direct` と同じ。CPU を止めて gdb を待つ | initramfs |

- 終了: ゲストのシェルで `poweroff`（QEMU ごと止めるなら `Ctrl-a x`）
- rootdisk 版はシェルを `exit` しても立ち上がり直す（inittab の `respawn`）
- TF-A 版の違い
  - `-M virt,secure=on,virtualization=on` で EL3 と EL2 を有効にする。U-Boot と Linux は EL2 で動く（ほかの起動方法は EL1。dmesg の `CPU: All CPU(s) started at EL2` で分かる）
  - PSCI（CPU の起動・`poweroff` など）には QEMU ではなく TF-A の BL31 が応える。`poweroff` すると BL31 が `PSCI Power Domain Map` を表示してから止まる
  - `-m 1024` が必要。BL2 が U-Boot を `0x60000000` に置くため、既定の 128MB では足りない
  - 起動時の `cortex_a53: CPU workaround for erratum ... was missing!` は、実機向けの CPU の不具合対策を有効にしていないという警告。QEMU では影響しない
- disk 系のスクリプトには `-kernel` / `-initrd` を渡していない。渡すと U-Boot は fw_cfg 経由の起動を先に選ぶため

### ログ

各スクリプトは実行のたびに次のファイルを上書きする。

- `logs/boot-<起動方法>-<版>.log`: コンソール出力
- `logs/qemu/qemu-<起動方法>-<版>.log`: QEMU の `-d guest_errors` の出力

## gdb でカーネルを追う

```sh
# 端末 1
./run-direct-debug-7.2.sh

# 端末 2
gdb-multiarch -x debug-7.2.gdb
```

- QEMU は `-s -S` で起動し、CPU を止めたまま TCP 1234 番で待つ
- `nokaslr` を付けて、`vmlinux` のシンボルと実行時のアドレスを一致させている
- `debug-<版>.gdb` は次の順にハードウェアブレークポイントを置く
  1. カーネルの入口（MMU オフ、物理アドレス。5.4 は `0x40080000`、6.18 / 7.2 は `0x40200000`）
  2. `__primary_switched`（MMU オン直後）
  3. `start_kernel`
  4. initramfs の展開（5.4 は `populate_rootfs`、6.18 / 7.2 は `do_populate_rootfs`）
  5. `run_init_process`（`/init` の起動）

## デバイスツリーを見る

```sh
./dump-dtb.sh     # → virt.dtb / virt.dts
```

QEMU の `virt` マシンが生成するデバイスツリーを書き出す。

## ライセンス

このリポジトリのスクリプトと設定ファイルは [MIT License](LICENSE)。
セットアップで取得する Linux・U-Boot・BusyBox は含まれておらず、それぞれのライセンス（GPL-2.0 など）に従う。
