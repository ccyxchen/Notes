# rtc时钟无法唤醒

## 原因分析

rtc 唤醒是通过下面这条命令设置的
`echo $(( $(date +%s) + 5 )) > /sys/class/rtc/rtc0/wakealarm`

这里会设置在5s 后 触发 rtc 中断唤醒，如果这个值被系统中其他服务修改，就无法实现精确唤醒。

```txt
[ 3246.026944] (0)[8760:sus.sh]rtc_mt6358: set al time = 2026/10/01 09:18:32 (1)
[ 3261.261036] (0)[8760:sus.sh]rtc_mt6358: set al time = 2026/10/01 09:18:47 (1)
[ 3264.479718] (5)[2294:binder:497_3]rtc_mt6358: set al time = 2026/10/01 09:19:27 (1)
[ 3276.445900] (0)[8760:sus.sh]rtc_mt6358: set al time = 2026/10/01 09:19:37 (1) 
```

从上面的log 可以看到有另一个程序修改了rtc，通过进程号查到是 `/system/bin/hw/android.system.suspend-service`。
它是 Android 11+ 的 SystemSuspend HAL，取代了旧版 PowerManagerService/libsuspend 直接写 /sys/power/* 的方式。
它的职责恰恰是让系统入睡，不是阻止入睡——autosuspend 线程读写 /sys/power/wakeup_count、/sys/power/state（SystemSuspend.cpp:342,379）。
它写 /sys/power/state 触发 suspend 时，内核 alarmtimer_suspend() 在写入者的线程上下文里执行（kernel-6.6/kernel/time/alarmtimer.c:275）：

```C
static int alarmtimer_suspend(struct device *dev)   // 当前任务 = 写 /sys/power/state 的线程
{
    /* 找出最近的 alarmtimer（AlarmManager、healthd 的 CLOCK_*_ALARM timerfd）*/
    rtc_timer_cancel(rtc, &rtctimer);
    rtc_timer_start(rtc, &rtctimer, now + min, 0);  // → __rtc_set_alarm → 驱动打印
}
```

驱动 set al time 的 dev_notice 打印的是 current->comm，所以显示成 binder:497_3（该服务的 autosuspend 线程是从
 binder 线程 fork 的，Linux 线程继承 comm）。不是直接写 /sys/class/rtc/rtc0/wakealarm，而是内核 alarmtimer→rtc_timer_start 路径。
它也不是"定时"重写——只在每次进 suspend 的瞬间执行一次，目的是把 RTC 编程给 AlarmManager 的下一个闹钟

根因：使用 命令设置 `/sys/class/rtc/rtc0/wakealarm` 时并没有被改写，系统正常触发  rtc唤醒后， 因为 sleep 10 在 suspend 
期间不走时，而且进程会被冻结，此时没有任何wakelock 锁， SystemSuspend HAL快速使系统再次进入休眠，并将rtc 时间设为下一次
alarmtimer 触发时间。所以主要原因其实是sleep 使脚本无法往下走拿锁，导致很快进入休眠。

## 解决方法

1. 使用C语言实现
用你的 rtc_wakeup_tool.c。它用 timerfd_create(CLOCK_REALTIME_ALARM)，read() 阻塞在 timerfd 上；
alarmtimer 到期时内核会唤醒系统并让 read() 返回——阻塞点本身就被 RTC 唤醒解开了，这是正确的等待方式。脚本只负责 input keyevent。
```C
void set_wake_lock(const char* lock_name, int acquire) {
    const char* path = acquire ? "/sys/power/wake_lock" : "/sys/power/wake_unlock";
    FILE *fp = fopen(path, "w");
    if (fp != NULL) {
        fprintf(fp, "%s", lock_name);
        fclose(fp);
    }
}

// 检查屏幕是否处于关闭状态
int is_screen_off() {
    char buffer[128];
    int screen_off = 0;
    // 执行 dumpsys 并抓取状态行
    FILE *fp = popen("dumpsys display | grep 'mScreenState='", "r");
    if (fp == NULL) return 0;

    if (fgets(buffer, sizeof(buffer), fp) != NULL) {
        // 如果字符串中包含 OFF，说明屏幕是灭的
        if (strstr(buffer, "OFF") != NULL) {
            screen_off = 1;
        }
    }
    pclose(fp);
    return screen_off;
}

