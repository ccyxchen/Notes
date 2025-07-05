# shutdown_detect 机制

## 内核代码
驱动路径：
`vendor\bsp\kernel5.15\kernel5.15\drivers\unisoc_platform\shutdown_detect\shutdown_detect.c`

该驱动只是创建一个proc 节点，根据节点写入的值执行相应操作。

这个驱动用于监控关机超时的异常。上层传入不同值到/proc/shutdown_detect 来设置超时时间和状态
MeizuNote16:/ # cat /proc/shutdown_detect
=== shutdown_detect controller ===
0: shutdown_detect abort
20: shutdown_detect systemcall reboot phase
30: shutdown_detect init reboot phase
40: shutdown_detect system server reboot phase
=== shutdown_detect controller ===

=== shutdown_detect: shutdown phase: 0

1、如果传入0，会禁用shutdown_detect
2、

## 上层控制关机或重启
上层控制关机/重启主要有3种方式：
1、直接调用内核sys_reboot 接口
2、调用系统关机接口
3、设置sys.powerctl这个prop触发关机或重启

## 上层控制

### shutdown_detect的开关控制
路径：`system/vendor/sprd/platform/frameworks/native/services/ultraframework/shutdown_log/shutdown_log.c`

```C
#define PATH_SHUTDOWN_DETECT_CONFIG         "/product/etc/shutdown_detect_config.xml"

int main(void)
{

    if (read_shutdown_detect_config() == 0) {
        ALOGE("read shutdown detect config fail\n");
        return 0;
    }
//通过PATH_SHUTDOWN_DETECT_CONFIG的xml获取使能状态和超时时间
    ALOGD("main_on is %s\n", shutdown_config.scenes->shutdowns->main_on);
    // 0:off, 1:on, 2:string lengths
    if (!strcmp(shutdown_config.scenes->shutdowns->main_on, "1")) {
        write_shutdown_detect_node("1", 2);    //使能shutdown_detect
        ALOGD("timeout_val is %s\n", shutdown_config.scenes->shutdowns->timeout_val);//设置timeout 的值
        //M2521的timeout_val定义为0x5AFF
        write_shutdown_detect_node(shutdown_config.scenes->shutdowns->timeout_val, LEN_TIMEOUT_MAX);
    } else {
        ALOGD("Not enable shutdown detect !\n");
        write_shutdown_detect_node("0", 2);
    }

    return 0;
}
```

对于0x5AFF的值，gnativetimeout=15，gjavatimeout=15，gtotaltimeout=90

### 重启超时的检测
`system/system/core/init/reboot.cpp`
`system/frameworks/base/services/core/java/com/android/server/power/ShutdownThread.java`
