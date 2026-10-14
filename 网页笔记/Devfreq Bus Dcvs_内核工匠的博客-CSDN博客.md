# (176条消息) Devfreq Bus Dcvs_内核工匠的博客-CSDN博客

## 一、引言

计算机的世界里，CPU任务分为CPU bound和IO bound。而实际场景下往往是两者混合型任务。针对性能的优化，普遍关注点都在CPU上(不论是CPU的频点和CPU的选核), 往往忽略对IO bound的任务的优化。而DDR作为SOC芯片代码运行空间和数据缓存空间，在不同应用状态下，SOC对DDR访问的带宽需求不一样。譬如听音乐时访问带宽需求较小，此时DDR工作在较低的频率，而通过网络信号观看高清视频时，则对带宽需求较大。DDR则需要提高工作频率。由此可见，SOC需要根据系统的运行情况动态调整DDR的总线工作频，以提高CPU工作效率，并降低系统在运行状态的功耗，达到性能功耗的平衡。

## 二、BUS DCVS

什么是BUS DCVS？

BUS DCVS，其 Bus Dynamic Clock and Voltage Scaling 的缩写，它是一种总线频率选择的算法，用于在动态的工作负载间选择最佳的频率点，以满足性能和功耗的平衡。

![0038c20b1eb2cb135317b685e52987a8.png](img/(176%E6%9D%A1%E6%B6%88%E6%81%AF)%20Devfreq%20Bus%20Dcvs_%E5%86%85%E6%A0%B8%E5%B7%A5%E5%8C%A0%E7%9A%84%E5%8D%9A%E5%AE%A2-CSDN%E5%8D%9A%E5%AE%A2-01.jpg)

先来看看现代SOC架构，对于DDR这个slave而言，其对应的master会很多，例如 CPU，GPU，NPU，DISPLAY，CAMERA 等等。每隔一段时间各个master就会给你自己对带宽的需求，最终由RPM汇总仲裁后设定最终的DDR频率。

本文主要介绍主流平台CPU的BUS DCVS策略

以上图所示架构，BUS DCVS主要是根据L2->L3，L3->system cache，System 和cache->DDR 等路径上对带宽的需求，选择最合适的频点以达到功耗和性能的平衡。

Bus DCVS 提供了2种调频策略

**1. bw_hwmon (bandwidth hardwaremonitor)**

基于CPU到cache 和 cache 到 DDR 的流量带宽调整cache 和 DDR的频率

**2. memlat(memory latency)**

基于 cache和 DDR 的 CPU 相关统计数据来调整相应频率。

## 三、BUS DCVS 软件架构

![245542e466d824b2637c28d1e9d9764e.png](img/(176%E6%9D%A1%E6%B6%88%E6%81%AF)%20Devfreq%20Bus%20Dcvs_%E5%86%85%E6%A0%B8%E5%B7%A5%E5%8C%A0%E7%9A%84%E5%8D%9A%E5%AE%A2-CSDN%E5%8D%9A%E5%AE%A2-02.jpg)

BUS DCVS分为3个大部分

**1. User space (用户空间)**

表现形式为sysfs 节点。路径为/sys/class/devfreq/soc\*ddr-bw和/sys/class/devfreq/soc\*ddr-lat（分别对应2种不同的策略方式）。当然还有devfreq的标准节点，min_freq/max_freq/cur_freq。用户空间的软件可以通过访问对应的文件获取当前master 对 DDR的带宽需求。如果具有某些权限，设置可以通过设置相应的参数来控制当前master 对 DDR 带宽需求的策略

**2. Kernel space（内核空间）**

CPU 的BUS DCVS与其他的非CPUFreq调频的外设一样，是基于devfreq 框架的一套机制。其核心为devfreq framework，设备的抽象为bimc-bwmon 和[arm](https://so.csdn.net/so/search?q=arm&spm=1001.2101.3001.7020)-memlat-mon，策略的抽象为governor bw_hwmon 和 memlat。

**3. RPM OS**

其主要作用是手机各个master voted的ddr 带宽，最终设定DDR的频率到LPDDR的硬件上。

## 四、bw_hwmon策略

**1. 源码路径**

a) drivers/devfreq/devfreq_devbw.c

b) drivers/devfreq/bimc-bwmon.c

