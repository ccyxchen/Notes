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

## 最新的交叉编译工具链：gcc-arm-10.2-2020.11-x86_64-arm-none-linux-gnueabihf编译后报错: 0x00000004
    在网上找到问题，是因为arm官方提供的工具链只支持A系列，使用的架构是arm-v7a，其中包含一些新的指令无法在armv4上执行，所以出现非法指令集。

解决方法：
1、自己下载工具链源码重新编译制作适合的工具链
2、使用旧工具链：gcc version 4.3.2 (Sourcery G++ Lite 2008q3-72)编译，在最新内核运行没有任何问题。但是无法编译最新的busybox。