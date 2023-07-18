# 最新的Debian 编译 Android 5.0.2

## 设置交叉编译器

将开发板提供的交叉编译器解压到`/home/chenyx/bin/tools/arm-linux-gcc-4.5.1-v6-vfp-20120301`，然后编辑
`/home/chenyx/bin/build_android_5.0.2.sh`作为环境设置脚本,将交叉编译器加入环境变量

`export PATH=$PATH:/home/chenyx/bin/tools/arm-linux-gcc-4.5.1-v6-vfp-20120301/FriendlyARM/toolschain/4.5.1/bin/`

## 安装编译需要的程序和库

首先打开32位库支持

`sudo dpkg --add-architecture i386`

然后参照官方的安装脚本安装，其中有些库需要作修改，且openjdk7需要手动下载安装

```Shell
# 安装软件
sudo apt-get install \
    git gnupg flex bison gperf build-essential  \
    zip curl libc6-dev libncurses5-dev x11proto-core-dev \
    libx11-dev libreadline6-dev \
    libgl1-mesa-dev libgl1-mesa-glx \
    g++-multilib tofrodos libncurses5-dev \
    python3-markdown libxml2-utils xsltproc zlib1g-dev \
    python lib32z1 libx32z1 zlib1g

# 下载openjdk7
# 参考https://techoral.com/blog/java/install-openjdk-7-debian.html
cd ~/bin
wget https://download.java.net/openjdk/jdk7u75/ri/openjdk-7u75-b13-linux-x64-18_dec_2014.tar.gz
tar -xvf openjdk-7u75-b13-linux-x64-18_dec_2014.tar.gz
```

将openjdk7 加入环境变量

```Shell
export JAVA_HOME=/home/chenyx/bin/java-se-7u75-ri/
export PATH=$JAVA_HOME/bin:$PATH
```

开始编译：

```Shell
source ~/bin/build_android_5.0.2.sh
. setenv
make
```

## 解决编译时遇到的问题

### 1、java版本报错

报错如下：

```Shell
************************************************************
You are attempting to build with the incorrect version
of java.

Your version is: openjdk version "1.7.0_75" OpenJDK Runtime Environment (build 1.7.0_75-b13) OpenJDK 64-Bit Server VM (build 24.75-b04, mixed mode).
The required version is: "1.7.x"
```

在代码中搜索相关报错，手动设置java版本

```Makefile
diff --git a/build/core/main.mk b/build/core/main.mk
index 9d6e233d4c..b957900a2c 100644
--- a/build/core/main.mk
+++ b/build/core/main.mk
@@ -144,8 +144,8 @@ javac_version_str := $(shell unset _JAVA_OPTIONS && javac -version 2>&1)
 ifeq ($(LEGACY_USE_JAVA6),)
 required_version := "1.7.x"
 required_javac_version := "1.7"
-java_version := $(shell echo '$(java_version_str)' | grep '^java .*[ "]1\.7[\. "$$]')
-javac_version := $(shell echo '$(javac_version_str)' | grep '[ "]1\.7[\. "$$]')
+java_version := "1.7.75"  #$(shell echo '$(java_version_str)' | grep '^java .*[ "]1\.7[\. "$$]')
+javac_version := "1.7.75" #$(shell echo '$(javac_version_str)' | grep '[ "]1\.7[\. "$$]')
 else # if LEGACY_USE_JAVA6
 required_version := "1.6.x"
 required_javac_version := "1.6"
```

### 2、终端字符编码错误

默认的终端字符编码设置是`en_US.UTF-8`,显示中文是正常的。编译时报错：

```Shell
flex-2.5.39: loadlocale.c:130: _nl_intern_locale_data: Assertion `cnt < (sizeof (_nl_value_type_LC_TIME) / sizeof (_nl_value_type_LC_TIME[0]))' failed.
```

解决方法是`export LC_ALL=C`,但是这样会导致终端中文显示乱码。

### 3、ld连接器错误

报错`unsupported reloc 43 against global symbol`,网上说是ld版本不匹配导致的

应用网上提供的补丁解决。

```Makefile
# https://android-review.googlesource.com/#/c/223100/