int main(int argc, char *argv[]) {
    struct itimerspec utmr;
    // 使用 CLOCK_REALTIME_ALARM 确保硬件唤醒
    int tfd = timerfd_create(CLOCK_REALTIME_ALARM, 0);
    int timesec = 10;
    const char* MY_LOCK = "screen_test_lock";
    
    if (argc == 2)
	timesec = atoi(argv[1]);
    printf("每%d秒执行休眠唤醒\n", timesec);

    if (tfd == -1) {
        perror("timerfd_create 失败，检查内核支持情况");
        return 1;
    }

    while (1) {
        // 1. 执行切换屏幕 (直接调用 shell 命令)
	set_wake_lock(MY_LOCK, 1);
	if (is_screen_off()) {
        	system("input keyevent 26");
		sleep(1);
		system("input keyevent 82");
	}

	sleep(timesec);
        // 2. 配置定时器：6 秒后触发
        struct timespec now;
        clock_gettime(CLOCK_REALTIME, &now);

	
        utmr.it_value.tv_sec = now.tv_sec + timesec;
        utmr.it_value.tv_nsec = now.tv_nsec;
        utmr.it_interval.tv_sec = 0; // 不自动重复，我们手动控制循环
        utmr.it_interval.tv_nsec = 0;

        if (timerfd_settime(tfd, TFD_TIMER_ABSTIME, &utmr, NULL) == -1) {
            perror("timerfd_settime 失败");
            break;
        }

	set_wake_lock(MY_LOCK, 0);
	if (!is_screen_off()) {	
            system("input keyevent 26");
	}

        // 3. 阻塞在这里，直到闹钟触发
        uint64_t expirations;
        ssize_t s = read(tfd, &expirations, sizeof(uint64_t));
        if (s != sizeof(uint64_t)) {
            perror("read timerfd 错误");
        }
    }

    close(tfd);
    return 0;
}
```

2. 使用轮询方式判断是否已唤醒
不用sleep ,rtc 唤醒后 wakealarm 的值会清空，通过持续判断这个值，直到唤醒时再往下走。
`while [ -n "$(cat /sys/class/rtc/rtc0/wakealarm)" ]; do sleep 0.2; done`

3. 使用dmesg 模拟阻塞读
>shell 里有没有类似 read() 的阻塞方法？

没有 timerfd，inotifyd 也不行（sysfs 不支持 inotify）。但有一个内核级真正阻塞的读可以用：/dev/kmsg。

toybox 的 dmesg -w 就是打开 /dev/kmsg 后阻塞 read()（external/toybox/toys/lsb/dmesg.c：fd=open("/dev/kmsg", O_RDONLY ... !FLAG(w))）；
内核 devkmsg_read 里是 wait_event_interruptible(log_wait, ...)（kernel-6.6/kernel/printk/printk.c:833）——真正的阻塞等待，没有定时器、没有"剩余时间"。

而 RTC 闹钟触发时内核一定会打印：
```txt
rtc_mt6358: alarm time is up
...
Resume caused by IRQ 357, mt6358-rtc
```

所以可以这样"阻塞等 RTC"：
```bash
dmesg -C >/dev/null                                   # 先清空，否则旧记录会立刻命中
echo 0 > /sys/class/rtc/rtc0/wakealarm
echo $(( $(date +%s) + 12 )) > /sys/class/rtc/rtc0/wakealarm
echo test > /sys/power/wake_unlock                    # 允许挂起

dmesg -w | grep -m1 "alarm time is up"                # ← 阻塞在 read()，RTC 触发时才返回

echo test > /sys/power/wake_lock                      # 醒来第一件事抢锁
input keyevent 26
```

这比轮询稳定，因为：
- 进程是阻塞在 read() 的 waiter，挂起期间被冻结，resume/thaw 时被内核的日志记录直接唤醒，没有 0.5s 要重新累计；
- RTC 一到点就打印，命中即返回，不依赖运气式的轮询节拍。