c) driver/devfreq/governor_bw_hwmon.c

d) arch/arm64/boot/dts/vendor/qcom/

**2. bw_hwmon软件框图**

![380694ed2fdebeea957c7c75eabe0d24.png](img/(176%E6%9D%A1%E6%B6%88%E6%81%AF)%20Devfreq%20Bus%20Dcvs_%E5%86%85%E6%A0%B8%E5%B7%A5%E5%8C%A0%E7%9A%84%E5%8D%9A%E5%AE%A2-CSDN%E5%8D%9A%E5%AE%A2-03.jpg)

bw_hwmon策略涉及到的模块大致分为 devbw，bimc-bwmon，和devfreq framework。

a) bimc-bwmon：其代表代表 BIMC带宽监视器的设备，可用于测量来自 BIMC 主端口的读/写流量的带宽。

b) devbw：master对ddr slave的带宽需求

c) devfreq framework：非 CPU 设备的通用动态电压和频率缩放 (DVFS) 框架bw_hwmon调频策略的触发时机

d) 根据时间片轮询查看单位时间窗口的平均带宽

e) 根据配置带宽上升下降的阈值作为触发点，一旦在单位时间内上升或者下降过快，则触发中断通知更新频率

基于上述的触发时机，bimc-bwmon收到硬件监测到的带宽信息，根据软件的计算规则，预估需要调整的带宽，将其下发至devbw匹配OPP表，将需要的频率通过RPM驱动发送到RPM core，根据多个master对带宽的需求最终决策DDR需求的频率。

**3. 初始化流程**

a) bimc-bwmon驱动通过设备名”qcom,bimc-bwmon[0-4]”匹配到对应的devicetree中的硬件信息，获取中断号，获取控制器的版本，针对不同功能的控制器进行初始化。然后调用register_bw_hwmon初始化devfreq_governor类，并赋值其函数指针get_target_freq和event_handler，最终通过devfreq_add_governor注册到devfreq framework。

![6df076d1d3a25bfe67e4cdc33aa8f622.png](img/(176%E6%9D%A1%E6%B6%88%E6%81%AF)%20Devfreq%20Bus%20Dcvs_%E5%86%85%E6%A0%B8%E5%B7%A5%E5%8C%A0%E7%9A%84%E5%8D%9A%E5%AE%A2-CSDN%E5%8D%9A%E5%AE%A2-04.jpg)

b) devbw驱动通过如下设备名”qcom,devbw\*”匹配到对应的devicetree中的硬件信息,初始化devbw 设备的信息dev_data类，并将其设置为driver的私有数据。设置devfreq framework结构的devfreq_dev_profile中的target 和 get_dev_status函数及polling_ms的初始值。

![a7532c56afc481d15dc6dae21de95399.png](img/(176%E6%9D%A1%E6%B6%88%E6%81%AF)%20Devfreq%20Bus%20Dcvs_%E5%86%85%E6%A0%B8%E5%B7%A5%E5%8C%A0%E7%9A%84%E5%8D%9A%E5%AE%A2-CSDN%E5%8D%9A%E5%AE%A2-05.jpg)

同时设置设备的OPP表(OPP表的代码以DTS的形式表现)。

![6aff37a5a1c7d8fe660830a509c5672c.png](img/(176%E6%9D%A1%E6%B6%88%E6%81%AF)%20Devfreq%20Bus%20Dcvs_%E5%86%85%E6%A0%B8%E5%B7%A5%E5%8C%A0%E7%9A%84%E5%8D%9A%E5%AE%A2-CSDN%E5%8D%9A%E5%AE%A2-06.jpg)

![3f27529e0e4d6ea2eec00d35055279df.png](img/(176%E6%9D%A1%E6%B6%88%E6%81%AF)%20Devfreq%20Bus%20Dcvs_%E5%86%85%E6%A0%B8%E5%B7%A5%E5%8C%A0%E7%9A%84%E5%8D%9A%E5%AE%A2-CSDN%E5%8D%9A%E5%AE%A2-07.jpg)

最终通过devfreq_add_device将devbw 设备添加到devfreq framework的devfreq list链表中。此时会与devfreq governor建立两者的联系。

