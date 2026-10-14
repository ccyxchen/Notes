# arm-linux cross compiler tool chain made (based S3C2440) [turn]

FaceBook Share

[Write My Article](https://titanwolf.org/writearticle/)

[Report](https://titanwolf.org/Contact)

*widgets* Article

# arm-linux cross compiler tool chain made (based S3C2440) [turn]

This article reprinted from: [http://eric-gao.iteye.com/blog/2160622](http://eric-gao.iteye.com/blog/2160622)

Making arm-linux cross compiler tool chain typically by crosstool tools or crosstool-NG, the former is easy to use, but the production will be subject to some restrictions, use crosstool can compile a maximum of gcc4.1.1, glibc2.x version can not be higher than the compiled version 2.6 .29 linux kernel. crosstool-NG tool is used to create a new cross compiler tool chain, which is crosstool replacement. crosstool-NG better customization, and has maintained updated to support the new version of the compiler tool chain is better, of course, also brought some trouble, it is not downloaded you can use, you must first configure the installation . We are here to make the choice crosstool-NG compiler tool chain.

Use of this system is Ubuntu Kylin (3.13.0-32-generic # 57-Ubuntu SMP Tue Jul 15 03:51:08 UTC 2014 x86_64 x86_64 x86_64 GNU/Linux), recommends that you use Ubuntu system, install the software more convenient.

**A mounting crosstool-NG**

1, the establishment of arm-linux-tools directory and enter the directory

Shell Code

[View Image](http://eric-gao.iteye.com/images/icon_star.png)

- $ mkdir arm-linux-tools
- $ cd arm-linux-tools

2, get crosstool-NG source

Shell Code

[View Image](http://eric-gao.iteye.com/images/icon_star.png)

- $ wget http://crosstool-ng.org/download/crosstool-ng/crosstool-ng-1.20.0.tar.bz2

3, extract the source crosstool-NG

Shell Code

[View Image](http://eric-gao.iteye.com/images/icon_star.png)

- $ tar xvjf crosstool-ng-1.20.0.tar.bz2

Taking into account that will be used to follow the various directories, we are here to build a good follow-up required directory.

Shell Code

[View Image](http://eric-gao.iteye.com/images/icon_star.png)

- $ mkdir crosstool-build crosstool-install src

4, configuration and dependency detected

Shell Code

[View Image](http://eric-gao.iteye.com/images/icon_star.png)

- $ cd crosstool-ng-1.20.0
- $ ./configure --prefix /home/eric/arm-linux-tools/crosstool-install/

Before configuration, make sure the following software is already installed

1) gperf

2) bison

3) flex

4) texinfo

5) gawk

6) libtool

7) automake

8) libncurses5-dev

9) g ++

During configuration, it will be dependent on detection, if there is the phenomenon of missing packages, installed after the re-configuration can be executed.

Automatically creates the Makefile we needed after a successful configuration.

5, compile and install

Shell Code

