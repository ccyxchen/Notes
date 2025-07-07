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

### 调用系统关机接口
有几种不同的情况会调用关机接口
1、上层应用或按电源键关机
发送关机 Intent
```java
Intent intent = new Intent(Intent.ACTION_REQUEST_SHUTDOWN);
intent.putExtra(Intent.EXTRA_KEY_CONFIRM, true); // 显示确认对话框
startActivity(intent);
```
![应用实现关机的流程](vx_images/328444944298500.png =1186x)
默认处理者：ShutdownActivity（系统应用，位于 
frameworks/base/packages/SystemUI/src/com/android/systemui/shutdown/ShutdownActivity.java）。

调用链：
ShutdownActivity 接收 ACTION_REQUEST_SHUTDOWN Intent。
根据 EXTRA_KEY_CONFIRM 决定是否显示用户确认对话框。
用户确认后，调用 ShutdownThread.run()。
```java
//system/frameworks/base/core/java/com/android/internal/app/ShutdownActivity.java
//接收Intent，判断是关机还是重启，并获取reason值
Intent intent = getIntent();
        mReboot = Intent.ACTION_REBOOT.equals(intent.getAction());
        mConfirm = intent.getBooleanExtra(Intent.EXTRA_KEY_CONFIRM, false);
        mUserRequested = intent.getBooleanExtra(Intent.EXTRA_USER_REQUESTED_SHUTDOWN, false);
        final String reason = mUserRequested
                ? PowerManager.SHUTDOWN_USER_REQUESTED
                : intent.getStringExtra(Intent.EXTRA_REASON);

 Thread thr = new Thread("ShutdownActivity") {
            @Override
            public void run() {
            //获取PowerManagerService的接口类
                IPowerManager pm = IPowerManager.Stub.asInterface(
                        ServiceManager.getService(Context.POWER_SERVICE));
                try {
                    if (mReboot) {
                      //调用PowerManagerService的reboot 和 shutdown函数
                        pm.reboot(mConfirm, "ShutdownActivity reboot device.", false);
                        /* @}*/
                    } else {
                        pm.shutdown(mConfirm, reason, false);
                    }
                } catch (RemoteException e) {
                }
            }
        };               

//system/frameworks/base/services/core/java/com/android/server/power/PowerManagerService.java
public void reboot(boolean confirm, @Nullable String reason, boolean wait) {
            try {
                shutdownOrRebootInternal(HALT_MODE_REBOOT, confirm, reason, wait);
            } finally {
                Binder.restoreCallingIdentity(ident);
            }
}

public void shutdown(boolean confirm, String reason, boolean wait) {
    try {
                shutdownOrRebootInternal(HALT_MODE_SHUTDOWN, confirm, reason, wait);
            } finally {
                Binder.restoreCallingIdentity(ident);
            }
}

private void shutdownOrRebootInternal(final @HaltMode int haltMode, final boolean conf
    Runnable runnable = new Runnable() {
            @Override
            public void run() {
                synchronized (this) {
                    if (haltMode == HALT_MODE_REBOOT_SAFE_MODE) {
                        ShutdownThread.rebootSafeMode(getUiContext(), confirm);
                    } else if (haltMode == HALT_MODE_REBOOT) {
                    //调用ShutdownThread的接口
                        ShutdownThread.reboot(getUiContext(), reason, confirm);
                    } else {
                        ShutdownThread.shutdown(getUiContext(), reason, confirm);
                    }
                }
            }
        };

```
执行流：
startActivity(intent)->ShutdownActivity.run()->PowerManagerService.reboot/shutdown->
ShutdownThread.reboot/shutdown->ShutdownThread.shutdownInner
->ShutdownThread.beginShutdownSequence->ShutdownThread.run-> 
ShutdownThread.rebootOrShutdown->PowerManagerService.lowLevelReboot/lowLevelShutdown->
SystemProperties.set("sys.powerctl", "reboot," + reason)/
SystemProperties.set("sys.powerctl", "shutdown," + reason + chargeTypeString);

可以看到这种方式最终是通过设置sys.powerctl来执行重启/关机的。

### 设置sys.powerctl实现的关机重启

