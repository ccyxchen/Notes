# ctng 的使用与实现

## ctng基本命令

```shell
cyx@chenyx:~/bin/ctng_work$ ct-ng
This is crosstool-NG version 1.26.0.93_a87bf7f

Copyright (C) 2008  Yann E. MORIN <yann.morin.1998@free.fr>
This is free software; see the source for copying conditions.
There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

See below for a list of available actions, listed by category:

Configuration actions:
  show-config        - Show a brief overview of current configuration
  saveconfig         - Save current config as a preconfigured target
  menuconfig         - Update current config using a menu based program
  nconfig            - Update current config using a menu based program
  oldconfig          - Update current config using a provided .config as base
  upgradeconfig      - Upgrade config file to current crosstool-NG
  extractconfig      - Extract to stdout the configuration items from a
                       build.log file piped to stdin
  savedefconfig      - Save current config as a mini-defconfig to ${DEFCONFIG}
  defconfig          - Update config from a mini-defconfig ${DEFCONFIG}
                       (default: ${DEFCONFIG}=./defconfig)
  show-tuple         - Print the tuple of the currently configured toolchain

Preconfigured toolchains (#: force number of // jobs):
  list-samples       - Prints the list of all samples (for scripting)
  show-<sample>      - Show a brief overview of <sample> (list with list-samples)
  <sample>           - Preconfigure crosstool-NG with <sample> (list with list-samples)
  build-all[.#]      - Build *all* samples (list with list-samples) and install in
                       ${CT_PREFIX} (set to ~/x-tools by default)

Build actions (#: force number of // jobs):
  list-steps         - List all build steps
  source             - Download sources for currently configured toolchain
  build[.#]          - Build the currently configured toolchain

Clean actions:
  clean              - Remove generated files
  distclean          - Remove generated files, configuration and build directories

Distribution actions:
  check-samples      - Verify if samples need updates due to Kconfig changes
  update-samples     - Regenerate sample configurations using the current Kconfig
  updatetools        - Update the config tools

Environment variables (see http://crosstool-ng.github.io/docs/build/)
  STOP=step          - Stop the build just after this step (list with list-steps)
  RESTART=step       - Restart the build just before this step (list with list-steps)
  CT_PREFIX=dir      - Install samples in dir (see action "build-all", above).
  V=0|1|2|<unset>    - <unset> show only human-readable messages (default)
                       0 => do not show commands or human-readable message
                       1 => show only the commands being executed
                       2 => show both

Use action "menuconfig" to configure your toolchain
Use action "build" to build your toolchain
Use action "version" to see the version
See "man 1 ct-ng" for some help as well
```

使用ctng的基本步骤：

```Shell
# 1、 选择sample用例
ct-ng list-samples
ct-ng aarch64-unknown-linux-gnu
# 2、设置.config
ct-ng menuconfig
# 3、编译并安装
ct-ng build.32
```

## ctng打印所有log进行debug

1、设置log等级
ct-ng menuconfig 设置 "Maximum log level to see" 为DEBUG

2、编译时设置 V=2
ct-ng build.32 V=2

最终输出的log为 工作目录下的build.log

## ctng 的实现原理

### ctng 的入口

bin/ct-ng 是一个makefile 脚本， 当执行ct-ng 命令时，其实是调用 gmake 去运行这个脚本。
