# Native hang机制
## kernel下的实现
Native hang驱动代码：
```C
//vendor\bsp\kernel5.15\kernel5.15\drivers\unisoc_platform\sysdump\hang_monitor.c
//创建驱动设备/dev/native_hang_monitor，用于设置超时时间
static int native_hang_init(void)
{
	/*	create /dev/native_hang_monitor */
｝

static struct miscdevice native_hang_monitor_dev = {
	.minor = MISC_DYNAMIC_MINOR,
	.name = "native_hang_monitor",
	.fops = &native_hang_monitor_fops,
};

static const struct file_operations native_hang_monitor_fops = {
	.owner = THIS_MODULE,
	.unlocked_ioctl = monitor_hang_ioctl,
#ifdef CONFIG_COMPAT
	.compat_ioctl = monitor_hang_ioctl,
#endif
};

//创建2个内核线程
//超时触发panic
	hd_thread = kthread_run(hang_detect_thread, NULL, "native_hang_detect");
//超时保存kernel log和关键Android服务堆栈
	hdinfo_thread = kthread_run(hang_detect_thread_info, NULL, "native_hang_detect_info");

//hang_detect_thread 会检查是否超时，如果超时就通知hang_detect_thread_info去保存log，然后睡眠
40S让log能保存，再触发panic.

//注册minidump log区域，用于保存上层堆栈信息
ret = minidump_save_extend_information("nhang", __pa(hang_info), __pa(hang_info + HANG_INFO_MAX));
//注册minidump log区域，用于保存kernel log
ret = minidump_save_extend_information("nh_log_buf", __pa(nh_log_buf), __pa(nh_log_buf + NH_LOGBUF_SIZE));
```

## android 实现
```java
//watchdog 代码
//system/vendor/sprd/platform/frameworks/base/services/core/java/com/android/server/UnisocWatchdogImpl.java
//设置超时时间
 public void writeWDTMonitor(int duration){

            if(sWatchdogOptimization.mHugeTaskRunning){
                duration = (int)sWatchdogOptimization.HUGETASK_DEFAULT_DUATION ;
                Slog.e(TAG,"WDT_Monitorwpp: writeWDTMonitor reduration(hugeTask)=" + duration);
            } else if(sWatchdogOptimization.checkIfVeryLowPerformance()){
                duration += Math.max(30,mNextNativeHangAddedValue);
                Slog.e(TAG,"WDT_Monitorwpp: writeWDTMonitor reduration(lowperformance)=" + duration);
            } else if (mNextNativeHangAddedValue > 0) {
                duration += mNextNativeHangAddedValue;
                Slog.e(TAG,"WDT_Monitorwpp: writeWDTMonitor reduration(busy)=" + duration);
            }
            try {
                openNativeHangMonitorFile();
                if(fdNativeHangMonitorFile != null && !shutdowning){
                    Os.ioctlInt(fdNativeHangMonitorFile,NativeHangMonitor_SS_WDT_CTRL_SET_PARA|0x30|(duration*64));
                }
            } catch (Exception e){
                //if write NativeHangMonitorFile failed, kernel native hang monitor may be triggered
                Slog.e(TAG,"WDT_Monitor: Failed to write native hang Monitor :"+e);
            }
        }
        
//消息函数更新超时
    public void  doEmergencyMessage(int messageId) {
        if (messageId == UNISOCWATCHDOG_MESSAGE_TIMER30) {
            //normal feeding
            sWDTHandler.writeWDTMonitor(WDTHandler.NativeHangMonitor_Duration_Normal);
            if (isDebug()) {
                updateNHAddedValue();
            }
        }else if (messageId >= UNISOCWATCHDOG_MESSAGE_WAITEDHALF1 &&
                messageId <= UNISOCWATCHDOG_MESSAGE_OVERDUE) {
            //feeding a long time watchdog to avoid timeout during HALF/OVERDUE
            sWDTHandler.writeWDTMonitor(3*WDTHandler.NativeHangMonitor_Duration_Normal);
        }
    }
     public void sendMessage(int messageId, int timeout){
        f(blocking && (timeout != 0)){
                sWDTHandler.writeWDTMonitor(WDTHandler.NativeHangMonitor_Duration_Normal);
                if(timeout < 0)
                    timeout = WDTHandler.NativeHangMonitor_Duration_Normal/2;
            }
     ｝
     
//创建实例
    public static UnisocWatchdog getInstance(Context context,ActivityManagerService activity) {
        if (null == sUnisocWatchdog) {
            sUnisocWatchdog = new UnisocWatchdogImpl(context,activity);
        }
        return sUnisocWatchdog;
    }
```

