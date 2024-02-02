# 查看开机和重启原因

## log中关键字

```txt
cmdline: console=tty0 console=ttyS0,921600n1 root=/dev/ram vmalloc=400M slub_debug=OFZPU swiotlb=noforce cgroup.memory=nosocket,nokmem f
[3553]        : irmware_class.path=/vendor/firmware page_owner=on loop.max_part=7 has_battery_removed=0 loop.max_part=7 androidboot.boot_device
[3555]        : s=bootdevice,soc/11230000.mmc,11230000.mmc,soc/11230000.msdc,11230000.msdc ramoops.mem_address=0x4d010000 ramoops.mem_size=0xe0
[3558]        : 000 ramoops.pmsg_size=0x10000 ramoops.console_size=0x40000 bootopt=64S3,32N2,64N2 androidboot.init_fatal_panic=true buildvarian
[3561]        : t=userdebug root=/dev/ram androidboot.vbmeta.device=PARTUUID=5f6a2c79-6617-4b85-ac02-c2975a14d2d7 androidboot.vbmeta.avb_versio
[3563]        : n=1.2 androidboot.vbmeta.device_state=locked androidboot.veritymode=enforcing androidboot.veritymode.managed=yes androidboot.sl
[3566]        : ot_suffix=_a androidboot.slot=a androidboot.verifiedbootstate=green androidboot.atm=disabled androidboot.force_normal_boot=1 an
[3568]        : droidboot.meta_log_disable=0 androidboot.hwmodel=t402aa androidboot.hwrev=EVT androidboot.sku= androidboot.barcode=JS2348802357
[3571]        :  androidboot.barcodeflag=P10P androidboot.efuse=no androidboot.locked=yes androidboot.wpid=0 mtk_printk_ctrl.disable_uart=0 and
[3574]        : roidboot.serialno=JS2348802357 androidboot.bootreason=reboot gpt=1 usb2jtag_mode=0 androidboot.dtb_idx=0 androidboot.dtbo_idx=0
[3576]        :  androidboot.boardid=3 androidboot.hwid=0
[3577] lk boot mode = 0
[3578] lk boot reason = 4
```

## 代码中的定义

```C
//kernel-4.19/drivers/misc/mediatek/include/mt-plat/mtk_boot_reason.h 
9  enum boot_reason_t {
10   BR_POWER_KEY = 0,
11   BR_USB,
12   BR_RTC,
13   BR_WDT,
14   BR_WDT_BY_PASS_PWK,
15   BR_TOOL_BY_PASS_PWK,
16   BR_2SEC_REBOOT,
17   BR_UNKNOWN
18  };

//drivers/misc/mediatek/include/mt-plat/mtk_boot_common.h
 10 enum boot_mode_t {
 11         NORMAL_BOOT = 0,
 12         META_BOOT = 1,
 13         RECOVERY_BOOT = 2,
 14         SW_REBOOT = 3,
 15         FACTORY_BOOT = 4,
 16         ADVMETA_BOOT = 5,
 17         ATE_FACTORY_BOOT = 6,
 18         ALARM_BOOT = 7,
 19         KERNEL_POWER_OFF_CHARGING_BOOT = 8,
 20         LOW_POWER_OFF_CHARGING_BOOT = 9,
 21         DONGLE_BOOT = 10,
 22         UNKNOWN_BOOT
 23 };


//vendor/mediatek/proprietary/bootable/bootloader/preloader/platform/mt6768/src/drivers/inc/platform.h
typedef enum {
156      NORMAL_BOOT         = 0,
157      META_BOOT           = 1,
158      RECOVERY_BOOT       = 2,
159      SW_REBOOT           = 3,
160      FACTORY_BOOT        = 4,
161      ADVMETA_BOOT        = 5,
162      ATE_FACTORY_BOOT    = 6,
163      ALARM_BOOT          = 7,
164      FASTBOOT            = 99,
165  
166      DOWNLOAD_BOOT       = 100,
167      UNKNOWN_BOOT
168  } boot_mode_t;
169  
170  typedef enum {
171      BR_POWER_KEY = 0,
172      BR_USB,
173      BR_RTC,
174      BR_WDT,
175      BR_WDT_BY_PASS_PWK,
176      BR_TOOL_BY_PASS_PWK,
177      BR_2SEC_REBOOT,
178      BR_UNKNOWN,
179      BR_KERNEL_PANIC,
180      BR_WDT_SW,
181      BR_WDT_HW,
182      BR_POWER_EXC = 30,
183      BR_LONG_POWKEY,
184      BR_POWER_LOSS
185  } boot_reason_t;

//vendor/mediatek/proprietary/bootable/bootloader/lk/platform/mt6768/include/platform/boot_mode.h
63  /* boot type definitions */
64  typedef enum {
65   NORMAL_BOOT = 0,
66   META_BOOT = 1,
67   RECOVERY_BOOT = 2,
68   SW_REBOOT = 3,
69   FACTORY_BOOT = 4,
70   ADVMETA_BOOT = 5,
71   ATE_FACTORY_BOOT = 6,
72   ALARM_BOOT = 7,
73   KERNEL_POWER_OFF_CHARGING_BOOT = 8,
74   LOW_POWER_OFF_CHARGING_BOOT = 9,
75   FASTBOOT = 99,
76   DOWNLOAD_BOOT = 100,
77   UNKNOWN_BOOT
78  } BOOTMODE;
79  
80  typedef enum {
81   BR_POWER_KEY = 0,
82   BR_USB,
83   BR_RTC,
84   BR_WDT,
85   BR_WDT_BY_PASS_PWK,
86   BR_TOOL_BY_PASS_PWK,
87   BR_2SEC_REBOOT,
88   BR_UNKNOWN,
89   BR_KERNEL_PANIC,
90   BR_WDT_SW,
91   BR_WDT_HW,
92   BR_POWER_EXC = 30,
93   BR_LONG_POWKEY,
94   BR_POWER_LOSS,
95   BR_REBOOT_EXCEPTION
96  } boot_reason_t;
```

## 确认boot_mode

kernel log
01-26 16:09:16.311614     1     1 E .[7](1:swapper/0)cfg80211: batt_get_boot_mode: boot mode=0

[   28.268881] <6>.[2](123:irq/277-mt6358-)battery_get_boot_mode: boot mode=8
[   28.268883] <6>.[2](123:irq/277-mt6358-)mtk_battery boot mode =8
