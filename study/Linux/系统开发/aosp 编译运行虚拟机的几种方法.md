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

## 通过cuttlefish运行