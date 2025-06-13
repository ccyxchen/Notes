# 使用tinycore搭建qemu的Linux系统

## tinycore的使用

### 从tinycore的img文件提取出rootfs文件

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
sudo mount /dev/loop0p2 /mnt/piCore-linux

# 从piCore-fat中复制出rootfs-piCore64-15.0.gz，并将rootfs-piCore64-15.0.gz解压到rootfs
cp picoreimg/boot/rootfs-piCore64-15.0.gz .
mkdir rootfs
cd rootfs
sudo zcat ../rootfs-piCore64-15.0.gz | sudo cpio -idv

# 生成rootfs.img
dd if=/dev/zero of=rootfs.img bs=3G count=1
mkfs.ext4 rootfs.img

# 挂载rootfs.img,并将rootfs复制到rootfs.img
sudo mkdir -p /mnt/tmp_mount
sudo mount -o loop rootfs.img /mnt/tmp_mount
sudo cp -r rootfs/* /mnt/tmp_mount
sudo umount /mnt/tmp_mount

# 将rootfs制作为initrd镜像
cd rootfs
find . | cpio -o -H newc | gzip > /mnt/rootfs/rootfs-piCore64-15.0.gz
```

### 从iso提取rootfs

```Shell
# 解压iso文件
7z x TinyCorePure64-15.0.iso -oiso_base
mkdir rootfs
cd rootfs
sudo zcat ../iso_base/boot/corepure64.gz | sudo cpio -idv
```

## qemu的使用

### 基本命令

qemu-system-x86_64.exe -cdrom path/to/your/image.iso -m 2048 -cpu host -smp 2
参数解释

* -cdrom path/to/your/image.iso：指定要使用的 .iso 镜像文件，需要将 path/to/your/image.iso 替换为实际 .iso 镜像文件的路径。
* -m 2048：为虚拟机分配 2048MB（即 2GB）的内存。你可以根据实际需求调整内存大小，例如 -m 4096 表示分配 4GB 内存。
* -cpu host：让虚拟机使用宿主机的 CPU 特性，这样可以提高虚拟机的性能。
* -smp 2：设置虚拟机使用 2 个虚拟 CPU 核心。你可以根据宿主机的 CPU 核心数量和实际需求调整该参数，例如 -smp 4 表示使用 4 个虚拟 CPU 核心。
* -nographic 默认情况下，QEMU 会打开一个窗口来显示虚拟机的图形界面。如果想要禁用图形界面，使用该参数。
* -serial mon:stdio 将串口输出重定向到标准输入输出，方便在命令行查看信息.
* -kernel bzImage 使用自编的内核
* -append "root=/dev/sda rw console=ttyS0" 指定内核引导参数
* -serial chardev:serial0 -chardev pty,id=serial0 使用伪终端

### 使用虚拟硬盘

* 可创建一个虚拟硬盘用于存储数据，使用 -hda 参数指定虚拟硬盘文件
    `qemu-system-x86_64.exe -cdrom path/to/your/image.iso -hda path/to/your/virtual_disk.img -m 2048 -cpu host -smp 2`
* 你可以使用 qemu-img 工具预先创建指定大小和格式的虚拟硬盘，例如创建一个 20GB 的 qcow2 格式虚拟硬盘：
    `qemu-img create -f qcow2 path/to/your/virtual_disk.img 20G`

### 使用网络

qemu-system-x86_64.exe -cdrom path/to/your/image.iso -hda path/to/your/virtual_disk.img -m 2048 -cpu host -smp 2 -net user -net nic

* -net user：启用 QEMU 的用户模式网络。
* -net nic：创建一个虚拟网络接口卡（NIC）。

## qemu中运行 linux x86_64

### 编译Linux内核

```Shell
cd ~/work_open/opensource/linux_stable/linux
cp ../../tinycore/x86_64/release/src/kernel/config-6.6.8-tinycore64 .config
make menuconfig
make -j32
make modules
# 安装 模块
sudo make modules_install INSTALL_MOD_PATH=/mnt/tmp_mount 
```

### 搭建桥接网卡

```Shell
#默认已经创建 虚拟网桥virbr0，还需要创建tap 设备

brctl show
sudo ip tuntap add dev tap0 mode tap
sudo ifconfig tap0 up
sudo brctl addif virbr0 tap0
sudo systemctl restart NetworkManager.service

# qemu命令
sudo qemu-system-x86_64 -kernel boot/vmlinuz64 -append "root=/dev/sda rw rootfstype=ext4 console=ttyS0" -drive file=rootfs.img,format=raw -serial mon:stdio -net nic  -net tap,ifname=tap0
```

### 系统中的设置

* 安装openssh
  `tce-load -wi openssh.tcz`
* 启动openssh

```Shell
  sudo touch /usr/local/etc/ssh/sshd_config
  sudo /usr/local/etc/init.d/openssh start
  # 开机启动
  /opt/bootlocal.sh增加/usr/local/etc/init.d/openssh start

  mkdir /tce
  mkdir /tce/optional
  将.tcz 加入/tce/optional
  将.tcz名加入/tce/onboot.lst文件

  # 上传ssh公钥
  主机端：
  cat ~/.ssh/id_rsa.pub
  qemu端：
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh
  vi ~/.ssh/authorized_keys
```

* 使磁盘中某个路径重启后保留修改
`/etc/sysconfig/backup_devices  增加 sda/tce \n sda/`
* 设置串口终端
/etc/inittab增加 `tty2::respawn:/sbin/getty 921600 ttyS0`
* 使用 cgroup

```Shell
sudo mount -t cgroup2 none /sys/fs/cgroup/
sudo mount -t cgroup -o blkio none /dev/blkio/
```

开机挂载
/etc/fstab
none            /sys/fs/cgroup/ cgroup2 rw,nosuid,nodev,noexec,relatime 0 0
none            /sys/kernel/debug/	debugfs	defaults 0 0
none            /sys/kernel/tracing/ tracefs  defaults 0 0
none            /dev/blkio cgroup defaults,blkio 0 0

* 设置 DHCP
/etc/resolv.conf增加nameserver 192.168.122.1

### 使用kgdb

 append 中添加`kgdboc=ttyS0,115200 kgdbwait`

ubuntu运行 gdb

```Shell
gdb vmlinux
target remote /dev/pts/4
```

最终的命令
`sudo qemu-system-x86_64  -M pc -smp 4  -m 4096 -kernel /home/cyx/work_open/opensource/linux_stable/linux/arch/x86/boot/bzImage -append "root=/dev/sda rw rootfstype=ext4 console=ttyS0,921600n8 loglevel=7 tce=sda home=sda opt=sda" -drive file=/home/cyx/work_open/opensource/tinycore/x86_64/myimg/rootfs.img,format=raw -device virtio-blk-pci,drive=ufs_disk  -drive if=none,id=ufs_disk,file=/home/cyx/work_open/opensource/tinycore/x86_64/myimg/disk_f2fs.img,format=raw -serial chardev:serial0 -chardev pty,id=serial0 -net nic -net tap,ifname=tap0 -nographic`

## qemu中运行 linux aarch64

### 交叉编译内核

```Shell
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
cp ../tinycore/aarch64/tinycorelinux.net/15.x/aarch64/releases/RPi/src/kernel/6.6.34-piCore-v8_.config .config
make menuconfig
make -j32
make modules
sudo make modules_install INSTALL_MOD_PATH=/mnt/tmp_mount 
```

aarch64 运行的命令：
sudo qemu-system-aarch64 -M virt   -cpu cortex-a57  -smp 4  -m 2048 -kernel /home/cyx/workspace/opensource/linux_6.6.34/arch/arm64/boot/Image -initrd initramfs.cpio.gz -append "console=ttyAMA0  root=/dev/vda rw rootfstype=ext4  loglevel=7 "  -drive file=./rootfs.img,if=virtio,format=raw  -net nic  -net tap,ifname=tap0     -serial chardev:serial0 -chardev pty,id=serial0 -nographic

### aarch64 中挂载根目录

Linux 的 Virtio 驱动并不一定依赖于 PCI，虽然 PCI 是 Virtio 驱动常见的一种传输机制，但 Virtio 本身支持多种传输方式。下面为你详细介绍：

* Virtio 概述
Virtio 是一种用于虚拟化环境的半虚拟化 I/O 标准，旨在为虚拟机提供高效、灵活的 I/O 设备模拟。它定义了一套通用的接口和协议，使得虚拟机可以与宿主机进行高效的 I/O 交互。Virtio 主要由两部分组成：Virtio 设备（在虚拟机中）和 Virtio 后端（在宿主机中）。

1. 基于 PCI 的 Virtio 驱动
    • 原理：基于 PCI 的 Virtio 驱动是最常见的实现方式之一。在这种模式下，Virtio 设备通过 PCI 总线与宿主机进行通信。虚拟机将 Virtio 设备视为普通的 PCI 设备，通过 PCI 配置空间和 I/O 端口与设备进行交互。宿主机则通过 PCI 总线模拟 Virtio 设备的行为，实现与虚拟机的通信。
    • 示例：在 QEMU 虚拟化环境中，可以使用 -device virtio-blk-pci 参数来添加一个基于 PCI 的 Virtio 块设备。在 Linux 内核中，virtio_pci 模块提供了对基于 PCI 的 Virtio 设备的支持。
2. 非 PCI 的 Virtio 驱动
    • Virtio-MMIO：
        ○ 原理：Virtio-MMIO 是另一种常见的 Virtio 传输方式，它通过内存映射 I/O（MMIO）来实现虚拟机与宿主机之间的通信。在这种模式下，Virtio 设备的配置空间和数据缓冲区被映射到虚拟机的内存空间中，虚拟机可以直接通过内存访问来与设备进行交互。
        ○ 优点：相比于基于 PCI 的 Virtio 驱动，Virtio-MMIO 更加轻量级，不需要复杂的 PCI 总线配置，因此在一些资源受限的环境中（如嵌入式系统）更为适用。
        ○ 示例：在一些 ARM 架构的虚拟化环境中，经常使用 Virtio-MMIO 来实现 Virtio 设备的模拟。在 Linux 内核中，virtio_mmio 模块提供了对 Virtio-MMIO 设备的支持。
    • Virtio over VirtioFS：VirtioFS 是一种用于在虚拟机和宿主机之间共享文件系统的 Virtio 协议。它通过 Virtio 接口实现文件系统的共享，不依赖于 PCI 总线。这种方式可以实现高效的文件共享，并且可以在不同的虚拟化平台上使用。
3. 基于 SCSI 的 Virtio 驱动
    • 原理：基于 SCSI 的 Virtio 驱动是最常见的实现方式之一。在这种模式下，Virtio 设备通过 SCSI 总线与宿主机进行通信。虚拟机将 Virtio 设备视为普通的 SCSI 设备，通过 SCSI 配置空间和 I/O 端口与设备进行交互。宿主机则通过 SCSI 总线模拟 Virtio 设备的行为，实现与虚拟机的通信。

#### 具体实现

通过 virtio-blk 实现块设备

* 在根文件系统中创建 dev 块设备文件
  `sudo mknod /dev/vda b 254 0`

内核中的配置
相关配置项
CONFIG_VIRTIO

Device Drivers
  ->Block devices
    ->Virtio block driver

##### 通过MMIO方式

 配置项
Location:                                                                                                               │
  │     -> Device Drivers                                                                                                     │
  │       -> Virtio drivers (VIRTIO_MENU [=y])                                                                                │
  │ (1)     -> Platform bus driver for memory mapped virtio devices (VIRTIO_MMIO [=y])

Qemu 启动参数
 -device virtio-blk-device,drive=myhd  -drive id=myhd,file=rootfs.img,if=none,format=raw

##### 通过PCI方式

 配置项
  
Symbol: PCI_HOST_GENERIC [=y]                                                                                             │
  │ Type  : tristate                                                                                                          │
  │ Defined at drivers/pci/controller/Kconfig:126                                                                             │
  │   Prompt: Generic PCI host controller                                                                                     │
  │   Depends on: PCI [=y] && OF [=y]                                                                                         │
  │   Location:                                                                                                               │
  │     -> Device Drivers                                                                                                     │
  │       -> PCI support (PCI [=y])                                                                                           │
  │         -> PCI controller drivers                                                                                         │
  │ (1)       -> Generic PCI host controller (PCI_HOST_GENERIC [=y])                                                          │
  │ Selects: PCI_HOST_COMMON [=y] && IRQ_DOMAIN [=y] 

 Symbol: VIRTIO_PCI [=y]                                                                                                   │
  │ Type  : tristate                                                                                                          │
  │ Defined at drivers/virtio/Kconfig:50                                                                                      │
  │   Prompt: PCI driver for virtio devices                                                                                   │
  │   Depends on: VIRTIO_MENU [=y] && PCI [=y]                                                                                │
  │   Location:                                                                                                               │
  │     -> Device Drivers                                                                                                     │
  │       -> Virtio drivers (VIRTIO_MENU [=y])                                                                                │
  │ (1)     -> PCI driver for virtio devices (VIRTIO_PCI [=y])                                                                │
  │ Selects: VIRTIO_PCI_LIB [=y] && VIRTIO [=y]                                                                               │
  │                                                                                                                           │
  │                                                                                                                           │
  │ Symbol: VIRTIO_PCI_LEGACY [=y]                                                                                            │
  │ Type  : bool                                                                                                              │
  │ Defined at drivers/virtio/Kconfig:63                                                                                      │
  │   Prompt: Support for legacy virtio draft 0.9.X and older devices                                                         │
  │   Depends on: VIRTIO_MENU [=y] && VIRTIO_PCI [=y]                                                                         │
  │   Location:                                                                                                               │
  │     -> Device Drivers                                                                                                     │
  │       -> Virtio drivers (VIRTIO_MENU [=y])                                                                                │
  │         -> PCI driver for virtio devices (VIRTIO_PCI [=y])                                                                │
  │ (2)       -> Support for legacy virtio draft 0.9.X and older devices (VIRTIO_PCI_LEGACY [=y])                             │
  │ Selects: VIRTIO_PCI_LIB_LEGACY [=y]

Qemu 参数
 -device virtio-blk-pci,drive=myhd -drive id=myhd,file=rootfs.img,if=none,format=raw
如果不指定 参数，而是使用  -drive file=./rootfs.img,format=raw  ，也会走pci总线

##### 通过SCSI方式

在x86 架构中  ，默认使用  SCSI的磁盘，不需要额外参数设置

Arm64上的设置
  │ Symbol: SCSI_VIRTIO [=y]                                                                                                  │
  │ Type  : tristate                                                                                                          │
  │ Defined at drivers/scsi/Kconfig:1512                                                                                      │
  │   Prompt: virtio-scsi support                                                                                             │
  │   Depends on: SCSI_LOWLEVEL [=y] && SCSI [=y] && VIRTIO [=y]                                                              │
  │   Location:                                                                                                               │
  │     -> Device Drivers                                                                                                     │
  │       -> SCSI device support                                                                                              │
  │         -> SCSI low-level drivers (SCSI_LOWLEVEL [=y])                                                                    │
  │ (1)       -> virtio-scsi support (SCSI_VIRTIO [=y])

qemu参数设置：
 -device virtio-scsi-device,id=scsi0 -device scsi-hd,drive=hd0 -drive file=rootfs.img,format=raw,if=none,id=hd0

参数解析：
-device virtio-scsi-device,id=scsi0
此选项的作用是在虚拟机里创建一个 Virtio SCSI 控制器设备，并且给该控制器赋予一个唯一的标识符 scsi0。Virtio 是一种用于虚拟化环境的半虚拟化设备模型，而 Virtio SCSI 控制器则是专门用来模拟 SCSI 总线的设备，它能够让虚拟机和外部存储设备进行交互。简单来说，这一步是在虚拟机中搭建了一个用于连接存储设备的 “桥梁”。
-device scsi-hd,drive=hd0
这个选项的功能是在之前创建的 Virtio SCSI 控制器（scsi0）上添加一个 SCSI 硬盘设备。drive=hd0 表示该硬盘设备会关联到一个名为 hd0 的驱动器，而这个驱动器在后续通过 -drive 选项来定义其具体的存储介质（例如一个文件、RAM 磁盘等）。可以理解为，这一步是在前面搭建好的 “桥梁” 上连接了一个具体的 “存储设备”。

##### 最终三种实现的命令

```Shell
# SCSI磁盘：
sudo qemu-system-aarch64 -M virt   -cpu cortex-a57  -smp 4  -m 4096 -kernel /home/cyx/work_open/opensource/linux_6.6.34/arch/arm64/boot/Image -append "console=ttyAMA0  root=/dev/sda rw  loglevel=7 tce=sda home=sda opt=sda"  -net nic  -net tap,ifname=tap0 -serial chardev:serial0 -chardev pty,id=serial0 -nographic  -device virtio-scsi-device,id=scsi0 -device scsi-hd,drive=hd0 -d
rive file=/home/cyx/work_open/opensource/tinycore/aarch64/myimg/rootfs.img,format=raw,if=none,id=hd0

# Virtio PCI:
sudo qemu-system-aarch64 -M virt   -cpu cortex-a57  -smp 4  -m 2048 -kernel /home/cyx/work_open/opensource/linux_6.6.34/arch/arm64/boot/Image -append "console=ttyAMA0  root=/dev/vda  loglevel=7 "  -net nic  -net  tap,ifname=tap0 -serial chardev:serial0 -chardev pty,id=serial0 -nographic   -device virtio-blk-pci,drive=myhd -drive id=myhd,file=rootfs.img,if=none,format=raw
或
sudo qemu-system-aarch64 -M virt   -cpu cortex-a57  -smp 4  -m 2048 -kernel /home/cyx/work_open/opensource/linux_6.6.34/arch/arm64/boot/Image -append "console=ttyAMA0  root=/dev/vda  loglevel=7 "  -net nic  -net  tap,ifname=tap0 -serial chardev:serial0 -chardev pty,id=serial0 -nographic  -drive file=./rootfs.img,format=raw

# Virtio MMIO:
sudo qemu-system-aarch64 -M virt   -cpu cortex-a57  -smp 4  -m 2048 -kernel /home/cyx/work_open/opensource/linux_6.6.34/arch/arm64/boot/Image -append "console=ttyAMA0  root=/dev/vda  loglevel=7 "  -net nic  -net  tap,ifname=tap0 -serial chardev:serial0 -chardev pty,id=serial0 -nographic  -device virtio-blk-device,drive=myhd  -drive id=myhd,file=rootfs.img,if=none,format=raw
```

### 配置 RTC驱动

默认启动时系统会卡住，无法挂载硬盘。
在/etc/init.d/tc-config中设置了RTC的检测，由于内核未加载RTC驱动，/dev/rtc0不存在会卡死在这里。

```Shell
if [ -n "$NORTC" ]; then
        echo "${BLUE}Skipping rtc as requested from the boot command line.${NORMAL}"
else
        while [ ! -e /dev/rtc0 ]; do usleep 50000; done
        if [ -n "$NOUTC" ]; then
                /sbin/hwclock -l -s &
        else
                /sbin/hwclock -u -s &
        fi
fi
```

解决方法是打开内核如下驱动：

1. RTC 核心支持：
  CONFIG_RTC_LIB=y
  CONFIG_RTC_CLASS=y
2. QEMU RTC 驱动（基于 Pl031 芯片）：
  CONFIG_RTC_DRV_PL031=y  # QEMU默认使用的RTC芯片

### 配置网络

打开内核驱动：
CONFIG_VIRTIO_NET=y