# 本地修改：
diff --git a/build/core/clang/HOST_x86_common.mk b/build/core/clang/HOST_x86_common.mk
index 0241cb6636..77547b79c6 100644
--- a/build/core/clang/HOST_x86_common.mk
+++ b/build/core/clang/HOST_x86_common.mk
@@ -8,6 +8,7 @@ ifeq ($(HOST_OS),linux)
 CLANG_CONFIG_x86_LINUX_HOST_EXTRA_ASFLAGS := \
   --gcc-toolchain=$($(clang_2nd_arch_prefix)HOST_TOOLCHAIN_FOR_CLANG) \
   --sysroot=$($(clang_2nd_arch_prefix)HOST_TOOLCHAIN_FOR_CLANG)/sysroot \
+  -B$($(clang_2nd_arch_prefix)HOST_TOOLCHAIN_FOR_CLANG)/x86_64-linux/bin \
   -no-integrated-as

 CLANG_CONFIG_x86_LINUX_HOST_EXTRA_CFLAGS := \
```

### 4、fatal error: XPathGrammar.hpp: No such file or directory

网上说是bison版本过高，语法发送改变，对bison降级解决问题。
参考`https://geeksww.com/tutorials/miscellaneous/bison_gnu_parser_generator/installation/installing_bison_gnu_parser_generator_ubuntu_linux.php#download_bison`进行安装。

```Shell
cd ~/workspace
wget http://ftp.gnu.org/gnu/bison/bison-3.0.2.tar.gz
tar -xvf bison-3.0.2.tar.gz
cd bison-3.0.2
./configure --prefix=/home/chenyx/bin/bison-3.0.2/
make 
make install
```

### 5、报API错误

完整报错如下：

```Shell
******************************
You have tried to change the API from what has been previously approved.

To make these errors go away, you have two choices:
   1) You can add "@hide" javadoc comments to the methods, etc. listed in the
      errors above.

   2) You can update current.txt by executing the following command:
         make update-api

      To submit the revised current.txt to the main Android repository,
      you will need approval.
******************************
```

虽然执行`make update-api`能解决问题，但是网上已经有修复patch

```Makefile
# https://android.googlesource.com/platform/system/core/+/dd060f01f68ee0e633e9cae24c4e565cda2032bd%5E%21/#F0
diff --git a/system/core/libutils/String8.cpp b/system/core/libutils/String8.cpp
index 9092cbc99a..3323b82a5e 100644
--- a/system/core/libutils/String8.cpp
+++ b/system/core/libutils/String8.cpp
@@ -424,7 +424,7 @@ bool String8::removeAll(const char* other) {
             next = len;
         }

-        memcpy(buf + tail, buf + index + skip, next - index - skip);
+        memmove(buf + tail, buf + index + skip, next - index - skip);
         tail += next - index - skip;
         index = next;
     }
```

## 最终的设置环境变量脚本

```Shell
export PATH=$PATH:/home/chenyx/bin/tools/arm-linux-gcc-4.5.1-v6-vfp-20120301/FriendlyARM/toolschain/4.5.1/bin/
export LANG=C
export JAVA_HOME=/home/chenyx/bin/java-se-7u75-ri/
export PATH=$JAVA_HOME/bin:$PATH
export PATH=/home/chenyx/bin/bison-3.0.2/bin:$PATH
```

## 总结

可见，在高版本系统编译旧的代码版本并不可怕，基本可以通过如下方法解决：

1. 新系统无法安装较旧的工具版本。

    安装最新的工具版本，编译时报错到网上查找，可能已经有人提供patch。如果没有，就下载旧版本的代码编译安装。

2. 编译过程中报其他问题。

    到网上查找，或者自己搜索代码报错点解决。

3. 旧编译器报依赖问题。

    下载较旧的库的源码编译安装，还要指定库路径。