在系统开机init 进程的SecondStage中，执行SecondStageMain函数会进入死循环，该循环会
检测shutdown_command 是否被设置，shutdown_command 就是在sys.powerctl设置后会初始化。
```c++
//system/system/core\init\init.cpp
int SecondStageMain(int argc, char** argv) {

    //设置了trigger_shutdown函数变量
    trigger_shutdown = [](const std::string& command) { shutdown_state.TriggerShutdown(command); };

    while (true) {
        auto shutdown_command = shutdown_state.CheckShutdown();
        if (shutdown_command) {
            LOG(INFO) << "Got shutdown_command '" << *shutdown_command
                      << "' Calling HandlePowerctlMessage()";
            HandlePowerctlMessage(*shutdown_command);
        }
      }
}
//检查do_shutdown_判断是否关机/重启
std::optional<std::string> CheckShutdown() __attribute__((warn_unused_result)) {
    if (do_shutdown_ && !IsShuttingDown()) {
            do_shutdown_ = false;
            return shutdown_command_;
        }
        return {};
}

//设置shutdown_command_
//ShutdownState.TriggerShutdown
void TriggerShutdown(const std::string& command) {
 shutdown_command_ = command;
        do_shutdown_ = true;
        WakeMainInitThread();
}
   
/*
 * 在 Property属性被改变后，会调用PropertyChanged，当判断Property是sys.powerctl，就会设置
 * shutdown_command_
 */
void PropertyChanged(const std::string& name, const std::string& value) {
     // If the property is sys.powerctl, we bypass the event queue and immediately handle it.
    // This is to ensure that init will always and immediately shutdown/reboot, regardless of
    // if there are other pending events to process or if init is waiting on an exec service or
    // waiting on a property.
    // In non-thermal-shutdown case, 'shutdown' trigger will be fired to let device specific
    // commands to be executed.
    if (name == "sys.powerctl") {
        trigger_shutdown(value);
    }
}

//core\init\reboot.cpp
//关机重启的最终实现是在HandlePowerctlMessage中
void HandlePowerctlMessage(const std::string& command) {
    
    if (userspace_reboot) {
        HandleUserspaceReboot();
        return;
    }
     ActionManager::GetInstance().ClearQueue();
    // Queue shutdown trigger first
    //这里会发送shutdown事件，触发init.rc 中定义的shutdown动作。
    //在shutdown执行完后就会执行shutdown_handler中的DoReboot完成最终的重启/关机
    ActionManager::GetInstance().QueueEventTrigger("shutdown");
    // Queue built-in shutdown_done
    auto shutdown_handler = [cmd, command, reboot_target, run_fsck](const BuiltinArguments&) {
        DoReboot(cmd, command, reboot_target, run_fsck);
        return Result<void>{};
    };
    ActionManager::GetInstance().QueueBuiltinAction(shutdown_handler, "shutdown_done");

    EnterShutdown();
}

static void DoReboot(unsigned int cmd, const std::string& reason, const std::string& reboot_target,
                     bool run_fsck) {
    RebootSystem(cmd, reboot_target, reason);
    abort();
}

//core\init\reboot_utils.cpp
//这个函数实现系统最终的关机或重启，通过调用c库函数 reboot(RB_POWER_OFF); 实现关机，
//该函数会调用Linux下的kernel_power_off函数关机。
//调用 __NR_reboot系统调用实现重启。
void __attribute__((noreturn))
RebootSystem(unsigned int cmd, const std::string& rebootTarget, const std::string& reboot_reason) {
     switch (cmd) {
        case ANDROID_RB_POWEROFF:
            reboot(RB_POWER_OFF);
            break;

        case ANDROID_RB_RESTART2:
            syscall(__NR_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2,
                    LINUX_REBOOT_CMD_RESTART2, rebootTarget.c_str());
            break;

        case ANDROID_RB_THERMOFF:
            if (android::base::GetBoolProperty("ro.thermal_warmreset", false)) {
                std::string reason = "shutdown,thermal";
                if (!reboot_reason.empty()) reason = reboot_reason;

                LOG(INFO) << "Try to trigger a warm reset for thermal shutdown";
                syscall(__NR_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2,
                        LINUX_REBOOT_CMD_RESTART2, reason.c_str());
            } else {
                reboot(RB_POWER_OFF);
            }
            break;
    }
    // In normal case, reboot should not return.
    PLOG(ERROR) << "reboot call returned";
    abort();
}
```
执行流：
PropertyChanged->TriggerShutdown->SecondStageMain->shutdown_state.CheckShutdown
->HandlePowerctlMessage->DoReboot->RebootSystem->reboot(关机)/__NR_reboot(重启)

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
目前上层对/proc/shutdown_detect的写入都是在上面2个文件中，其中reboot.cpp中都是在
DoReboot 函数，而ShutdownThread.java 是ShutdownThread.run().

从前面的关机流程可以知道，整个完整的执行过程是：
startActivity(intent)->ShutdownActivity.run()->PowerManagerService.reboot/shutdown->
ShutdownThread.reboot/shutdown->ShutdownThread.shutdownInner
->ShutdownThread.beginShutdownSequence->ShutdownThread.run-> 
ShutdownThread.rebootOrShutdown->PowerManagerService.lowLevelReboot/lowLevelShutdown->
SystemProperties.set("sys.powerctl", "reboot," + reason)/
SystemProperties.set("sys.powerctl", "shutdown," + reason + chargeTypeString);->
PropertyChanged->TriggerShutdown->SecondStageMain->shutdown_state.CheckShutdown
->HandlePowerctlMessage->DoReboot->RebootSystem->reboot(关机)/__NR_reboot(重启).

ShutdownThread.run会在DoReboot之前完成。

