# WSL 构建f2fs文件系统

## WSL 编译内核和f2fs内核模块

微软官方有维护其内核，从WSL 读取到的内核镜像信息如下：

```Shell
chenyx@BabyDog:~$ uname -r
5.15.74.2-microsoft-standard-WSL2+
```

WSL官方代码仓库路径：<https://github.com/microsoft/WSL2-Linux-Kernel>

为了得到最好的兼容性，这里直接克隆该代码仓构建新内核。

安装环境依赖：
`$ sudo apt install build-essential flex bison dwarves libssl-dev libelf-dev`

官方的编译命令为`make KCONFIG_CONFIG=Microsoft/config-wsl`,为了自定义config配置，这里选择一个新方法，具体如下：

```Shell
~$ cp Microsoft/config-wsl arch/x86/configs/wsl_x86_64_defconfig
~$ make wsl_x86_64_defconfig
~$ make menuconfig
~$ make -j32
~$ make modules -j32
~$ make install
~$ make modules_install
~$ cp arch/x86/boot/bzImage /mnt/c/Users/Chenyx/Documents
```

config按如下配置：

![f2fs config 配置选项](/tmpimage/20221120220323.png)  

这里把f2fs编译为模块，并打开压缩特性支持。最后把生成的模块ko文件安装到系统中，并将生成的内核镜像拷贝到C盘。

## 在Windows中使用新内核启动WSL

编辑.wslconfig文件，其中添加`kernel=C:\\Users\\Chenyx\\Documents\\bzImage`。

执行`wsl --shutdown`关闭WSL，再重新打开，这时已经使用新的内核镜像启动了。

## WSL生成并挂载f2fs镜像

WSL中加载LZ4和f2fs模块，使系统支持F2FS文件系统。

```Shell
# 因为f2fs依赖LZ4压缩，需要先加载LZ4内核模块
sudo insmod /lib/modules/5.15.74.2-microsoft-standard-WSL2+/kernel/lib/lz4/lz4_compress.ko
sudo insmod /lib/modules/5.15.74.2-microsoft-standard-WSL2+/kernel/lib/lz4/lz4hc_compress.ko
sudo insmod /lib/modules/5.15.74.2-microsoft-standard-WSL2+/kernel/fs/f2fs/f2fs.ko
```

生成一个8G的文件并映射为loop设备，然后格式化为f2fs，最后挂载到本地路径。

```Shell
~$ dd if=/dev/zero of=f2fs_test.img bs=4K count=2000000
# 映射成loop设备
sudo losetup /dev/loop1 /home/chenyx/f2fs_test.img
# 生成f2fs分区
sudo mkfs.f2fs -l f2fs /dev/loop1
# 挂载f2fs分区
sudo mount -t f2fs /dev/loop1 /home/chenyx/f2fs_mount
```

可以看到已经成功挂载，并且可以正常写入：

![挂载成功](/tmpimage/20221120222914.png)  

![写入4G内容](/tmpimage/20221120223058.png)
