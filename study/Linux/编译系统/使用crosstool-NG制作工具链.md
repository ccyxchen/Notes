# 制作交叉编译工具链的思路

arm官网上有发布适合arm的最新编译工具链，但是这些工具链一般基于最新的arm架构构建（如最新的gcc 10支持arm  cortex-v7. 而s3c2440使用的是arm4架构，不能使用官网的编译器。我们需要借助crosstool-NG工具基于最新的gcc和glibc编译支持arm4的编译器。crosstool-NG其实是一个makefile 脚本。

## 下载最新的crosstool-NG

git clone <https://github.com/crosstool-ng/crosstool-ng>

## 使用crosstool-NG构建工具链

参考官方文档和博客
<https://crosstool-ng.github.io/docs/>
<https://titanwolf.org/Network/Articles/Article?AID=49efa029-bfb8-4640-9345-80a9ac36826e>

```Shell
mkdir crosstool-build crosstool-install src
sudo apt-get install flex gperf bison  texinfo  gawk libtool automake libncurses5-dev help2man libtool-bin libtool
./bootstrap
./configure --prefix=/home/cyx/workspace/open/crosstool-ng/crosstool-install/
make
make install

export PATH=$PATH:~/workspace/open/crosstool-ng/crosstool-install/bin/
cp -r samples/arm-unknown-linux-gnueabi/ ../crosstool-build/
cd crosstool-build/
ct-ng arm-unknown-linux-gnueabi
ct-ng menuconfig
Paths and misc options  --->
    Local tarballs directory -> /home/cyx/workspace/open/crosstool-ng/src/
    Prefix directory->          /home/cyx/workspace/open/crosstool-ng/x-tools/$ {CT_TARGET}
    Number of parallel jobs ->  4
Target options  --->
    Architecture level->        armv4t
    Emit assembly for CPU ->    arm9tdmi
    (arm920t) Tune for CPU 
Toolchain options  --->
    Tuple's vendor string ->    S3C2440


# installation termcap

cd /tmp  
wget ftp://ftp.gnu.org/gnu/termcap/termcap-1.3.1.tar.gz  
tar xvzf termcap-1.3.1.tar.gz  
cd termcap-1.3.1  
./configure --prefix=/usr  
make  
make install  

cd crosstool-build/
ct-ng build.4
```

编译生成的工具链在/home/cyx/workspace/open/crosstool-ng/x-tools/目录下