[View Image](http://eric-gao.iteye.com/images/icon_star.png)

- $ make
- $ make install

6, configure the environment variables

Shell Code

[View Image](http://eric-gao.iteye.com/images/icon_star.png)

- $ export PATH=$PATH:/home/eric/arm-linux-tools/crosstool-install/bin/

7, check whether the installation was successful crosstool-NG

Shell Code

[View Image](http://eric-gao.iteye.com/images/icon_star.png)

- $ ct-ng -v

[View Image](http://dl2.iteye.com/upload/attachment/0103/6543/29f80027-fc06-35be-a0e4-f3246203e763.png)

**Second, the cross compiler tool chain configuration**

There are many good default configuration (located under crosstool-ng-1.20.0/samples directory) in crosstool-NG in here only need to be modified it. Because production is arm-linux cross compiler tool chain, so the choice of arm-unknown-linux-gnueabi configuration.

1. Copy the arm-unknown-linux-gnueabi folder to crosstool-build directory

Shell Code

[View Image](http://eric-gao.iteye.com/images/icon_star.png)

- $ cd samples
- $ cp -r arm-unknown-linux-gnueabi/ ../../crosstool-build/

2, the default configuration files are copied to directory crosstool-build and renamed .config

Shell Code

[View Image](http://eric-gao.iteye.com/images/icon_star.png)

- $ cd ~/arm-linux-tools/crosstool-build
- $ cp arm-unknown-linux-gnueabi/crosstool.config .config

3, execution ct-ng menuconfig configuration interface to configure

Shell Code

[View Image](http://eric-gao.iteye.com/images/icon_star.png)

- $ ct-ng menuconfig

Configuration interface as shown below: 
[View Image](http://dl2.iteye.com/upload/attachment/0103/6545/d0590cfe-bd18-3c25-8b1b-2190c0526b5c.png)

(1) Source Package installation path setting and path cross compiler

1) Source Package path: Paths and Local tarballs directory is provided under misc options is/home/eric/arm-linux-tools/src

2) the installation path cross compiler: Prefix directory is provided under Paths and misc options is/home/eric/arm-linux-tools/x-tools/$ {CT_TARGET}

(2) modify the cross-compiler for the architecture

1) Set Architecture level at Target options is armv4t

2) Set Emit assembly for CPU is under Target options arm9tdmi

Tune for CPU under 3) Target options to set arm920t

This argument is over how to get out of a few, you can refer to the man gcc manual. You can find the file after download gcc-4.9.1.tar.bz2 unzip the folder (gcc-4.9.1/gcc/doc/gcc.1)

Execute the following command to open gcc.1

Shell Code

[View Image](http://eric-gao.iteye.com/images/icon_star.png)

- $ man ./gcc.1

In which you can see the following passage:

Shell Code

[View Image](http://eric-gao.iteye.com/images/icon_star.png)

- ......
- ARM Options
- ......
- -march=name
- This specifies the name of the target ARM architecture. GCC uses
- this name to determine what kind of instructions it can emit when
- generating assembly code. This option can be used in conjunction
- with or instead of the -mcpu= option. Permissible names are:
- armv2, armv2a, armv3, armv3m, armv4, armv4t, armv5, armv5t, armv5e,
- armv5te, armv6, armv6j, armv6t2, armv6z, armv6zk, armv6-m, armv7,
- armv7-a, armv7-r, armv7-m, armv7e-m, armv7ve, armv8-a, armv8-a+crc,
- iwmmxt, iwmmxt2, ep9312.
- -mtune=name
- This option specifies the name of the target ARM processor for
- which GCC should tune the performance of the code. For some ARM
- implementations better performance can be obtained by using this
- option. Permissible names are: arm2, arm250, arm3, arm6, arm60,
- arm600, arm610, arm620, arm7, arm7m, arm7d, arm7dm, arm7di,
- arm7dmi, arm70, arm700, arm700i, arm710, arm710c, arm7100, arm720,
- arm7500, arm7500fe, arm7tdmi, arm7tdmi-s, arm710t, arm720t,
- arm740t, strongarm, strongarm110, strongarm1100, strongarm1110,
- arm8, arm810, arm9, arm9e, arm920, arm920t, arm922t, arm946e-s,
- arm966e-s, arm968e-s, arm926ej-s, arm940t, arm9tdmi, arm10tdmi,
- arm1020t, arm1026ej-s, arm10e, arm1020e, arm1022e, arm1136j-s,
- arm1136jf-s, mpcore, mpcorenovfp, arm1156t2-s, arm1156t2f-s,
- arm1176jz-s, arm1176jzf-s, cortex-a5, cortex-a7, cortex-a8,
- cortex-a9, cortex-a12, cortex-a15, cortex-a53, cortex-a57,
- cortex-r4, cortex-r4f, cortex-r5, cortex-r7, cortex-m4, cortex-m3,
- cortex-m1, cortex-m0, cortex-m0plus, marvell-pj4, xscale, iwmmxt,
- iwmmxt2, ep9312, fa526, fa626, fa606te, fa626te, fmp626, fa726te.
- Additionally, this option can specify that GCC should tune the
- performance of the code for a big.LITTLE system. Permissible names
- are: cortex-a15.cortex-a7, cortex-a57.cortex-a53.
- -mcpu=name
- This specifies the name of the target ARM processor. GCC uses this
- name to derive the name of the target ARM architecture (as if
- specified by -march) and the ARM processor type for which to tune
- for performance (as if specified by -mtune). Where this option is
- used in conjunction with -march or -mtune, those options take
- precedence over the appropriate part of this option.
- Permissible names for this option are the same as those for -mtune.
- -mcpu=generic-arch is also permissible, and is equivalent to
- -march=arch -mtune=generic-arch. See -mtune for more information.
- -mcpu=native causes the compiler to auto-detect the CPU of the
- build computer. At present, this feature is only supported on
- Linux, and not all architectures are recognized. If the auto-
- detect is unsuccessful the option has no effect.
- ......

Architecture level corresponding to -march = name

-mtune = name corresponding to Tune for CPU

-mcpu = name corresponding to Emit assembly for CPU

(3) the number of parallel processes when setting compile

1) Set the Number of Paths and misc options of parallel jobs 4

This value should not be too large, should be twice the number of cores in the CPU.

(4) The compiler prefix provided

1) Set Tuple's vendor string at Toolchain options as S3C2440, thus generated prefix compiler is arm-S3C2440-linux-gnueabi-

4, installation termcap

Shell Code

[View Image](http://eric-gao.iteye.com/images/icon_star.png)

- $ cd /tmp
- $ wget ftp://ftp.gnu.org/gnu/termcap/termcap-1.3.1.tar.gz
- $ tar xvzf termcap-1.3.1.tar.gz
- $ cd termcap-1.3.1
- $ ./configure --prefix=/usr
- $ make
- $ make install

5, compiled

Execute the following command to compile under crosstool-build directory

Shell Code

[View Image](http://eric-gao.iteye.com/images/icon_star.png)

- $ ct-ng build.4

The entire compilation long time, crosstool-ng automatically download the appropriate package and kernel files, and then extract, configure, compile, link, but individual package error occurs during the download automatically, e.g. duma_2_5_15 and expat-2.1.0, these two need to manually download the package into Local tarballs directory specified directory (here/home/eric/arm-linux-tools/src), and then re-execute the compiler can.

The compilation process, the installation of the cross-gdb, appear configure: error: expat is missing or unusable in error, you can install libexpat1-dev.

Compilation process, there g ++: Internal error: Killed (program cc1plus) error, try to increase available memory.

As shown below represents the installation was successful.

[View Image](http://dl2.iteye.com/upload/attachment/0103/6551/5c36b307-31f4-32a1-bb11-d50f62297e3d.png)

6, configure the environment variables

Shell Code

[View Image](http://eric-gao.iteye.com/images/icon_star.png)

- $ echo "PATH=$PATH:/home/eric/arm-linux-tools/x-tools/arm-S3C2440-linux-gnueabi/bin" >> ~/.bashrc
- $ source ~/.bashrc

7. Confirm the installation is complete

Shell Code

[View Image](http://eric-gao.iteye.com/images/icon_star.png)

- $ arm-S3C2440-linux-gnueabi-gcc -v

[View Image](http://dl2.iteye.com/upload/attachment/0103/6553/a080e479-a19a-311a-a5b7-14fb29bc8ff2.png)

8, after successful compilation cross compiler path

(1) The compiler path:/home/eric/arm-linux-tools/x-tools/arm-S3C2440-linux-gnueabi/bin

(2) the library file path:/home/eric/arm-linux-tools/x-tools/arm-S3C2440-linux-gnueabi/arm-S3C2440-linux-gnueabi/lib

**Third, compile the test**

1, write a simple C program: Hello, World

C code

[View Image](http://eric-gao.iteye.com/images/icon_star.png)

- #include <stdio.h>
- int main() {
- printf("Hello, World\n");
- return 0;
- }

2, compiled

Shell Code

[View Image](http://eric-gao.iteye.com/images/icon_star.png)

- $ arm-S3C2440-linux-gnueabi-gcc -o hello hello.c

3, upload it to the target board and performs

Shell Code

[View Image](http://eric-gao.iteye.com/images/icon_star.png)

- $ chmod +x ./hello
- $ ./hello

[View Image](http://dl2.iteye.com/upload/attachment/0103/6992/c459e13c-d005-3b02-b784-77fcb34a1833.jpg)

As shown above, the chain cross compiler created successfully compiled into instructions of the target board can be identified.

For more information about and use crosstool-ng, see: [http://www.crifan.com/files/doc/docbook/crosstool_ng/release/htmls/index.html](http://www.crifan.com/files/doc/docbook/crosstool_ng/release/htmls/index.html)

Download the required dependencies: [http://download.csdn.net/detail/jsntghf/8198753](http://download.csdn.net/detail/jsntghf/8198753)

Compiled cross compiler tool chain Download: [http://download.csdn.net/detail/jsntghf/8206693](http://download.csdn.net/detail/jsntghf/8206693)

Credit

*widgets* Related Articles

*widgets* Contribution

This article is contributed by
 CNB
 and text available under
 [CC-SA-4.0](https://creativecommons.org/licenses/by-sa/4.0/)
