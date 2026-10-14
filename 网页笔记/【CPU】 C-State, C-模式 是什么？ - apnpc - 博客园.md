# 【CPU】 C-State, C-模式 是什么？ - apnpc - 博客园

[原文](https://www.dell.com/support/article/zh-cn/qna41893/%E4%BB%80%E4%B9%88%E6%98%AF-c-state?lang=zh)

为了在 CPU 空闲时节约能源，可以使用命令让 CPU 进入低功耗模式。每个 CPU 都有几种功耗模式，它们统称为“C-State”或“C-模式”。在本文中，我们将介绍这些模式的内容、具体操作方式及其对应的支持处理器。

低功耗模式是在486DX4处理器中首次引入的，所以这个概念远远谈不上创新。通过新模式的不断增强，CPU 的功耗也在进一步降低。

这些模式的工作原理是降低 CPU 内空闲单元的时钟信号和功率。通过降低时钟信号和电压停止（甚至完全关闭）的 CPU 单元越多，功耗就越低。但是，要从休眠模式中完全“唤醒”CPU，需要花费更长时间。

这些模式或“C-State”从 C0 开始，CO 表示“正常”的 CPU 运行模式（CPU 已 100% 激活）。C 后的数字越大，表示 CPU 进入休眠模式的程度越深。换言之，关闭的电路和时钟信号越多，完全唤醒 CPU 进入 C0 模式需要的时间越长。

每个 C-State 模式均有对应名称，其中一些模式根据节能级别和唤醒时间不同，还具有相应子模式。

下表汇总了当前可用的所有 C-State 模式。C1 到 C3 模式可通过降低 CPU 时钟信号来实现，而 C4 到 C6 模式则通过降低 CPU 电压来实现。而“增强”模式可以结合上述两种模式。

| Mode（模式） | 姓名 | 作用 | CPU |
| --- | --- | --- | --- |
| C0 | 操作状态 | CPU完全打开 | 所有CPU |
| C1 | 停止 | 通过软件停止 CPU 内部主时钟；总线接口单元和 APIC 仍然保持全速运行 | 486DX4及以上 |
| C1E | 增强型停止 | 通过软件停止 CPU 内部主时钟并降低 CPU 电压；总线接口单元和 APIC 仍然保持全速运行 | 所有socket 775 CPU |
| C1E | — | 停止所有CPU内部时钟 | Turion 64、65-nm Athlon X2和Phenom CPU |
| C2 | 停止授予 | 通过硬件停止 CPU 内部主时钟；总线接口单元和 APIC 仍然保持全速运行 | 486DX4及以上 |
| C2 | 停止时钟 | 通过硬件停止CPU内部和外部时钟 | 仅限486DX4、Pentium、Pentium MMX、K5、K6、K6-2、K6-III |
| C2E | 扩展的停止授予 | 通过硬件停止 CPU 内部主时钟并降低 CPU 电压； | 总线接口单元和 APIC 仍然保持全速运行 Core 2 Duo和更高版本（仅限Intel） |
| C3 | 睡眠 | 停止所有CPU内部时钟 | Pentium II、Athlon以上支持，但Core 2 Duo E4000和E6000上不支持 |
| C3 | 深度睡眠 | 停止所有CPU内部和外部时钟 | Pentium II以上支持，但Core 2 Duo E4000、E6000和Turion 64上不支持 |
| C3 | AltVID | 停止所有CPU内部时钟和降低CPU电压 | AMD Turion 64 |
| C4 | 更深入的睡眠 | 降低CPU电压 | Pentium M以上支持，但Core 2 Duo E4000、E6000和Turion 64上不支持 |
| C4E/C5 | 增强的更深入的睡眠 | 大幅降低CPU电压并关闭内存高速缓存 | Core Solo、Core Duo和45-nm移动版Core 2 Duo支持 |
| C6 | 深度电源关闭 | 将 CPU 内部电压降低至任何值，包括 0 V | 仅45-nm移动版Core 2 Duo支持 |

__EOF__

![【CPU】 C-State, C-模式 是什么？ - apnpc - 博客园-01](img/%E3%80%90CPU%E3%80%91%20C-State%2C%20C-%E6%A8%A1%E5%BC%8F%20%E6%98%AF%E4%BB%80%E4%B9%88%EF%BC%9F%20-%20apnpc%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-01.jpg)

本文作者

：

**[NPC](https://www.cnblogs.com/apnpc/p/13780146.html)**

本文链接

：

[https://www.cnblogs.com/apnpc/p/13780146.html](https://www.cnblogs.com/apnpc/p/13780146.html)

关于博主

：评论和私信会在第一时间回复。或者

[直接私信](https://msg.cnblogs.com/msg/send/apnpc)

我。

版权声明

：本博客所有文章除特别声明外，均采用

[BY-NC-SA](https://creativecommons.org/licenses/by-nc-nd/4.0/)

许可协议。转载请注明出处！

声援博主

：如果您觉得文章对您有帮助，可以点击文章右下角

**<span style="color:#ff0000">【推荐】</span>**

一下。您的鼓励是博主的最大动力！
