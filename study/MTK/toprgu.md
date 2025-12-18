# toprgu
**TOPRGU（Top Reset Generation Unit）** 是常见于 **MediaTek（联发科）SoC** 中的一块系统级硬件模组，属于 **系统电源/重启控制逻辑的一部分**。它负责整个芯片的 **全局复位管理**，包含不同来源的复位信号、看门狗重启、异常重启记录等。

下面是更完整的说明：

---

# 🔧 **TOPRGU 是什么硬件？**

TOPRGU = **Top Reset Generation Unit**
它是 SoC 里的 **顶层复位控制单元**，通常包含以下功能：

### ✅ **1. 全局 Reset 信号产生**

* 管理 SoC 的 **全局硬件复位**
* 负责 CPU 子系统与外围模块的 reset source 分配
* 可触发 warm reset / cold reset

---

### ✅ **2. Watchdog Timer（WDT）管理**

在 MTK SoC（如手机、IoT 芯片）里，TOPRGU 通常与 WDT 深度整合，用来：

* 让系统通过 WDT 触发重启
* 防止系统死机
* 管理 WDT 超时行为

---

### ✅ **3. Reset Source 记录**

TOPRGU 会记录：

* Watchdog reset
* Power-key reset
* Software reset
* Low-power reset
* PMIC reset

软件可读这些寄存器来判断系统重启的原因。

---

### ✅ **4. 配合 PMIC（电源管理芯片）控制系统开关机**

TOPRGU 通常与 PMIC 协作：

* 处理 power-on sequence
* 管理 shutdown / reboot 流程

---

### 常见寄存器例子（以 MTK 为例）

* `RGU_WDT_MODE`
* `RGU_WDT_STATUS`
* `RGU_RESET_STAT`
* `RGU_WDT_SWRST`

这些寄存器都属于 TOPRGU 模块。

---

# 📌 **总览（一句话总结）**

**TOPRGU 是 SoC 中负责“全局复位生成 + 看门狗控制 + 重启原因记录”的核心硬件模块。**

---

如果你告诉我你使用的是 **哪一款 SoC（例如 MT6739、MT7622、MT8183、MTXXXX）**，我可以给你该芯片中 TOPRGU 的具体架构图、寄存器说明与相关软件初始化流程。
