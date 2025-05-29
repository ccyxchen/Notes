# 各平台使用gdb和crash解析dump

## 高通平台

### 解析ramdump

#### 使用平台工具linux-ramdump-parser-v2

##### 获取linux-ramdump-parser-v2工具

工具位于源代码根目录下的 `vendor/vendor/qcom/opensource/tools/linux-ramdump-parser-v2/`,各平台的参数文件位于`vendor/vendor/qcom/proprietary/ramdump-parser/`,需要把参数文件拷贝到工具目录下的extensions目录下。

```Shell
cp -r vendor/vendor/qcom/proprietary/ramdump-parser/*
vendor/vendor/qcom/opensource/tools/linux-ramdump-parser-v2/extensions
```

##### 安装依赖软件

需要安装python3,以及相关模块

```Shell
sudo apt-get install python3
sudo apt-get install python3-pip
pip3 install psutil
pip3 install pyelftools
```

安装 gdb,dtc,nm,objdump

```Shell
sudo apt install gdb-multiarch
sudo apt install dtc
sudo apt install gcc-aarch64-linux-gnu
sudo apt install gcc-arm-linux-gnueabihf
sudo apt install device-tree-compiler
```

1. 设置local_setting.py,指定gdb,nm,objdump,dtc工具的路径
在工具目录下新建local_setting.py文件，内容如下

```python
import parser_util,os,sys

if parser_util.get_system_type() == 'Linux':
    nm_path = "/usr/bin/arm-linux-gnueabihf--nm"
    gdb_path = "/usr/bin/gdb-multiarch"
    objdump_path = "/usr/bin/arm-linux-gnueabihf-objdump"
    nm64_path = "/usr/bin/aarch64-linux-gnu-nm"
    gdb64_path = "/usr/bin/gdb-multiarch"
    objdump64_path = "/usr/bin/aarch64-linux-gnu-objdump"
    dtc_path = "/usr/bin/dtc"
else:
    nm_path = "D:\Direct\bin\gcc-arm-10.3-2021.07-mingw-w64-i686-arm-none-linux-gnueabihf\bin\arm-none-linux-gnueabihf-nm.exe"
    gdb_path = "D:\Direct\bin\gcc-arm-10.3-2021.07-mingw-w64-i686-arm-none-linux-gnueabihf\bin\arm-none-linux-gnueabihf-gdb.exe"
    objdump_path = "D:\Direct\bin\gcc-arm-10.3-2021.07-mingw-w64-i686-arm-none-linux-gnueabihf\bin\arm-none-linux-gnueabihf-objdump.exe"
    nm64_path = "D:\\Direct\\bin\\gcc-arm-10.3-2021.07-mingw-w64-i686-aarch64-none-linux-gnu\\bin\\aarch64-none-linux-gnu-nm.exe"
    gdb64_path = "D:\\Program Files\\msys64\\mingw64\\bin\\gdb-multiarch.exe"
    objdump64_path = "D:\\Direct\\bin\\gcc-arm-10.3-2021.07-mingw-w64-i686-aarch64-none-linux-gnu\\bin\\aarch64-none-linux-gnu-objdump.exe"
```

从`linux-ramdump-parser-v2/extensions/board_def.py` 文件查找对应的平台，其中 elf.board_num 就是平台名字

```python
class BoardBengal(Board):
    def __init__(self, socid):
        super(BoardBengal, self).__init__()
        self.socid = socid
        self.board_num = "bengal"
        self.cpu = 'CORTEXA53'
        self.ram_start = 0x40000000
        self.smem_addr = 0x6000000
        self.smem_addr_buildinfo = 0x6007210
        self.phys_offset = 0x40000000
        self.imem_start = 0x0c100000
        self.kaslr_addr = 0x0c1256d0
        self.wdog_addr = 0x0c125658
        self.imem_file_name = 'OCIMEM.BIN'
```

使用QPST工具抓到dump文件，使用如下命令解析,其中--force-hardware 是上面elf.board_num的值

```Shell
python3 tools/linux-ramdump-parser-v2/ramparse.py -a log/Port_COM10/ -v samba/workspace/T602AA/vendor/kernel_platform/out/msm-kernel-bengal-consoli
date/dist/vmlinux -o out --force-hardware bengal --dmesg -x
```

#### 使用 crash 命令

下载和编译crash

```Shell
git clone https://github.com/google/crash.git

#编译 aarch64 
make target=ARM64

#编译 arm 
make target=ARM
```

使用crash命令解析dump

```Shell
crash_arm64 ../../vmlinux DDRCS0_0.BIN@0x40000000,DDRCS0_1.BIN@0xc0000000,DDRCS1_0.BIN@0x140000000,DDRCS1_1.BIN@0x1c0000000 --kaslr=0x230a800000  --no_data_debug --machdep vabits_actual=39 -m tag_ignore

# 参数解析：
#其中0x40000000/0xc0000000这些是dump文件的物理地址偏移值，可以从 dump 文件 dump_info.txt中查看，如

   1 0x0000000040000000 0000002147483648   DDR CS0 part0 Memo         DDRCS0_0.BIN
   1 0x00000000c0000000 0000002147483648   DDR CS0 part1 Memo         DDRCS0_1.BIN
   1 0x0000000140000000 0000002147483648   DDR CS1 part0 Memo         DDRCS1_0.BIN
   1 0x00000001c0000000 0000002147483648   DDR CS1 part1 Memo         DDRCS1_1.BIN

#如果kernel中使能了kaslr 特性，需要使用--kaslr参数设置 KASLR offset,这个在每个版本中都会不同，
#可以从dump 文件"OCIMEM.bin" 查看，使用如下命令。

hexdump  -e '16/4 "%08x " "\n"' -s 0x0256d4 -n 8 OCIMEM.BIN

#返回：0a800000 00000023

#最终的KASLR offset为0x230a800000，其中命令中0x0256d4这个值可以从
#linux-ramdump-parser-v2/extensions/board_def.py文件查看对应平台的如下值：
        self.imem_start = 0x0c100000
        self.kaslr_addr = 0x0c1256d0

#该值为self.kaslr_addr-self.imem_start+0x4=0x0256d4

```

### 加载 KO

crash工具分析wlan ko文件
由于wlan驱动是以ko形式添加到系统中，所以还需要在crash命令行手动加载wlan.ko
根据第二步进入crash交互后，输入wlan.ko文件的路径

`crash> mod -s wlan  /home/xxx/disk/main/test/log/0708/wifi/debug/wlan/qca_cld3_wlan.ko.unstripped`
