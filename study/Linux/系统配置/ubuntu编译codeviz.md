# Ubuntu编译codeviz gcc

## docker ubuntu-14.04 编译gcc-7.4.0

### 旧的Ubuntu需要更新源

```Shell
sed -i -e 's/:\/\/(archive.ubuntu.com\|security.ubuntu.com)/old-releases.ubuntu.com/g' /etc/apt/sources.list
```

### 安装编译工具链和库

```Shell
apt-get install make vim git gcc build-essential  libgmp-dev 
libmpfr-dev libmpc-dev gcc-multilib perl graphviz libncurses5-dev 
libncursesw5-dev  bash-completion texi2html valgrind
```

### 将codeviz的库安装到系统

```Shell
cd codeviz
cp ./lib/* -rv /usr/lib/   (Or your preferred perl library path)
cp ./bin/* /usr/local/bin
```

### 对gcc-7.4.0源码打补丁

`patch -p1 < ../codeviz/compilers/gcc-patches/gcc-7.4.0-cdepn.diff`

### 源码中注意的点

```C
   if (!exit_after_options)
-    {
-      if (m_use_TV_TOTAL)
-       start_timevars ();
-      do_compile ();
-    }
+  {
+    if (m_use_TV_TOTAL)
+      start_timevars();
+
+    cdepn_dump = ((getenv("CDEPN_SUPPRESS")) ? 0 : 1);
+    if (cdepn_dump)
+      cdepn_open(main_input_filename);
+    do_compile ();
+    if (cdepn_dump)
+      cdepn_close();
+  }
/* 当未定义CDEPN_SUPPRESS环境变量，cdepn_dump的值为1，会执行cdepn_open去创建cdepn，
 * 而编译gcc编译器时是不需要生成cdepn文件的，所以需要定义CDEPN_SUPPRESS环境变量。
 */ 

getenv的使用
 #include <stdlib.h>

char *getenv(const char *name);

char *secure_getenv(const char *name);

The  getenv()  function  searches  the  environment  list to find the environment variable name, and returns a pointer to the corresponding value string.

getenv返回name这个环境变量的值的指针，如果没有该变量则为NULL。
```

### 编译codeviz的gcc

```Shell
export CDEPN_SUPPRESS=yes
export LIBRARY_PATH=/usr/lib/x86_64-linux-gnu
./configure --prefix=/home/bin/gcc-7.4.0/install/ --enable-shared --enable-languages=c,c++
make bootstrap -j32
make
make install
```

### 使用新编译器编译linux

```Shell
cp arch/x86/configs/x86_64_defconfig .config
make CC=/home/cyx/bin/gcc-7.4.0/install/bin/gcc menuconfig
make CC=/home/cyx/bin/gcc-7.4.0/install/bin/gcc -j32
```