#### ShutdownThread.run中设置shutdown_detect的过程
```java
    public void run() {
    //run 运行时先直接设置为40
         if (sShutdownDetectEnabled && sUnisocShutdownThreadService != null) {
            //40:shutdown stage start, systemserver id
            sUnisocShutdownThreadService.doShutdownDetect("40");
        }
   /*
   *发送ACTION_SHUTDOWN广播，用于通知应用程序设备即将关机或重启。
   *当用户关机、重启或系统因某些原因（如低    电量）触发关闭时，系统会发送此广播。
   *Intent Action: Intent.ACTION_SHUTDOWN
   *发送时机: 在系统实际关闭之前发送，允许应用进行清理操作（如保存数据、关闭服务等）。
   *类型: 有序广播（Ordered Broadcast），系统会按优先级顺序传递给接收器。
   应用可以监听 ACTION_SHUTDOWN 广播，以执行以下操作：
保存用户数据（如未提交的编辑内容）。
关闭后台服务或释放资源。
记录日志或上报设备状态。
取消未完成的任务（如网络请求）。
*/
 Intent intent = new Intent(Intent.ACTION_SHUTDOWN);
        intent.addFlags(Intent.FLAG_RECEIVER_FOREGROUND | Intent.FLAG_RECEIVER_REGISTERED_ONLY);
        new IIntentReceiver.Stub() {
                    @Override
                    public void performReceive(Intent intent, int resultCode, String data,
                            Bundle extras, boolean ordered, boolean sticky, int sendingUser) {
                        Log.i(TAG, "receive shutdown broadcast, resultCode is " + resultCode
                                + ", ordered is " + ordered + ", sticky is " + sticky
                                + ", sendingUser is " + sendingUser);
                    //当广播被所有接收器处理完毕后，系统回调 performReceive()。    
                    mHandler.post(ShutdownThread.this::actionDone);
                    }
                }, null, UserHandle.USER_ALL, null, null, opts);
                
        synchronized (mActionDoneSync) {
            while (!mActionDone) {
                long delay = endTime - SystemClock.elapsedRealtime();
                if (delay <= 0) {
                   //shutdown广播的超时时间是10S，超时后就写入47 通知广播完成超时
                    if (sShutdownDetectEnabled && sUnisocShutdownThreadService != null) {
                        // 47:shutdown stage, shutdown broadcast timeout id
                        sUnisocShutdownThreadService.doShutdownDetect("47");
                    }
                    break;
                } else if (mRebootHasProgressBar) {
                    int status = (int)((MAX_BROADCAST_TIME - delay) * 1.0 *
                            BROADCAST_STOP_PERCENT / MAX_BROADCAST_TIME);
                    sInstance.setRebootProgress(status, null);
                }
                try {
                //设置wait 时间是500ms
                    mActionDoneSync.wait(Math.min(delay, ACTION_DONE_POLL_WAIT_MS));
                } catch (InterruptedException e) {
                }
            }
        }
        
    //执行activity manager的关机流程，am的关机超时是10S，超时会发送46
     long startAmDetectTime = SystemClock.elapsedRealtime();

        final IActivityManager am =
                IActivityManager.Stub.asInterface(ServiceManager.checkService("activity"));
       try {
                am.shutdown(MAX_BROADCAST_TIME);
        } catch (RemoteException e) {
        }
        ////执行package  manager的关机流程，am的关机超时是10S，超时会发送45
final PackageManagerInternal pm = LocalServices.getService(PackageManagerInternal.class);
        if (pm != null) {
            pm.shutdown();
        }
```

#### DoReboot中设置shutdown_detect 的过程
```C++
//* Reboot / shutdown the system.
// cmd ANDROID_RB_* as defined in android_reboot.h
// reason Reason string like "reboot", "shutdown,userrequested"
// reboot_target Reboot target string like "bootloader". Otherwise, it should be an empty string.
// run_fsck Whether to run fsck after umount is done.
//
static void DoReboot(unsigned int cmd, const std::string& reason, const std::string& reboot_target,
                     bool run_fsck) {
//开始执行时先解析reason,并根据cmd 类型判断是关机或重启
 if((cmd == ANDROID_RB_RESTART) || (cmd == ANDROID_RB_RESTART2)) {
        android::base::WriteStringToFile("30", "/proc/shutdown_detect");
    }else {
        android::base::WriteStringToFile("70", "/proc/shutdown_detect");
    }
    
//执行vold 关机流程，超时时间5S，超时发送32
 // 3. send volume abort_fuse and volume shutdown to vold
    Service* vold_service = ServiceList::GetInstance().FindService("vold");
    if (vold_service != nullptr && vold_service->IsRunning()) {
        // Manually abort FUSE connections, since the FUSE daemon is already dead
        // at this point, and unmounting it might hang.
        CallVdc("volume", "abort_fuse");
        CallVdc("volume", "shutdown");
        vold_service->Stop();
    } else {
        LOG(INFO) << "vold not running, skipping vold shutdown";
    }

//执行umount和fsck，超时5S，超时发送31
    UmountStat stat =
            TryUmountAndFsck(cmd, run_fsck, shutdown_timeout - t.duration(), &reboot_semaphore);
#ifdef SPRD_FEATURE_SHUTDOWN_DETECT
    android::base::WriteStringToFile("20", "/proc/shutdown_detect");
#endif

    RebootSystem(cmd, reboot_target, reason);
    abort();
}
```
