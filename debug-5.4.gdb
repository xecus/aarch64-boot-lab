# gdb-multiarch -x debug-5.4.gdb で読み込む（run-direct-debug-5.4.sh 用）
file ./linux-5.4.83/vmlinux
set architecture aarch64
target remote :1234

# 1. カーネルの入口（MMU オフ・物理アドレス）
#    5.4 は text_offset=0x80000 なので 0x40080000
hbreak *0x40080000

# 2. MMU オン直後（ここから仮想アドレス 0xffff8000...）
hbreak __primary_switched

# 3. C 言語の処理の始まり
hbreak start_kernel

# 4. initramfs（rootfs.img の cpio）の展開
hbreak populate_rootfs

# 5. /init の起動
hbreak run_init_process

continue
