# Ubuntu 编译安卓

## 软件安装

### 下载安装 JDK

不同版本的Android源代码对JDK版本的要求也不一样，具体如下。
    ● AOSP master：OpenJDK 8
    ● Android 5.x (Lollipop) ~ Android 6.0 (Marshmallow)：OpenJDK 7
    ● Android 2.3.x (Gingerbread) ~ Android 4.4.x (KitKat)：Java JDK 6
    ● Android 1.5 (Cupcake) ~ Android 2.2.x (Froyo)：Java JDK 5

随着Android源代码版本的迭代，对于Ubuntu版本、JDK及其他依赖包都会发生变化，最新的安装指令可以参考官 方网站：<https://source.android.com/source/initializing>。

Java JDK 5和6的官方网站为：<http://www.oracle.com>。 该网站为Linux提供的JDK有bin和rpm.bin两种包，推荐下载bin包。以JDK 6为例，假设下载文件 为jdk-6u45-linux-x64.bin，保存在~/Downloads目录下，执行以下命令进行安装。

```Shell
USER@MACHINE:~$ sudo cp ~/Downloads/jdk-6u45-linux-x64.bin /usr/java/ 
USER@MACHINE:~$ cd /usr/java 
USER@MACHINE:/usr/java$ chmod a+x ./jdk-6u45-linux-x64.bin 
USER@MACHINE:/usr/java$ ./jdk-6u45-linux-x64.bin 
```

安装完成后，可以通过update-alternatives工具管理JDK，如下所示。

```Shell
sudo update-alternatives –install /usr/bin/java java /usr/java/jdk1.6.0_45/bin/ java 1061 
sudo update-alternatives –install /usr/bin/javac javac /usr/java/jdk1.6.0_45/ bin/java 1061
```

在安装过程中如果提示依赖缺失，则可以执行以下命令进行修复安装。 `USER@MACHINE:~$ sudo apt-get -f install`

### 安装其他依赖

Ubuntu 14.04的依赖包可以执行以下命令进行安装。

`USER@MACHINE:~$ sudo apt-get install git-core gnupg flex bison gperf build-essential \ zip curl zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386 \ lib32ncurses5-dev x11proto-core-dev libx11-dev lib32z-dev ccache \ libgl1-mesa-dev libxml2-utils xsltproc unzip`

## 配置需要的环境

```Shell
# 设置英文编码，某些时候设置了中文字符编码会报错
export LANG=C

# 设置使用jdk1.6.0_45
export JAVA_HOME=/home/chenyx/bin/jdk1.6.0_45
export PATH=$JAVA_HOME/bin:$PATH

# 指定编译库和头文件路径，否则会找不到某些库，头文件而报错
export C_INCLUDE_PATH=/usr/include/x86_64-linux-gnu
export CPLUS_INCLUDE_PATH=/usr/include/x86_64-linux-gnu
export LIBRARY_PATH=/usr/lib/x86_64-linux-gnu

# 编译完安卓后，将Android虚拟机路径加入环境变量，方便运行，ANDROID_PRODUCT_OUT是Android虚拟机查找安卓镜像的路径
export PATH=$PATH:/home/chenyx/workspace/opensource/Android-2.3.1_r1/out/host/linux-x86/bin
export ANDROID_PRODUCT_OUT=/home/chenyx/workspace/opensource/Android-2.3.1_r1/out/target/product/generic
```

## 一些错误修复

### 编译时报Unknown parameter a interfaceName for tags/attrs

这是gcc版本过高导致的报错，最新的ubuntu 14,.04 使用gcc4.8,但编译 Android 2.3.1_r1 需要gcc 4.4版本，使用以下命令安装gcc 4.4:

```Shell
# 安装 gcc4.4
apt-get --install-suggests --yes install gcc-4.4:amd64 gcc-4.4-multilib:amd64 g++-4.4:amd64 g++-4.4-multilib:amd64

# 设置多版本gcc共存，默认使用数字最高的
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.4 80 --slave /usr/bin/g++ g++ /usr/bin/g++-4.4
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.8 40 --slave /usr/bin/g++ g++ /usr/bin/g++-4.8
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.7 60 --slave /usr/bin/g++ g++ /usr/bin/g++-4.7
```

### 报错error: storage size of \'rlim\' isn't known

这是glibc库接口发生变化，需做修改：

```diff
diff --git a/dalvik/vm/native/dalvik_system_Zygote.c b/dalvik/vm/native/dalvik_system_Zygote.c
index bcc2313..a50c45d 100644
--- a/dalvik/vm/native/dalvik_system_Zygote.c
+++ b/dalvik/vm/native/dalvik_system_Zygote.c
@@ -30,6 +30,8 @@
 # include <sys/prctl.h>
 #endif

+#include <sys/resource.h>
+
 #define ZYGOTE_LOG_TAG "Zygote"

 /* must match values in dalvik.system.Zygote */
```

### 报错`Can't locate Switch.pm in @INC (you may need to install the Switch module)`

`sudo apt-get install libswitch-perl`
