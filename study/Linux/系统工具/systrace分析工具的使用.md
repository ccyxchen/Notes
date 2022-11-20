# systrace安装和使用

google的网页工具[perfetto](https://ui.perfetto.dev/#!/record)有相同作用，不想使用命令行的可以用网页。

## 安装systrace

可以在[systrace](https://android.googlesource.com/platform/external/chromium-trace/+archive/master/catapult.tar.gz)下载,解压后运行`~/bin/catapult/systrace/bin/systrace`,这是一个python脚本，或者在[platform-tools](https://chromium.googlesource.com/android_tools/+archive/881586ca84f2fb8e82faa9c8d645416d175d0f01/sdk/platform-tools.tar.gz)下载。

## systrace的使用

典型命令：

```Shell
# 官方
systrace -o mynewtrace.html sched freq idle am wm gfx view binder_driver hal dalvik camera input res

# atrace 指令
systrace sched freq idle am wm gfx view binder_driver irq workq ss sync -t 10 -b 96000 -o full_trace.html

# 查看已连接设备支持的类别列表
systrace --list-categories

# 简单的
systrace -t 10 -o full_trace.html
```

### 网页打开错误解决

在[chrome trace网页](chrome://tracing/)中打开

参考：

1. [在命令行上捕获系统跟踪记录](https://developer.android.com/topic/performance/tracing/command-line?hl=zh-cn)
2. [系统跟踪概览](https://developer.android.com/topic/performance/tracing?hl=zh-cn)
3. [捕获设备上的系统跟踪记录](https://developer.android.com/topic/performance/tracing/on-device?hl=zh-cn)
4. [浏览 Systrace 报告](https://developer.android.com/topic/performance/tracing/navigate-report?hl=zh-cn)
5. [性能与功耗](https://developer.android.com/topic/performance?hl=zh-cn)

## 通过atrace抓取systrace

参考：

[使用 ftrace](https://source.android.com/devices/tech/debug/ftrace?hl=zh-cn)