c) 当event_handler收到GOV_START信号以后，start_monitor 会注册中断函数，此中断就对应上升下降阈值的触发时机。如果有设置polling_ms则会queue_delayed_work 更新频率。

![07a63cad92a2f2041080199821f15a84.png](img/(176%E6%9D%A1%E6%B6%88%E6%81%AF)%20Devfreq%20Bus%20Dcvs_%E5%86%85%E6%A0%B8%E5%B7%A5%E5%8C%A0%E7%9A%84%E5%8D%9A%E5%AE%A2-CSDN%E5%8D%9A%E5%AE%A2-08.jpg)

**4. 频率调整流程**

![9ea6e988a98c4915bb212560b04680c0.png](img/(176%E6%9D%A1%E6%B6%88%E6%81%AF)%20Devfreq%20Bus%20Dcvs_%E5%86%85%E6%A0%B8%E5%B7%A5%E5%8C%A0%E7%9A%84%E5%8D%9A%E5%AE%A2-CSDN%E5%8D%9A%E5%AE%A2-09.jpg)

如上图所示为devfreq framework的通用的更新外设频率的流程

updatedevfreq 为核心函数，其流程如下

- 通过get_target_freq重新评估需要的频率
- 通过get_cur_freq获取当前的频率，如果实现此接口，则使用上次的频率作为当前频率
- 最后通过target 函数指针调用设置硬件的clock

其中get_target_freq 函数指针对应的函数就是bus dcvs的策略算法实现，此处为devfreq_bw_hwmon_get_freq，其本质就是get_bw_and_set_irq函数。

![01e0a0c54a3bfce43446d13630ae57ff.png](img/(176%E6%9D%A1%E6%B6%88%E6%81%AF)%20Devfreq%20Bus%20Dcvs_%E5%86%85%E6%A0%B8%E5%B7%A5%E5%8C%A0%E7%9A%84%E5%8D%9A%E5%AE%A2-CSDN%E5%8D%9A%E5%AE%A2-10.jpg)

**5. get_bw_and_set_irq**

此策略中的变量参数比较多，但是本质上最基本的计算方式如下图所示

![8c9e4d39782b06928b58eead5c57b883.png](img/(176%E6%9D%A1%E6%B6%88%E6%81%AF)%20Devfreq%20Bus%20Dcvs_%E5%86%85%E6%A0%B8%E5%B7%A5%E5%8C%A0%E7%9A%84%E5%8D%9A%E5%AE%A2-CSDN%E5%8D%9A%E5%AE%A2-11.jpg)

AB：平均需求的带宽

IB：瞬时需求的带宽

a) guard_band_mbps：基于性能的目的引入guard_band，在投票之前为measured_mbps += guard_band_mbps，为了解决带宽更新不及时导致的问题

b) decay_rate：此参数的范围为0-100，如果设置为100则不考虑历史的影响。且只有在当前测量值比上一次需求带宽小的情况才生效，用于避免频率更新后的乒乓性。

c) bw_step：类似取整的参数，用于降低更新频率的频繁性。

d) io_percent：用于计算IB，CPU的执行过程是一部分时间在访存，一部分时间在执行。相当于设定访存所占时间的百分比。

## 五、memlat策略

**1.源码路径**

a) drivers/devfreq/devfreq_devbw.c

b) drivers/devfreq/arm-memlat-mon.c

c) driver/devfreq/governor_memlat.c

d) arch/arm64/boot/dts/vendor/qcom/

**2.memlat软件架构**

Gover normemlat 是对 bw_hwmon机制的补充，主要对应memory latency sensitivity的任务

![83a7ec8a7c7353f9bd00ac54837df23b.png](img/(176%E6%9D%A1%E6%B6%88%E6%81%AF)%20Devfreq%20Bus%20Dcvs_%E5%86%85%E6%A0%B8%E5%B7%A5%E5%8C%A0%E7%9A%84%E5%8D%9A%E5%AE%A2-CSDN%E5%8D%9A%E5%AE%A2-12.jpg)

![1588d00aca5e17cac8e1c023dc0467b9.png](img/(176%E6%9D%A1%E6%B6%88%E6%81%AF)%20Devfreq%20Bus%20Dcvs_%E5%86%85%E6%A0%B8%E5%B7%A5%E5%8C%A0%E7%9A%84%E5%8D%9A%E5%AE%A2-CSDN%E5%8D%9A%E5%AE%A2-13.jpg)

