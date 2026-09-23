# U-Boot ブートスクリプト（ディスク上のルートファイルシステム版）
# パーティション 1: boot.scr と Image（このスクリプトが置かれている場所）
# パーティション 2: ルートファイルシステム（busybox）→ カーネルが /dev/vda2 としてマウント
echo "== boot.scr: ${devtype} ${devnum}:${distro_bootpart} から起動します =="

setenv bootargs "console=ttyAMA0 root=/dev/vda2 rw rootwait"

load ${devtype} ${devnum}:${distro_bootpart} ${kernel_addr_r} ${prefix}Image

# initrd なしは "-" を指定する
booti ${kernel_addr_r} - ${fdtcontroladdr}
