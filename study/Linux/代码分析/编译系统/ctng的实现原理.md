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

### 使用ctng的基本步骤：

```Shell
# 1、 选择sample用例
ct-ng list-samples
ct-ng aarch64-unknown-linux-gnu
# 2、设置.config
ct-ng menuconfig
# 3、编译并安装
ct-ng build.32
```

### ct-ng 编译x86-64 gcc
```Shell
ct-ng x86_64-multilib-linux-gnu
ct-ng menuconfig 
# 修改路径,调试log等级
--> (${CT_TOP_DIR}/src) Local tarballs directory
--> (${CT_PREFIX:-${CT_TOP_DIR}/install}/${CT_HOST:+HOST-${CT_HOST}/}${CT_TARGET}) P│
--> (32) Number of parallel jobs
--> Maximum log level to see: (DEBUG)
--> [*] Debug crosstool-NG                                                   
       [ ]   Pause between every steps (NEW)                              
       [*]   Save intermediate steps                                         
       [*]     gzip saved states   
# 下载完源码后暂停,方便打补丁
ct-ng +companion_tools_for_build
cd .build/src/gcc-15.2.0/

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

当执行完menuconfig配置.config后，执行ct-ng build开始编译。

build需要执行的内容如下所示：

build最终执行scripts/crosstool-NG.sh去编译工具链。如果未开启ct-steps分步调试功能时
，crosstool-NG.sh会一次性完整执行整个编译过程，如果已设置ct-steps，则可以通过STOP和
RESTART变量控制需要执行的步骤，crosstool-NG.sh中除了编译相关步骤是在分步时执行，其他
步骤都是预备工作，包括：

1.CT_LoadConfig，解析config文件定义环境变量
2.根据环境变量下载所有需要的源码
3.根据环境变量解压源码并打补丁

分步执行的步骤如下定义：

```shell
CT_STEPS := \
            companion_tools_for_build  \
            companion_libs_for_build   \
            binutils_for_build         \
            companion_tools_for_host   \
            companion_libs_for_host    \
            binutils_for_host          \
            linker                     \
            libc_headers               \
            kernel_headers             \
            cc_core                    \
            libc_main                  \
            cc_for_build               \
            cc_for_host                \
            libc_post_cc               \
            companion_libs_for_target  \
            binutils_for_target        \
            debug                      \
            test_suite                 \
            finish                     \

# 对应解析代码
if [ "${CT_ONLY_DOWNLOAD}" != "y" -a "${CT_ONLY_EXTRACT}" != "y" ]; then
    # Because of CT_RESTART, this becomes quite complex
    do_stop=0
    prev_step=
    [ -n "${CT_RESTART}" ] && do_it=0 || do_it=1
    for step in ${CT_STEPS}; do
        if [ ${do_it} -eq 0 ]; then
            if [ "${CT_RESTART}" = "${step}" ]; then
                CT_DoLoadState "${step}"
                do_it=1
                do_stop=0
            fi
        else
            CT_DoSaveState ${step}
            if [ ${do_stop} -eq 1 ]; then
                CT_DoLog INFO "Stopping just after step '${prev_step}', as requested."
                exit 0
            fi
        fi
        if [ ${do_it} -eq 1 ]; then
            ( do_${step} )
            # POSIX 1003.1-2008 does not say if "set -e" should catch a
            # sub-shell ending with !0. bash-3 does not, while bash-4 does,
            # so the following line is for bash-3; bash-4 would choke above.
            [ $? -eq 0 ]
            # Pick up environment changes.
            if [ -r "${CT_BUILD_DIR}/env.modify.sh" ]; then
                CT_DoLog DEBUG "Step '${step}' modified the environment:"
                CT_DoExecLog DEBUG cat "${CT_BUILD_DIR}/env.modify.sh"
                . "${CT_BUILD_DIR}/env.modify.sh"
                CT_DoExecLog DEBUG rm -f "${CT_BUILD_DIR}/env.modify.sh"

            fi
            if [ "${CT_STOP}" = "${step}" ]; then
                do_stop=1
            fi
            if [ "${CT_DEBUG_PAUSE_STEPS}" = "y" ]; then
                CT_DoPause "Step '${step}' finished"
            fi
        fi
        prev_step="${step}"
    done
fi

# 可以看到是根据CT_RESTART和CT_STOP的值去执行CT_STEPS 中的函数do_${step}
```

![1](../../tmpimage/ctng的实现原理2024-10-19-22-00-04.png)

## do_companion_tools_for_build执行过程