memlat策略涉及到的模块大致分为 devbw，memlat-mon，和devfreq framework。

1) memlat-mon：其代表的是使用PMU来度量访存延时的设备。

2) devbw：master对ddr slave的带宽需求。

3) devfreqframework：非 CPU 设备的通用动态电压和频率缩放 (DVFS) 框架。

**3. 初始化流程**

a) 设备dts信息

![d1aad309dd44699086c1e53ed8038d8d.png](img/(176%E6%9D%A1%E6%B6%88%E6%81%AF)%20Devfreq%20Bus%20Dcvs_%E5%86%85%E6%A0%B8%E5%B7%A5%E5%8C%A0%E7%9A%84%E5%8D%9A%E5%AE%A2-CSDN%E5%8D%9A%E5%AE%A2-14.jpg)

qcom,target-dev:此设备对应的master。

qcom,cachemiss-ev:测量的缓存未命中事件。

qcom,core-dev-table:CPU核心频率到所需带宽投票的映射表。

![8eba125d7b06391288abdfe2fda79124.png](img/(176%E6%9D%A1%E6%B6%88%E6%81%AF)%20Devfreq%20Bus%20Dcvs_%E5%86%85%E6%A0%B8%E5%B7%A5%E5%8C%A0%E7%9A%84%E5%8D%9A%E5%AE%A2-CSDN%E5%8D%9A%E5%AE%A2-15.jpg)

operating-points-v2:从master到slave的带宽OPP表。

b) arm-memlat-mon驱动通过设备名”qcom,arm-memlat\*”匹配到对应的devicetree中的硬件信息，获取miss_ev_id，并对相关结构体进行初始化。然后调用register_memlat初始化devfreq_governor类，并赋值其函数指针get_target_freq和event_handler，最终通过devfreq_add_governor注册到devfreq framework。

c) 同bw_hwmon策略一样，event_handle 收到GOV_START信号以后，调用start_hwmon对相关的events进行初始化，同时启动delayed work更新频率。

![57331bf7a6fd0b81005c3b6262a73c9d.png](img/(176%E6%9D%A1%E6%B6%88%E6%81%AF)%20Devfreq%20Bus%20Dcvs_%E5%86%85%E6%A0%B8%E5%B7%A5%E5%8C%A0%E7%9A%84%E5%8D%9A%E5%AE%A2-CSDN%E5%8D%9A%E5%AE%A2-16.jpg)

**4. 频率调整流程**

![e7babff172b641f47be7403175c8789b.png](img/(176%E6%9D%A1%E6%B6%88%E6%81%AF)%20Devfreq%20Bus%20Dcvs_%E5%86%85%E6%A0%B8%E5%B7%A5%E5%8C%A0%E7%9A%84%E5%8D%9A%E5%AE%A2-CSDN%E5%8D%9A%E5%AE%A2-17.jpg)

此策略的因子比较简单。在每次的时间周期内，统计PM Uevent获取的instructions count 和 L2miss rate，只有当inst / miss 小于ratioceil的时候才会触发更新频率。最终将需求的带宽频率调用devfreq_bw的set_bw函数设置到硬件。

## 六、总结

随着各大厂商对芯片性能功耗的极致优化，对于一些cpu stall的场景可以通过BUS DCVS更精细化的优化进行改善。最后祝愿各位在技术的道路上越走越远。

参考：

https://android.googlesource.com/kernel/msm

https://android.googlesource.com/kernel/msm-extra/devicetree/

https://blog.csdn.net/feelabclihu/article/details/105592301

![(176条消息) Devfreq Bus Dcvs_内核工匠的博客-CSDN博客-18](img/(176%E6%9D%A1%E6%B6%88%E6%81%AF)%20Devfreq%20Bus%20Dcvs_%E5%86%85%E6%A0%B8%E5%B7%A5%E5%8C%A0%E7%9A%84%E5%8D%9A%E5%AE%A2-CSDN%E5%8D%9A%E5%AE%A2-18.jpg)

**扫码关注** **“内核工匠”微信公众号** Linux 内核黑科技 | 技术文章 | 精选教程
