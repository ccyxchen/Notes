## 下载最新的busybox源码
`git clone git://busybox.net/busybox.git`

## 编译，安装最新根文件系统
1、make menuconfig指定要使用的交叉编译工具
2、make 
3、make CONFIG_PREFIX=~/workspace/nfs_root/busy_1.21/ install 

## 构建根文件系统
```Shell
# 查看依赖的库
arm-none-linux-gnueabihf-readelf -a bin/busybox | grep "Shared"

# 制作系统库
mkdir lib
mkdir usr/lib -p
cp /home/cyx/workspace/Tools/arm-linux-gcc-4.3.2/arm-none-linux-gnueabi/libc/armv4t/lib/*so* lib/ -d
cp /home/cyx/workspace/Tools/arm-linux-gcc-4.3.2/arm-none-linux-gnueabi/libc/armv4t/lib/*so* usr/lib/ -d

# 配置开机启动项，设置第一个应用程序，开机启动项，控制台，挂载文件系统，设置mdev
cp ../third_fs/etc/ . -r

# 创建开机需要的设备节点
mkdir dev
cd dev
sudo mknod console c 5 1
sudo mknod null c 1 3

# 创建系统需要的其他目录
mkdir proc mnt tmp sys root

# 生成jffs2映像
mkfs.jffs2 -n -s 2048 -e 128KiB -d busybox_1.21/ -o busybox_1.21.jffs2
```

## 使用nfs烧录根文件系统（以jffs2为例）
```Shell
nfs 0x32000000 192.168.10.10:/home/cyx/workspace/nfs_root/busybox_1.34.1.jffs2
nand erase 260000 0xbb71d0
nand write.jffs2 32000000 260000 0xbb71d0
```