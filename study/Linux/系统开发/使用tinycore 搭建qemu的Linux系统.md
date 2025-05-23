# 使用tinycore搭建qemu的Linux系统

## tinycore的使用

1. 从tinycore的iso文件提取出rootfs文件
下面以tinycore的RPI 64镜像为例
piCore64-15.0.0.zip

```Shell
unzip piCore64-15.0.0.zip
# 得到piCore64-15.0.0.img，这个img是包含2个分区的
$ file piCore64-15.0.0.img
piCore64-15.0.0.img: DOS/MBR boot sector; partition 1 : ID=0xc, start-CHS (0x80,0,1), end-CHS (0x3ff,3,16), startsector 8192, 163840 sectors; partition 2 : ID=0x83, start-CHS (0x3ff,3,16), end-CHS (0x3ff,3,16), startsector 172032, 32768 sectors

# 需要使用losetup挂载到loop设备上
sudo losetup -P /dev/loop0 /path/to/piCore-15.0.0.img
sudo mkdir -p /mnt/piCore-fat
sudo mount /dev/loop0p1 /mnt/piCore-fat
sudo mkdir -p /mnt/piCore-linux
sudo mount -t ext4 /dev/loop0p2 /mnt/piCore-linux

# 从piCore-fat中复制出rootfs-piCore64-15.0.gz
mkdir rootfs
cd rootfs
zcat rootfs-piCore64-15.0.gz | sudo cpio -idv

# 生成rootfs.img
dd if=/dev/zero of=rootfs.img bs=3G count=1
mkfs.ext4 rootfs.img

# 挂载rootfs.img
sudo mkdir -p /mnt/rootfs
sudo mount -o loop rootfs.img /mnt/rootfs

# 将rootfs复制到rootfs.img
cd rootfs
find . | cpio -o -H newc | gzip > /mnt/rootfs/rootfs-piCore64-15.0.gz


```
