# gdb-multiarch -x debug-6.18.gdb で読み込む（run-direct-debug-6.18.sh 用）
file ./linux-6.18.53/vmlinux
set architecture aarch64
target remote :1234

# 1. カーネルの入口（MMU オフ・物理アドレス）
#    5.8 以降は text_offset=0 なので、QEMU は 2MiB 境界の 0x40200000 に置く
hbreak *0x40200000

# 2. MMU オン直後（ここから仮想アドレス 0xffff8000...）
hbreak __primary_switched

# 3. C 言語の処理の始まり
hbreak start_kernel

# 4. initramfs（rootfs.img の cpio）の展開
hbreak do_populate_rootfs

# 5. /init の起動
hbreak run_init_process

continue
