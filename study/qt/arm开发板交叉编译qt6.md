# arm开发板交叉编译qt6

## 编译前的准备

这里主要介绍如何在Ubuntu中交叉编译 qt 6.2.2 的arm版本,并且只编译qtbase库，如果要完整编译只要将configure文件换成qt源码顶级目录下的同名文件。同理，如果只想安装某个子模块，就将configure替换成子模块下的同名文件。

参考官方文档：<https://doc.qt.io/qt-6/configure-linux-device.html>

qt6的编译系统做的越来越健全，基本是傻瓜式操作，按照文档说明来就好。这里主要做个笔记以防自已以后会用到。

先决条件：
    1、先编译Ubuntu桌面版本，我安装在`/workspace/open/qt/qtdev_qtbase/install`。
    2、具有完整的交叉编译工具链，包括sysroot,这里的sysroot指gcc的头文件和库文件以及其他要用到的文件都要放在一个目录下，稍后编写cmake配置文件时会使用到。

## 编译

1、创建若干目录：
    交叉编译qt的编译目录：/workspace/open/qt/qtdev_s3c2440_gcc5
    安装生成结果的目录：/workspace/open/qt/qtdev_s3c2440_gcc5/install

2、创建cmake配置文件，我的是/workspace/open/qt/qtdev_s3c2440_gcc5/s3c2440.cmake
内容如下

```cmake
cmake_minimum_required(VERSION 3.18)
include_guard(GLOBAL)

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(TARGET_SYSROOT /workspace/open/crosstool-ng/cross_1.21/x-tool/arm-S3C2440-linux-gnueabi/arm-S3C2440-linux-gnueabi/sysroot)
set(CROSS_COMPILER /workspace/open/crosstool-ng/cross_1.21/x-tool/arm-S3C2440-linux-gnueabi/bin)

set(CMAKE_SYSROOT ${TARGET_SYSROOT})
set(Qt6HostInfo_DIR /workspace/open/qt/qtdev_qtbase/install/lib/cmake/Qt6HostInfo)

set(ENV{PKG_CONFIG_PATH} "")
set(ENV{PKG_CONFIG_LIBDIR} ${CMAKE_SYSROOT}/usr/lib/pkgconfig:${CMAKE_SYSROOT}/usr/share/pkgconfig)
set(ENV{PKG_CONFIG_SYSROOT_DIR} ${CMAKE_SYSROOT})

# set(QT_FEATURE_opengles2 on)

set(CMAKE_C_COMPILER ${CROSS_COMPILER}/arm-S3C2440-linux-gnueabi-gcc)
set(CMAKE_CXX_COMPILER ${CROSS_COMPILER}/arm-S3C2440-linux-gnueabi-g++)

set(QT_COMPILER_FLAGS "-march=armv4t -mfloat-abi=soft")
set(QT_COMPILER_FLAGS_RELEASE "-O2 -pipe")
set(QT_LINKER_FLAGS "-Wl,-O1 -Wl,--hash-style=gnu -Wl,--as-needed")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

include(CMakeInitializeConfigs)

function(cmake_initialize_per_config_variable _PREFIX _DOCSTRING)
  if (_PREFIX MATCHES "CMAKE_(C|CXX|ASM)_FLAGS")
    set(CMAKE_${CMAKE_MATCH_1}_FLAGS_INIT "${QT_COMPILER_FLAGS}")

    foreach (config DEBUG RELEASE MINSIZEREL RELWITHDEBINFO)
      if (DEFINED QT_COMPILER_FLAGS_${config})
        set(CMAKE_${CMAKE_MATCH_1}_FLAGS_${config}_INIT "${QT_COMPILER_FLAGS_${config}}")
      endif()
    endforeach()
  endif()

  if (_PREFIX MATCHES "CMAKE_(SHARED|MODULE|EXE)_LINKER_FLAGS")
    foreach (config SHARED MODULE EXE)
      set(CMAKE_${config}_LINKER_FLAGS_INIT "${QT_LINKER_FLAGS}")
    endforeach()
  endif()

  _cmake_initialize_per_config_variable(${ARGV})
endfunction()
```

```shell
../qt-everywhere-src-6.2.2/qtbase/configure -release -no-opengl  -nomake tests \
  -qt-host-path /workspace/open/qt/qtdev_qtbase                              \
  -extprefix  /workspace/open/qt/qtdev_s3c2440_gcc5/install                            \
  -prefix /usr/local/qt6                                   \
  -- -DCMAKE_TOOLCHAIN_FILE=/workspace/open/qt/qtdev_s3c2440_gcc5/s3c2440.cmake
```
