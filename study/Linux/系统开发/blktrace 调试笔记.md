# blktrace 调试笔记
## IO调试
在 Android 设备上遇到 ANR（Application Not Responding）且发现问题进程的 I/O 速率异常低时，可以通过以下 **Trace 工具** 和 **调试方法** 来定位问题根源（是 I/O 请求卡在系统层，还是 eMMC 处理命令变慢）：

---

### 一、关键 Trace 工具及调试方法
#### 1. **块层 I/O 跟踪 (`blktrace` + `blkparse`)**
   - **作用**：跟踪块设备层（Block Layer）的 I/O 请求下发和完成情况，确认是否存在 I/O 卡顿或延迟。
   - **步骤**：
     ```bash
     # 在 Android Shell 中执行（需 root）
     blktrace -d /dev/block/mmcblk0 -o trace &
     # 复现问题后终止 blktrace，导出 trace.blktrace.* 文件
     blkparse -i trace.blktrace.* > trace.log
     ```
   - **分析关键字段**：
     - `Q`（Queued）：I/O 请求进入队列的时间。
     - `D`（Dispatched）：请求下发到驱动层的时间。
     - `C`（Completed）：请求完成的时间。
     - **延迟计算**：`C - D` 的差值过大可能表明 eMMC 处理慢；`D - Q` 的差值过大可能表明系统调度或队列拥塞。

#### 2. **MMC 子系统 Trace（内核动态调试）**
   - **作用**：查看 eMMC 控制器处理的底层命令（CMD）和响应时间。
   - **步骤**：
     ```bash
     # 启用 MMC 调试日志（需 root 和内核支持）
     echo 'file mmc_* +p' > /sys/kernel/debug/dynamic_debug/control
     dmesg -w | grep mmc  # 实时查看 eMMC 命令日志
     ```
   - **关键信息**：
     - 命令类型（如 `CMD24` 写操作，`CMD18` 读操作）及响应时间。
     - 错误重试（如 `CMD retry`）或超时（`timeout`）事件。

#### 3. **Ftrace 跟踪调度延迟和 I/O 事件**
   - **作用**：结合内核事件（如调度、I/O 阻塞）分析进程卡顿原因。
   - **步骤**：
     ```bash
     # 启用 I/O 和调度相关事件（需 root）
     echo 1 > /sys/kernel/debug/tracing/events/block/enable
     echo 1 > /sys/kernel/debug/tracing/events/sched/enable
     # 开始记录
     echo 1 > /sys/kernel/debug/tracing/tracing_on
     # 复现问题后停止并导出
     cat /sys/kernel/debug/tracing/trace > ftrace.log
     ```
   - **关键事件**：
     - `block_rq_issue`：I/O 请求下发时刻。
     - `block_rq_complete`：I/O 请求完成时刻。
     - `sched_switch`：进程调度切换，检查是否有高优先级任务抢占或长时间运行的任务。

#### 4. **Android 专用工具（`systrace`/`perfetto`）**
   - **作用**：集成系统级 Trace（CPU、I/O、进程状态），可视化分析 ANR 时间点。
   - **步骤**：
     ```bash
     # 使用 perfetto 抓取 Trace（需 adb 调试）
     adb shell perfetto -o /data/misc/perfetto-traces/trace_file.perfetto-trace \
       -t 60s \
       --txt \
       -c - <<EOF
     buffers: { size_kb: 10000 }
     data_sources: {
       config { name: "linux.ftrace" 
         ftrace_config { 
           ftrace_events: "block_rq_issue"
           ftrace_events: "block_rq_complete"
           ftrace_events: "sched_switch"
           ftrace_events: "workqueue_execute"
         }
       }
     }
     EOF
     # 导出并使用 https://ui.perfetto.dev 分析
     ```
   - **分析重点**：
     - I/O 请求从下发到完成的延迟。
     - ANR 时间点附近是否有 I/O 阻塞或主线程等待。

---

### 二、针对两种可能原因的诊断方法
#### **假设 1：I/O 卡在系统层（正确下发但未完成）**
   - **验证方法**：
     1. 使用 `blktrace` 观察请求的 `D`（下发）和 `C`（完成）时间差。
     2. 检查 `dmesg` 是否有 I/O 错误日志（如 `I/O error`, `reset controller`）。
     3. 通过 `ftrace` 查看是否因锁竞争或调度延迟导致请求未完成。
   - **典型现象**：
     - `blktrace` 中 `D` 和 `C` 间隔极小，但请求在队列中停留时间（`Q` 到 `D`）过长。
     - 内核日志中出现 `hung task` 或 `soft lockup`。

#### **假设 2：eMMC 处理 CMD 变慢**
   - **验证方法**：
     1. 使用 `mmc-utils` 检查 eMMC 状态（擦写次数、健康度）。
       ```bash
       mmc extcsd read /dev/block/mmcblk0 | grep -E "LIFE_TIME|PRE_EOL_INFO"
       ```
     2. 通过 MMC 动态调试日志观察命令响应时间是否异常。
     3. 检查 `/sys/kernel/debug/mmcX/ios` 中的时钟频率和总线模式是否正常。
   - **典型现象**：
     - `blktrace` 中 `D` 到 `C` 的延迟显著增加。
     - MMC 日志中频繁出现 `CMD18/CMD24` 响应超时或重试。

---

### 三、其他优化和检查
1. **文件系统检查**：
   ```bash
   # 检查文件系统错误（需卸载分区）
   e2fsck -f /dev/block/mmcblk0pXX
   ```
2. **I/O 调度器调整**：
   ```bash
   cat /sys/block/mmcblk0/queue/scheduler  # 查看当前调度器
   echo "deadline" > /sys/block/mmcblk0/queue/scheduler  # 切换为低延迟调度器
   ```
3. **进程级 I/O 分析**：
   ```bash
   # 查看进程的 I/O 详情（需 root）
   pidstat -d -p <PID> 1  # 每秒统计一次
   ```

---

### 四、总结
- **优先使用 `blktrace` + `perfetto`**：快速定位 I/O 延迟发生在系统层还是硬件层。
- **内核日志 + MMC 调试**：直接验证 eMMC 命令处理是否异常。
- **结合场景**：若问题进程频繁读写小文件，可能是文件系统碎片或 eMMC 随机性能差；若读写大文件，需检查顺序吞吐量是否正常。

**注意**：部分调试需要内核支持（如 `CONFIG_MMC_DEBUG`、`CONFIG_BLK_DEBUG_FS`），若设备未开放权限，可尝试通过厂商提供的内核日志或性能工具分析。
