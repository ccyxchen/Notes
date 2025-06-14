# 内存不足导致的IO hang
![](vx_images/42416144837065.png =695x)
T302上遇到SWT/hang的集中报，MMC的请求量远超过平均吞吐量，看下这类问题要怎么排查
![](vx_images/130675882488755.png =1129x)

 T302项目SWT的DB里平台新增了一个文件SYS_PERFETTO，之前的SYS_FTRACE内容是空的了

ulldump
当无法runtime设置和提取trace时，这种往往在问题复现概率不高，无法有人值守的情况下采用，将ftrace block的配置信息写在init.rc中，在出现问题后通过fulldump提取block trace来分析，这是一个例子：

on init
        mkdir /sys/kernel/tracing/instances/block
        write /sys/kernel/tracing/instances/block/buffer_size_kb 10240
        write /sys/kernel/tracing/instances/block/events/block/block_rq_issue/enable 1
            write /sys/kernel/tracing/instances/block/events/block/block_rq_complete/enable 1
        write /sys/kernel/tracing/instances/block/tracing_on 1
编译版本，重新刷机后block trace应该默认会打开。

注意：必须开启fulldump，必须保存vmlinux，fulldump +vmlinux才能有效提取block trace，如何从fulldump中提取出trace请参考`[FAQ34807] [debug][ftrace] 如何从fulldump中提取trace`。

memory report里看，zram用完了，swapfree最少的时候用到0了
![](vx_images/509153846512766.png =940x)
![](vx_images/23596729240532.png =961x)

pgsteal_kswapd/s,pgsteal_file/s的曲线
![](vx_images/113493600130050.png =961x)

 com.topwar.gp起来后，突然占用了大量的内存

03-08 03:23:51.189   375   375 I killinfo: [19728,10114,905,0,35700,1,66560,365400,23976,1736,15984,5532,1610324,0,305968,248344,112700,233168,69700,210004,45792,70084,0,0,11936,0,4,0,0,42864,710680,4,4,12.100000,9.490000,25.700001,14.940000,13.480000]

03-08 03:34:13.437  1200  1228 E Watchdog: **SWT happen **Blocked in monitor com.android.server.am.ActivityManagerService on monitor thread (watchdog.monitor) for 156s, Blocked in handler on foreground thread (android.fg) for 272s, Blocked in handler on main thread (main) for 318s, Blocked in handler on ui thread (android.ui) for 318s, Blocked in handler on ActivityManager (ActivityManager) for 318s
最后一行kill_info是03-08 03:23:51，
swt发生的时间是   03-08 03:34:13
这中间Lowmemorykiller就没有再杀过进程了，
这个白名单的日志一直在打
03-08 03:36:25.417   375   375 E lowmemorykiller: ymx add lmkd-whitelist:pkgname=com.tinno.autotesttool
03-08 03:36:25.560   375   375 E lowmemorykiller: ymx add lmkd-whitelist:pkgname=com.tinno.autotesttool
03-08 03:36:25.568   375   375 E lowmemorykiller: ymx add lmkd-whitelist:pkgname=com.tinno.autotesttool
03-08 03:36:25.704   375   375 E lowmemorykiller: ymx add lmkd-whitelist:pkgname=com.tinno.autotesttool
03-08 03:36:25.838   375   375 E lowmemorykiller: ymx add lmkd-whitelist:pkgname=com.tinno.autotesttool
03-08 03:36:26.005   375   375 E lowmemorykiller: ymx add lmkd-whitelist:pkgname=com.tinno.autotesttool
03-08 03:36:26.184   375   375 E lowmemorykiller: ymx add lmkd-whitelist:pkgname=com.tinno.autotesttool
03-08 03:36:26.353   375   375 E lowmemorykiller: ymx add lmkd-whitelist:pkgname=com.tinno.autotesttool
03-08 03:36:26.544   375   375 E lowmemorykiller: ymx add lmkd-whitelist:pkgname=com.tinno.autotesttool
03-08 03:36:26.653   375   375 E lowmemorykiller: ymx add lmkd-whitelist:pkgname=com.tinno.autotesttool
03-08 03:36:26.881   375   375 E lowmemorykiller: ymx add lmkd-whitelist:pkgname=com.tinno.autotesttool

梦鑫改的代码影响到lmkd继续找别的进程查杀了
![](vx_images/293704062871603.png =961x)
![](vx_images/360145152942785.png =768x)
hang的kernel堆栈跟SWT里kernel日志Show block status打出来的状态一致，大量的进程阻塞在filemap_fault->folio_wait_bit_common里了
 [21403.291088] [ T1228]  io_schedule+0x38/0x78
[21403.291098] [ T1228]  folio_wait_bit_common+0x2b4/0x408
[21403.291108] [ T1228]  filemap_fault+0x3b0/0x7e4
[21403.291119] [ T1228]  __do_fault+0xc8/0xfc
[21403.291131] [ T1228]  handle_mm_fault+0x4c0/0x1c40
[21403.291143] [ T1228]  do_page_fault+0x1f8/0x48c
[21403.291155] [ T1228]  do_translation_fault+0x38/0x54
[21403.291167] [ T1228]  do_mem_abort+0x58/0x118

这个pgsteal_kswapd/pgsteal_file是比较典型的Lmkd不工作，纯靠kernel机制回收内存的攀升曲线
![](vx_images/444246897442304.png =912x)

active/inactive的曲线相背的剧烈变动

https://docs.kernel.org/translations/zh_CN/accounting/psi.html
压力阻塞信息这个，也可以监控IO的压力数据

/proc/pressure/io这个节点写入 "full 250000 1000000"
/* 监控IO部分阻塞，监控时间窗口为1秒、阻塞门限为250毫秒。*/
