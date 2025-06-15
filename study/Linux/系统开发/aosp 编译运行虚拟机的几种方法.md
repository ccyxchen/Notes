# aosp 编译运行虚拟机的几种方法
## 通过aosp的emulator运行
### 编译工程选择
新的Android编译系统发生改变，不能使用lunch 列出可用的工程，改为使用list* 命令查询后组合成
工程名
```shell
# 列出工程
$ list_products
aosp_64bitonly_x86_64
aosp_akita
aosp_akita_16k
aosp_akita_fullmte
aosp_arm
# 列出编译类型
$ list_variants
user
userdebug
eng
# 列出编译基线
$ list_releases sdk_phone64_x86_64
aosp_current
ap2a
ap3a
ap4a
bp1a
trunk_staging
```

这里需要选择sdk_phone64_x86_64 工程，这个工程编译的镜像可以运行qemu2虚拟机
```shell
lunch sdk_phone64_x86_64-trunk_staging-userdebug
make -j32
```

编译完成后，会在out 目录生成镜像，其中的kernel 和 ko 是预编译的，从代码如
下路径cp过程：
`prebuilts/qemu-kernel/x86_64/6.6/`

### 编译自己的kernel镜像
先下载android-kerenl 内核代码，选择6.6内核
`repo init -u https://android.googlesource.com/kernel/manifest -b common-android15-6.6`

