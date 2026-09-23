# U-Boot ブートスクリプト（make-bootdisk.sh が mkimage で boot.scr に変換する）
# U-Boot の bootflow がディスク上の boot.scr を見つけると、
# devtype / devnum / distro_bootpart / prefix を設定してからこれを実行する。
echo "== boot.scr: ${devtype} ${devnum}:${distro_bootpart} から起動します =="

setenv bootargs "console=ttyAMA0"

load ${devtype} ${devnum}:${distro_bootpart} ${kernel_addr_r} ${prefix}Image
load ${devtype} ${devnum}:${distro_bootpart} ${ramdisk_addr_r} ${prefix}rootfs.img
setenv initrd_size ${filesize}

booti ${kernel_addr_r} ${ramdisk_addr_r}:${initrd_size} ${fdtcontroladdr}