## Android中的watchdog实现
```Java
//system/frameworks/base/services/core/java/com/android/server/Watchdog.java

//创建sUnisocWatchdog
  public void init(Context context, ActivityManagerService activity) {
        mActivity = activity;
        context.registerReceiver(new RebootRequestReceiver(),
                new IntentFilter(Intent.ACTION_REBOOT),
                android.Manifest.permission.REBOOT, null);
        //Unisoc: initialize  UnisocWatchdog
        /** Unisoc: native hang watchdog
        * AR: AR.695.001080.003268.012033
        * method: modify directly
        * Unisoc Code @{
        */
        sUnisocWatchdog = UniSystemServiceFactory.getInstance().makeUnisocWatchdog(context,activity);
        /* @} */
    }
    
//在watchdog的run函数中，根据系统状态发送message 更新超时时间
 private void run() {
        boolean waitedHalf = false;

        while (true) {
            if(sUnisocWatchdog != null){
                sUnisocWatchdog.doEmergencyMessage(UnisocWatchdog.UNISOCWATCHDOG_MESSAGE_TIMER30);
                sUnisocWatchdog.sendMessage(UnisocWatchdog.UNISOCWATCHDOG_MESSAGE_TIMER30,0);
            }else
                Slog.e(TAG,"sUnisocWatchdog not initialized ");
            /* @} */
            //根据watchdog 的状态更新UnisocWatchdog
              final int waitState = evaluateCheckerCompletionLocked();
                if (waitState == COMPLETED) {
                    // The monitors have returned; reset
                    waitedHalf = false;
                    continue;
                } else if (waitState == WAITING) {
                    // still waiting but within their configured intervals; back off and recheck
                    /** Unisoc: native hang watchdog
                    * AR: AR.695.001080.003268.012033
                    * method: modify directly
                    * Unisoc Code @{
                    */
                    if (sUnisocWatchdog != null)//Unisoc:
                        sUnisocWatchdog.sendMessage(UnisocWatchdog.UNISOCWATCHDOG_MESSAGE_WAITING,0);
                    /* @} */
                    continue;
                } else if (waitState == WAITED_UNTIL_PRE_WATCHDOG) {
                    if (!waitedHalf) {
                        Slog.i(TAG, "WAITED_UNTIL_PRE_WATCHDOG");
                        /** Unisoc: native hang watchdog
                        * AR: AR.695.001080.003268.012033
                        * method: modify directly
                        * Unisoc Code @{
                        */
                        if (sUnisocWatchdog != null)
                            sUnisocWatchdog.sendMessage(UnisocWatchdog.UNISOCWATCHDOG_MESSAGE_WAITEDHALF1,10);
                        /* @} */
                        waitedHalf = true;
                        // We've waited until the pre-watchdog, but we'd need to do the stack trace
                        // dump w/o the lock.
                        blockedCheckers = getCheckersWithStateLocked(WAITED_UNTIL_PRE_WATCHDOG);
                        subject = describeCheckersLocked(blockedCheckers);
                        pids = new ArrayList<>(mInterestingJavaPids);
                        doWaitedPreDump = true;
                    } else {
                        /** Unisoc: native hang watchdog
                        * AR: AR.695.001080.003268.012033
                        * method: modify directly
                        * Unisoc Code @{
                        */
                        if (sUnisocWatchdog != null)
                            sUnisocWatchdog.sendMessage(UnisocWatchdog.UNISOCWATCHDOG_MESSAGE_WAITEDHALF2,10);
                        /* @} */
                        continue;
                    }
                } else {
                    // something is overdue!
                    blockedCheckers = getCheckersWithStateLocked(OVERDUE);
                    subject = describeCheckersLocked(blockedCheckers);
                    allowRestart = mAllowRestart;
                    pids = new ArrayList<>(mInterestingJavaPids);
                }
```