需要编译模拟器使用的内核，官方提供的命令：
`tools/bazel run //common-modules/virtual-device:virtual_device_x86_64_dist [-- --destdir=$DIST_DIR]`
同时可以参考Kleaf 的文档：
[kleaf.md](https://android.googlesource.com/kernel/build/+/refs/heads/main/kleaf/docs/kleaf.md)

编译生成少了很多的ko文件，将需要的ko编译出来
```diff
~/work_open/opensource/android-kernel/common-modules/virtual-device$ git diff
diff --git a/BUILD.bazel b/BUILD.bazel
index 2deb1f7..d0c527a 100644
--- a/BUILD.bazel
+++ b/BUILD.bazel
@@ -173,6 +173,97 @@ _VIRT_COMMON_MODULES = [
     "virtio_input.ko",
     "virtio_net.ko",
     "virtio_snd.ko",
+    "6lowpan.ko",
+    "8021q.ko",
+    "9pnet.ko",
+    "9pnet_fd.ko",
+    "aqc111.ko",
+    "asix.ko",
+    "ax88179_178a.ko",
+    "bluetooth.ko",
+    "bsd_comp.ko",
+    "btbcm.ko",
+    "btqca.ko",
+    "btsdio.ko",
+    "can-bcm.ko",
+    "can-dev.ko",
+    "can-gw.ko",
+    "can-raw.ko",
+    "can.ko",
+    "cdc-acm.ko",
+    "cdc_eem.ko",
+    "cdc_ether.ko",
+    "cdc_ncm.ko",
+    "dev_addr_lists_test.ko",
+    "diag.ko",
+    "ext4-inode-test.ko",
+    "fat_test.ko",
+    "ftdi_sio.ko",
+    "hci_uart.ko",
+    "hid-uclogic-test.ko",
+    "hidp.ko",
+    "ieee802154.ko",
+    "ieee802154_6lowpan.ko",
+    "ieee802154_socket.ko",
+    "iio-test-format.ko",
+    "input_test.ko",
+    "kheaders.ko",
+    "kunit-example-test.ko",
+    "kunit-test.ko",
+    "kunit.ko",
+    "l2tp_core.ko",
+    "l2tp_ppp.ko",
+    "lib_test.ko",
+    "libarc4.ko",
+    "mac802154.ko",
+    "macsec.ko",
+    "mii.ko",
+    "nfc.ko",
+    "nhc_dest.ko",
+    "nhc_fragment.ko",
+    "nhc_hop.ko",
+    "nhc_ipv6.ko",
+    "nhc_mobility.ko",
+    "nhc_routing.ko",
+    "nhc_udp.ko",
+    "ppp_deflate.ko",
+    "ppp_generic.ko",
+    "ppp_mppe.ko",
+    "pppox.ko",
+    "pps_core.ko",
+    "pptp.ko",
+    "ptp.ko",
+    "ptp_kvm.ko",
+    "r8152.ko",
+    "r8153_ecm.ko",
+    "regmap-kunit.ko",
+    "regmap-ram.ko",
+    "regmap-raw-ram.ko",
+    "rfcomm.ko",
+    "rfkill.ko",
+    "rtl8150.ko",
+    "slcan.ko",
+    "slhc.ko",
+    "soc-topology-test.ko",
+    "soc-utils-test.ko",
+    "time_test.ko",
+    "tipc.ko",
+    "tls.ko",
+    "usbmon.ko",
+    "usbnet.ko",
+    "usbserial.ko",
+    "vcan.ko",
+    "vcpu_stall_detector.ko",
+    "virtio_balloon.ko",
+    "virtio_blk.ko",
+    "virtio_console.ko",
+    "virtio_pci.ko",
+    "virtio_pci_legacy_dev.ko",
+    "virtio_pci_modern_dev.ko",
+    "vmw_vsock_virtio_transport.ko",
+    "wwan.ko",
+    "zram.ko",
+    "zsmalloc.ko",
 ]

 _VIRT_AARCH64_MODULES = [
```
另外运行qemu 需要其他的一些驱动
```diff
diff --git a/virtual_device.fragment b/virtual_device.fragment
index 492da0c..555f008 100644
--- a/virtual_device.fragment
+++ b/virtual_device.fragment
@@ -34,3 +34,24 @@ CONFIG_SND_ALOOP=m

 # TV-specific drivers
 CONFIG_USB_PULSE8_CEC=m
+CONFIG_NET_9P=m
+CONFIG_NET_9P_FD=m
+CONFIG_EXT4_KUNIT_TESTS=m
+CONFIG_FAT_KUNIT_TEST=m
+CONFIG_KUNIT=m
+CONFIG_KUNIT_DEBUGFS=y
+CONFIG_KUNIT_TEST=m
+CONFIG_KUNIT_EXAMPLE_TEST=m
+CONFIG_MACSEC=m
+CONFIG_PPS=m
+CONFIG_PTP_1588_CLOCK=m
+CONFIG_PTP_1588_CLOCK_OPTIONAL=m
+CONFIG_PTP_1588_CLOCK_KVM=m
+CONFIG_REGMAP_KUNIT=m
+CONFIG_REGMAP_RAM=m
+CONFIG_TLS=m
+CONFIG_USB_MON=m
+CONFIG_VCPU_STALL_DETECTOR=m
+CONFIG_VIRTIO_PCI_LIB_LEGACY=m
+CONFIG_WWAN=m
+CONFIG_SND_ALOOP=m
```

将生成的ko 拷贝到aosp 的prebuilts目录下，重新编译，还需要替换kernel镜像：
`cp out/virtual_device_x86_64/dist/bzImage ../aosp/out/target/product/emu64x/kernel-ranchu`

最后运行模拟器：
`emulator -show-kernel`

### 运行 emulator 的原理
emulator是aosp 中的模拟器程序，其源码位于：[qemu.git](https://android.googlesource.com/platform/external/qemu.git)
该仓库中默认的master分支并不是模拟器代码，带emu 的分支才是模拟器代码，最新的代码位于`emu-master-dev`分支。

当aosp 编译sdk_phone64_x86_64 工程时，其编译出x86_64的qemu2 Android模拟器系统镜像。 在执行lunch再执行emulator，
就会运行x86_64的模拟器。其中lunch会设置一系列的变量，emulator 程序会根据这些变量运行模拟器。
shell中查看设置的变量和函数：
```Shell
# 查看设置变量和函数
set
# 查看函数定义
declare -f lunch
# 查看变量定义
echo $PATH
```
#### lunch 的关键步骤如下：
```Shell
# lunch 定义
# build/envsetup.sh
function lunch()
{
    ...
    # Validate the selection and set all the environment stuff
    _lunch_meat $product $release $variant
}

function _lunch_meat()
{
    ...
    export TARGET_PRODUCT=$(_get_build_var_cached TARGET_PRODUCT)
    export TARGET_BUILD_VARIANT=$(_get_build_var_cached TARGET_BUILD_VARIANT)
    export TARGET_RELEASE=$release
    # Note this is the string "release", not the value of the variable.
    export TARGET_BUILD_TYPE=release

    [[ -n "${ANDROID_QUIET_BUILD:-}" ]] || echo
# 设置环境变量
    set_stuff_for_environment
    ...

    destroy_build_var_cache

    if [[ -n "${CHECK_MU_CONFIG:-}" ]]; then
      check_mu_config
    fi
}

function set_stuff_for_environment()
{
# 设置 各种路径变量
    set_lunch_paths
    set_sequence_number

    export ANDROID_BUILD_TOP=$(gettop)
}
```
#### sdk_phone64_x86_64 工程解析
工程配置文件：
`device/generic/goldfish/64bitonly/product/sdk_phone64_x86_64.mk`
其中和模拟器相关的配置：
```Shell
# 包含模拟器解析的参数文件
# device/generic/goldfish/64bitonly/product/sdk_phone64_x86_64.mk
$(call inherit-product, device/generic/goldfish/board/emu64x/details.mk)
$(call inherit-product, device/generic/goldfish/product/phone.mk)

PRODUCT_BRAND := Android
PRODUCT_NAME := sdk_phone64_x86_64
PRODUCT_DEVICE := emu64x
PRODUCT_MODEL := Android SDK built for x86_64

# device/generic/goldfish/product/phone.mk
$(call inherit-product, device/generic/goldfish/product/handheld.mk)
$(call inherit-product, device/generic/goldfish/product/base_phone.mk)

PRODUCT_COPY_FILES += \
    # 模拟器的功能定义，如是否有蓝牙，UWB设备等
    device/generic/goldfish/data/etc/advancedFeatures.ini:advancedFeatures.ini \
    # 模拟器的硬件参数，在emulator启动时会解析该文件
    device/generic/goldfish/data/etc/config.ini.nexus5:config.ini

# device/generic/goldfish/data/etc/config.ini.nexus5
avd.ini.encoding=UTF-8
disk.dataPartition.size=10G
fastboot.forceColdBoot = yes
hw.accelerometer=yes
hw.audioInput=yes
hw.battery=yes
hw.camera.back=emulated
hw.camera.front=emulated
hw.dPad=no
hw.gps=yes
hw.gpu.enabled=yes
hw.keyboard=yes
hw.lcd.density=480
hw.cpu.ncore = 4
hw.mainKeys=no
hw.ramSize = 4096
hw.sensors.orientation=yes
hw.sensors.proximity=yes
image.sysdir.1=x86/
skin.dynamic=no
skin.name=1080x1920
skin.path=1080x1920

# device/generic/goldfish/board/emu64x/details.mk
include device/generic/goldfish/board/kernel/x86_64.mk


PRODUCT_COPY_FILES += \
    $(EMULATOR_KERNEL_FILE):kernel-ranchu \
    device/generic/goldfish/board/fstab/x86:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/first_stage_ramdisk/fstab.ranchu \
    device/generic/goldfish/board/fstab/x86:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.ranchu \

$(call inherit-product, device/generic/goldfish/board/16k.mk)

# device/generic/goldfish/board/kernel/x86_64.mk
# BOARD_KERNEL_CMDLINE is not supported (b/361341981), use the file below
PRODUCT_COPY_FILES += \
    device/generic/goldfish/board/kernel/x86_64_cmdline.txt:kernel_cmdline.txt
    
# device/generic/goldfish/board/kernel/x86_64_cmdline.txt
8250.nr_uarts=1 clocksource=pit
```

#### emulator相关设置
emulator运行时会在`out/target/product/emu64x`下生成一些文件
1. 运行命令： emu-launch-params.txt
2. 硬件配置参数： hardware-qemu.ini， 该文件可以结合-android-hw 参数使用

emulator 加上-verbose 可以打印出完整的启动过程，最终使用的命令为：
`/home/cyx/work_open/opensource/aosp/prebuilts/android-emulator/linux-x86_64/qemu/linux-x86_64/qemu-system-x86_64 -dns-server 10.255.255.254 -serial null -device goldfish_pstore,addr=0xff018000,size=0x10000,file=/home/cyx/work_open/opensource/aosp/out/target/product/emu64x/build.avd/data/misc/pstore/pstore.bin -cpu android64 -enable-kvm -smp cores=4 -m 8192 -lcd-density 480 -object iothread,id=disk-iothread -nodefaults -kernel /home/cyx/work_open/opensource/aosp/out/target/product/emu64x/kernel-ranchu -initrd /home/cyx/work_open/opensource/aosp/out/target/product/emu64x/initrd -drive if=none,index=0,id=system,if=none,file=/home/cyx/work_open/opensource/aosp/out/target/product/emu64x/system-qemu.img,read-only -device virtio-blk-pci,drive=system,iothread=disk-iothread,modern-pio-notify -drive if=none,index=1,id=cache,if=none,file=/home/cyx/work_open/opensource/aosp/out/target/product/emu64x/cache.img.qcow2,overlap-check=none,cache=unsafe,l2-cache-size=1048576 -device virtio-blk-pci,drive=cache,iothread=disk-iothread,modern-pio-notify -drive if=none,index=2,id=userdata,if=none,file=/home/cyx/work_open/opensource/aosp/out/target/product/emu64x/userdata-qemu.img.qcow2,overlap-check=none,cache=unsafe,l2-cache-size=1048576 -device virtio-blk-pci,drive=userdata,iothread=disk-iothread,modern-pio-notify -drive if=none,index=3,id=encrypt,if=none,file=/home/cyx/work_open/opensource/aosp/out/target/product/emu64x/encryptionkey.img.qcow2,overlap-check=none,cache=unsafe,l2-cache-size=1048576 -device virtio-blk-pci,drive=encrypt,iothread=disk-iothread,modern-pio-notify -drive if=none,index=4,id=vendor,if=none,file=/home/cyx/work_open/opensource/aosp/out/target/product/emu64x/vendor-qemu.img,read-only -device virtio-blk-pci,drive=vendor,iothread=disk-iothread,modern-pio-notify -netdev user,id=mynet -device virtio-net-pci,netdev=mynet -chardev null,id=forhvc0 -chardev null,id=forhvc1 -device virtio-serial-pci,ioeventfd=off -device virtconsole,chardev=forhvc0 -device virtconsole,chardev=forhvc1 -chardev netsim,id=uwb -device virtconsole,chardev=uwb,name=uwb -chardev netsim,id=bluetooth -device virtserialport,chardev=bluetooth,name=bluetooth -device virtio-serial,ioeventfd=off -chardev socket,port=44911,host=::1,nowait,nodelay,reconnect=10,ipv6,id=modem -device virtserialport,chardev=modem,name=modem -device virtio-rng-pci -show-cursor -device virtio_input_multi_touch_pci_1 -device virtio_input_multi_touch_pci_2 -device virtio_input_multi_touch_pci_3 -device virtio_input_multi_touch_pci_4 -device virtio_input_multi_touch_pci_5 -device virtio_input_multi_touch_pci_6 -device virtio_input_multi_touch_pci_7 -device virtio_input_multi_touch_pci_8 -device virtio_input_multi_touch_pci_9 -device virtio_input_multi_touch_pci_10 -device virtio_input_multi_touch_pci_11 -device virtio-keyboard-pci -netdev user,id=virtio-wifi,dhcpstart=10.0.2.16 -device virtio-wifi-pci,netdev=virtio-wifi -device virtio-vsock-pci,guest-cid=77 -L /home/cyx/work_open/opensource/aosp/prebuilts/android-emulator/linux-x86_64/lib/pc-bios -soundhw virtio-snd-pci -vga none -chardev pty,id=serial0 -serial chardev:serial0 -append '8250.nr_uarts=1 clocksource=pit no_timer_check console=0 loop.max_part=7 ramoops.mem_address=0xff018000 ramoops.mem_size=0x10000 memmap=0x10000$0xff018000 printk.devkmsg=on bootconfig console=ttyS0' -android-hw /home/cyx/work_open/opensource/aosp/out/target/product/emu64x/hardware-qemu.ini`

可以看到使用的是预编译的qemu-system-x86_64启动的，emulator 的autoconfig 功能会根据lunch时设置环境变量找到out目录，
并从out下找到相关的配置文件和镜像，通过解析这些信息生成最终的运行参数和hardware-qemu.ini文件。

直接运行这个命令是无法启动的，因为emulater会设置必要的环境变量和动态库。

##### 设置串口
使用 -serial chardev:serial0 -chardev pty,id=serial0 运行会报错：
```txt
qemu-system-x86_64: -serial null: Duplicate ID 'serial0' for chardev
qemu-system-x86_64: -serial null: could not connect serial device to character backend 'null'
```
这是因为emulator 已经设置了-serial null ，导致了重复设置。
```C
// emulator 会自动添加启动参数
// android_emulator\qemu\android-qemu2-glue\main.cpp

// Always setup a single serial port, that can be connected
    // either to the 'null' chardev, or the -shell-serial one,
    // which by default will be either 'stdout' (Posix) or 'con:'
    // (Windows).
    const char* const serial =
            (!opts->virtio_console && (opts->shell || opts->show_kernel))
                    ? opts->shell_serial
                    : "null";

    args.add2("-serial", serial);
```
从代码可以看到默认是设置null， 如果需要设置自定义值，需要使用-shell-serial 参数。
最终的参数：
`-shell-serial chardev:serial0  -qemu -chardev pty,id=serial0`

##### 添加磁盘
使用`-drive if=none,index=5,id=myhd,if=none,file=/home/cyx/work_open/opensource/aosp/out/v1.img -device virtio-blk-pci,drive=myhd,iothread=disk-iothread,modern-pio-notify`设置会报错：
qemu-system-x86_64: -device virtio-blk-pci,drive=vvmm: Device needs media, but drive is empty

推测是未识别到img 文件，这里未找到原因，可能是需要向emulator 注册该镜像文件才会识别。

替代的方法，试验可用：
`-drive file=disk.qcow2,format=qcow2,if=virtio`

## 通过cuttlefish运行