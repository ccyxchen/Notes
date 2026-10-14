# (176条消息) Linux休眠与唤醒---wakelock唤醒锁与autosleep功能使用_面朝大海0902的博客-CSDN博客_linux 唤醒锁

**一、Linux系统休眠**
 在嵌入式设备中由于省电功耗等原因我们需要让系统在不忙的时候进入休眠模式，Linux pm core提供给我们wakelock及autoslepp内核休眠机制。
 autosleep 和 wakelock是并行存在，只有 wakelock 唤醒锁全部释放且 autosleep 为 enable 时候系统才能进入休眠；

**二、autosleep功能**
 节点路径为/sys/power/autosleep，该值为mem表示打开autoslepp功能，如果值为off表示关闭。
 如果没有此节点路径，我们需要在内核配置打开autosleep功能的宏控。
 /*面朝大海0902*/

**三、wakelock唤醒锁使用及查看**
 **Kernel wakelock 使用方法：**
 Step1， 初始化
 wake_lock_init(&wake_lock, WAKE_LOCK_SUSPEND, “name”);

Step2， 加锁
 wake_lock(&wake_lock); //与 wake_unlock 成对使用， lock 后系统不允许休眠
 wake_lock_timeout(&wake_lock, msecs_to_jiffies(timeout)); //超时锁， 超时时间到后自动释放

Step3， 解锁
 wake_unlock(&wake_lock); //unlock 后系统允许休眠

**app wakelock 使用方法：**
 Step1， 加锁
 write_lockfile("/sys/power/wake_lock", “wakelock_name”);

Step2， 解锁
 write_lockfile("/sys/power/wake_unlock", “wakelock_name”);

设置超时锁
 static void wake_timeout_lock(char \*lockname, ULONG interval);
 /*面朝大海0902*/

**查看当前系统持锁情况：**
 如果系统未休眠，按照上面说的内容肯定是当前系统有持锁，我们需要查看系统持锁情况，使用如下命令
 **awk ‘$6 != 0 {print $1" "$6}’ /sys/kernel/debug/wakeup_sources**
 该命令实际就是打印出wakeup_sources节点下active_since项为非0的锁的名称，如下

```c
~ # awk '$6 != 0 {print $1" "$6}' /sys/kernel/debug/wakeup_sources
name active_since
dwc_otg_pm 4442570
```

表示当前USB持锁导致系统未进入休眠模式。
 /*面朝大海0902*/
