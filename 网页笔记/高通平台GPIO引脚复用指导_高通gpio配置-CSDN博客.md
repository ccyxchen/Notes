# 高通平台GPIO引脚复用指导_高通gpio配置-CSDN博客

#### 高通平台GPIO引脚复用指导

- [1. 概述](https://blog.csdn.net/qq_42139745/article/details/134009430#1___8)
- [1.1 平台有多少个GPIO？](https://blog.csdn.net/qq_42139745/article/details/134009430#11_GPIO_9)[1.2 这些GPIO都有哪些可复用的功能？](https://blog.csdn.net/qq_42139745/article/details/134009430#12_GPIO_30)
- [2. 软件配置](https://blog.csdn.net/qq_42139745/article/details/134009430#2__41)
- [2.1 TZ侧GPIO配置](https://blog.csdn.net/qq_42139745/article/details/134009430#21_TZGPIO_43)[2.2 SBL侧GPIO配置](https://blog.csdn.net/qq_42139745/article/details/134009430#22_SBLGPIO_68)[2.3 AP侧GPIO配置](https://blog.csdn.net/qq_42139745/article/details/134009430#23_APGPIO_84)[2.3.1 Linux DTS机制与设备驱动模型概述](https://blog.csdn.net/qq_42139745/article/details/134009430#231_Linux_DTS_85)[2.3.2高通平台的pinctrl控制器](https://blog.csdn.net/qq_42139745/article/details/134009430#232pinctrl_95)[2.3.2.1 SDX12 CPU pinctrl](https://blog.csdn.net/qq_42139745/article/details/134009430#2321_SDX12_CPU_pinctrl_101)[2.3.2.2 PMD9655 pinctrl](https://blog.csdn.net/qq_42139745/article/details/134009430#2322_PMD9655_pinctrl_118)[2.3.2.3 sys文件节点来观察pinctrl](https://blog.csdn.net/qq_42139745/article/details/134009430#2323_syspinctrl_136) [2.3.3 GPIO如何进行复用？](https://blog.csdn.net/qq_42139745/article/details/134009430#233_GPIO_142)[2.3.3.1增加一个PIN脚用于按键功能](https://blog.csdn.net/qq_42139745/article/details/134009430#2331PIN_144)[2.3.3.2 增加一个PIN脚用于WIFI使能](https://blog.csdn.net/qq_42139745/article/details/134009430#2332_PINWIFI_163)[2.3.3.2 增加一个PIN脚用于电池电量ADC检测](https://blog.csdn.net/qq_42139745/article/details/134009430#2332_PINADC_181)[3.3.3.2.1 ADC通道配置](https://blog.csdn.net/qq_42139745/article/details/134009430#33321_ADC_182)[2.3.3.2.2 ADC功能复用](https://blog.csdn.net/qq_42139745/article/details/134009430#23322_ADC_218) [2.4 Modem侧GPIO配置](https://blog.csdn.net/qq_42139745/article/details/134009430#24_ModemGPIO_243)[2.4.1 GPIO配置](https://blog.csdn.net/qq_42139745/article/details/134009430#241_GPIO_245)[2.4.2GPIO API接口使用](https://blog.csdn.net/qq_42139745/article/details/134009430#242GPIO_API_256)

该文档以SDX12平台为例，介绍如何对高通平台的GPIO PIN脚功能进行软件配置。

| 术语 | 英文全名 | 中文解释 |
| --- | --- | --- |
| DTS | Device Tree Source | Linux用于描述硬件设备的数据结构。 |
| Pinctrl | Pin Controller | Linux 用于硬件引脚配置的驱动框架 |

## 1. 概述

### 1.1 平台有多少个GPIO？

在软件配置前需要先了解平台的GPIO引脚资源有哪些。如何获得这些信息？
 以SDX12平台为例，需要获取如下几个平台文档。

- 平台的原理图参考设计文档

该文档可以从高通网站下载，文档编号80-12402-41，文档名称 SDX12 PMD9655 Reference Schematic。从该文档中1.3章节系统框图可以知道，参考设计中SDX12通过SPMI总线连接和控制PMD9655的工作。

![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-01.jpg)

从该文档的1.4.17章节我们可以知道，电源管理芯片PMD9655提供了10个GPIO PIN脚。

![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-02.jpg)

从该文档的1.4.4章节，我们可以了解到SDX12 CPU内部提供100个GPIO PIN脚。

![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-03.jpg)

显然该平台总计提供了110个GPIO PIN脚，其中SDX12提供GPIO_0 ~ GPIO_99,PMD9655提供GPIO_01~GPIO_10.

### 1.2 这些GPIO都有哪些可复用的功能？

在讨论GPIO可复用功能前，需要先清楚这些GPIO的电气特性是什么样的？比如该GPIO是否可以作为模拟或者数字输入输出，当GPIO作为ADC PIN脚需要能够工作在模拟输入模式，当GPIO作为时钟 PIN脚需要能够工作在数字输出模式。比如GPIO的工作电压范围 1.2V、1.8V、3.0V，这个取决于该GPIO与哪个电源网络连接。这些信息需要查看平台的以下文档：

- data sheet文档，文档编号80-12402-1，文档名称 SDX12 Data Sheet. ![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-04.jpg) 截取上述文档一部分，用于说明每个GPIO PIN脚电气特性信息的来源，这个对于后面的软件配置非常重要。
- SDX12 GPIO PIN脚定义文档文档编号 80-12402-1A，文档名称 SDX12 Pin Assignment Spreadsheet，该文档中GPIO Configuration章节详细描述了GPIO_0~GPIO_99每个PIN脚的默认功能以及其他可复用的功能。 ![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-05.jpg)
- 电源管理芯片PMD9655 GPIO PIN脚定义.文档编号 80-P1085-1,文档名称PMD9655 Power Management Device Specification.

![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-06.jpg)

## 2. 软件配置

高通平台是一个多核非对称的SOC架构，不同的子系统运行着不同OS，对于GPIO引脚的控制各个子系统有着不同的配置方法。

### 2.1 TZ侧GPIO配置

高通平台对于低速外设的访问采用QUP(Qualcomm Universal Peripheral高通统一外设)配置，TrustZone(TZ)子系统管理者哪些子系统有权限访问哪些BLSP的QUP权限，换句话讲TZ管控这个各个子系统访问不同外设GPIO的权限。关于QUP的介绍的文档编号为：80-NU767-1,文档名称:BAM BLSP User Guide。
 SDX12配置位置为：

```bash
trustzone_images/core/buses/qup_accesscontrol/bear/config/QUPAC_9x55_Access.xml
```

目前平台相关常用的外设已经加入到该配置文件，一般不需要修改，如有特殊需求可参考如下说明。该文件修改完后，需要重新编译，再烧录devcfg.mbn镜像。

该配置文件节点说明如下：

![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-07.jpg)

- device id 是一个约定的好的节点别名，此处代表低速外设uart3
- CHIP_BUS_INDEX 是一个外设ID,可以选择的外设ID定义在./bear/inc/QupACCommonIds.h
- BUS_PROTOCOL 是一个协议ID,可以选择的协议ID定义在 ./bear/inc/TzBlspAC.h
- IS_GPIO_PROTECTED 表示该GPIO是否被保护，只有该GPIO被TZ子系统使用的时候，才需要启用保护
- GPIO_NUMBERS 当GPIO启用保护后，代表需要被保护的GPIO PIN脚
- SUBSYSTEM_ID 代表可以被哪个子系统访问，定义在./bear/inc/QupACCommonIds.h,可选参数有:AC_TZ,仅有TZ可以访问；AC_RPM，仅有RPM可以访问；AC_ADSP_Q6_ELF仅ADSP可以访问AC_HLOS,仅AP可以访问；AC_NONE，所有子系统都可以访问该外设的寄存器，仅AP可以访问外设BAM
- IS_PERSISTENT 设置为1代表该外设的配置不能够在运行时改变，如果需要运行时改变设置为0.

### 2.2 SBL侧GPIO配置

SBL作为bootloader用于引导加载AP侧镜像，在PBL之后初始化阶段运行，该阶段的[GPIO初始化](https://so.csdn.net/so/search?q=GPIO%E5%88%9D%E5%A7%8B%E5%8C%96&spm=1001.2101.3001.7020)配置位于：

`boot_images/core/systemdrivers/tlmm/config/mdm9x55/TLMMChipset.xml`

该配置文件将被/core/systemdrivers/tlmm/src/DALTLMM.c 中的DALTLMMState_Init 进行解析和配置。

![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-08.jpg)

该xml文件定义了GPIO_0~GPIO_99 100个GPIO在SBL阶段的初始配置，简要说明一下。

- GPIO方向：DALTLMM_INPUT代表配置为输入，DALTLMM_OUTPUT代表配置为输出。
- GPIO内部上下拉电阻配置：DALTLMM_PULL_UP 内部上拉，DALTLMM_PULL_DOWN代表内部下拉， DALTLMM_KEEPER 保持，一般用于GOIO作为输入时候的配置。
- GPIO输出：DALTLMM_OUT_HIGH输出高电平，DALTLMM_OUT_LOW输出低电平
- DALTLMM_PRG_YES or DALTLMM_PRG_NO,用于在SBL启动阶段,GPIO是否配置为低功耗模式。

### 2.3 AP侧GPIO配置

#### 2.3.1 Linux DTS机制与设备驱动模型概述

由于AP侧运行Linux 5.4内核，AP侧的GPIO配置需要遵循Linux 设备树DTS的规范以及Linux 设备驱动模型框架来进行相关的配置，这部分也是定制化程度较高的部分，本章节将深入展开讨论。

该章节需要对设备树DTS语法有一定的基础，该部分请参考[devicetree-specification](https://download.csdn.net/download/qq_42139745/88469714)。文档也可[devicetree](https://www.devicetree.org/)官网下载

另外需要对Linux platform 平台设备驱动框架有深入了解，DTS定义的设备最终都是通过platform设备驱动总线模型进行匹配的，同时需要对Linux pinctl 子系统与GPIO子系统有一定的认识，高通平台提供的驱动程序也都是基于上述两个子系统扩展而来。

DTS里面定义的设备节点最终都会通过 compatible兼容性属性通过platform总线驱动模型，在内核中匹配到对应的 platform_driver，本身被转换为 platform_device。platform_device 中含有 resource 数组, 它来自 device_node 的reg, interrupts 等属性。
 设备树的处理过程是： DTS ->dtb -> device_node -> platform_device

#### 2.3.2高通平台的pinctrl控制器

如下图是高通平台的一个CPU GPIO引脚内部的数字电路结构图，该PIN脚内部的功能通过芯片内部的pinctrl控制器来进行配置。

![在这里插入图片描述80-12402-5b_a_sdx12_chipset_–_architecture_and_digital_baseband_design_guidelines_training_slides(109页)](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-09.jpg)

Pinctrl控制器在软件中如何描述？需要通过设备树DTS来完成。从1.1章节我们了解到SDX12平台GPIO分别由SDX12 CPU和PMD9655两部分提供，所以在DTS里面也就定义了两个pinctrl控制器。

2.3.2.1 SDX12 CPU pinctrl

设备树源码位置：

```bash
apps_proc\vendor\qcom\proprietary\devicetree\qcom\sdxnightjar-pinctrl.dtsi
```

Pinctrl 控制器的设备树节点：

![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-10.jpg)

设备树中定义的设备最终都通过 compatible兼容性属性中定义的 "qcom,sdxnightjar-pinctrl"通过platform驱动设备总线模型找到他对应的内核驱动。

pinctrl@1000000控制器设备对应的驱动源码位于：

```bash
sdx12-ap/kernel/msm-5.4/drivers/pinctrl/qcom/pinctrl-sdxnightjar.c
```

2.3.2.2 PMD9655 pinctrl

设备树源码位置：

```bash
apps_proc\vendor\qcom\proprietary\devicetree\qcom\pmd9650.dtsi
```

Pinctrl 控制器的设备树节点：

![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-11.jpg)

设备树中定义的设备最终都通过 compatible兼容性属性中定义的 "qcom,pmd9650-gpio"通过platform驱动设备总线模型找到他对应的内核驱动。

pinctrl@c000控制器设备对应的驱动源码位于：

```bash
sdx12-ap/kernel/msm-5.4/drivers/pinctrl/qcom/pinctrl-spmi-gpio.c
```

2.3.2.3 sys文件节点来观察pinctrl

系统运行后从/sys/kernel/debug/pinctrl 这个节点也可以观察到，当前系统里面注册的两个pinctrl控制器。

![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-12.jpg)

上面是一个典型的DTS设备描述方式，由于pinctrl@c000的父节点是pmd9650@0，再上一层的设备节点是200f000.qcom,spmi，最终可以从DTS的根节点一路找到该设备。

#### 2.3.3 GPIO如何进行复用？

本章节将根据项目实际开发过程遇到的定制需求，来指导如何进行GPIO复用。

2.3.3.1增加一个PIN脚用于按键功能

实际项目开发过程有客户需要从模组空闲的PIN脚中找一个作为WIFI WPS按键功能来使用，结合客户的原理图，发现PCIE_EP_RESET_N 这个PIN脚客户没有使用，通过查询平台文档《SDX12 Pin Assignment Spreadsheet》发现该PIN脚对应的是GPIO_65，查询项目的设备树文件，发现该PIN脚未被使用过。

![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-13.jpg)

如何增加？首先与客户沟通了解到，当前客户使用的按键驱动为Linux 内核自带的gpio_keys驱动。在apps_proc/vendor/qcom/proprietary/devicetree/qcom/sdxnightjar.dtsi找到gpio_keys节点，修改补丁如下：

![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-14.jpg)

在gpio-keys节点增加一个子节点wps,该节点又如下几个属性。

- label = “wps” 取一个别名标识该节点
- gpios = <&tlmm_pinmux 65 1>，&tlmm_pinmux符合代表在tlmm_pinmux节点的基础上追加，tlmm_pinmux就是2.3.2.1中sdx12 CPU上pinctrl@1000000的别名，65 代表是该控制器的65 PIN，1代表低电平有效，既当GPIO_65为低电平时候代表按键按下。
- linux,input-type = <1>按键事件类型
- linux,code = <528> 该按键在input子系统中上报的key值
- debounce-interval = <15> 按键消抖时间15ms

上述DTS节点的信息为什么是这样解读的？这个完全是靠该设备对应的驱动程序进行的，通过属性compatible = "gpio-keys"可以找到该设备驱动位于./driver/input/keyboard/gpio_keys.c。设备树节点的解析通过驱动程序gpio_keys_get_devtree_pdata(struct device \*dev)接口来完成，然后通过接口gpio_keys_setup_key完成GPIO方向、中断申请的配置，最终完成input 设备的注册。

由于是个按键驱动，所以GPIO PIN脚肯定是作为一个输入来使用的，并且是要通过电平中断触发来上报。但是这些并没有体现在DTS配置中，这些已经通过内核的gpio_keys驱动框架实现了。

2.3.3.2 增加一个PIN脚用于WIFI使能

实际项目开发过程有客户需要从模组空闲的PIN脚中找一个作为WIFI PWR使能功能来使用，需要在wifi驱动加载的时候设置为高电平。高通参考设计是长供电的，结合客户的原理图，发现PMD9650 GPIO_07 这个PIN脚客户没有使用。

如何添加？首先找到在设备树中查找PMD9650 pinctrl控制器上面GPIO使用的情况。

![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-15.jpg)

如上图所示PMD9650 pinctrl控制器上面在该项目中使用GPIO_03用于LED灯控制，GPIO_08用于蓝牙复位控制。注意两处使用的地方都是通过“&pmd9650_gpios”来使用，pmd9650_gpios是PMD9650 pinctrl控制器的别名（标号），在PMD9650 DTS节点定义时候有说明：

![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-16.jpg)

然后找到WIFI驱动设备树节点，如下图增加一个GPIO控制节点，wlan-pwr-en-gpio。 WIFI驱动设备树文件位置：devicetree/qcom/sdxnightjar-cnss.dtsi

![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-17.jpg)

驱动中如何使用该GPIO控制呢？通过兼容性属性compatible = "qcom,cnss"可以在内核驱动源码找到该驱动位于：kernel/msm-5.4/drivers/net/wireless/cnss/cnss_pci.c。

驱动中增加一个接口cnss_configure_wlan_pwr_en_gpio用于gpio设备树解析、gpio申请、gpio配置。

![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-18.jpg)

2.3.3.2 增加一个PIN脚用于电池电量ADC检测

3.3.3.2.1 ADC通道配置

实际项目开发过程有客户需要从模组空闲的PIN脚中找一个作为ADC检测功能使用用于电池ID检测，从1.2章节中PMD9650 spec文档中3.7.1了解到，GPIO_02,GPIO_04,GPIO_06,GPIO_10四个引脚可以作为ADC检测功能进行复用。

![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-19.jpg)

在进行ADC配置前，需要先了解下高通平台PMIC ADC基本的工作原理，参考文档编号 80-P0711-23,文档名称PMIC ADC Software.

![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-20.jpg)

高通ADC控制器是一个可编程的非常灵活的框架，可以配置不同的GPIO引脚内部与ADC控制器连接，ADC内部上拉电阻可以根据需要灵活配置为open、30K、100K、400K，ADC采样范围也可以进行1/3缩放配置应对高电压测量。

这些不同的配置，已经通过硬件channel来区分，软件的配置只需要根据(80-P1085-1)下面表格中不同的channel ID来进行读取。

![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-21.jpg)

表格中前两列代表，不同的配置索引，Source列代表该配置行对应的外部哪路PIN脚作为ADC测量，Scaling列代表缩放范围，Internal pull-up列代表内部上拉电阻的可配置范围。结合客户硬件原理图设计，选取PMD9650 GPIO_02 PIN脚接到电池ID上面，作为ADC功能使用，测量电池ID电压。

软件上面首先在设备树中找到PMD9650 ADC控制器，文件源码地址：

```bash
apps_proc\vendor\qcom\proprietary\devicetree\qcom\pmd9650.dtsi
```

![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-22.jpg)

从兼容性属性compatible = “qcom,spmi-adc-rev2”，我们可以从内核驱动源码中找到PMD9650 ADC控制器驱动程序位于：

```bash
kernel/msm-5.4/drivers/iio/adc/qcom-spmi-adc5.c
```

下面ADC控制器新增的DTS设备节点信息，都要依据qcom-spmi-adc5驱动。增加GPIO_02 ADC配置DTS节点信息：

![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-23.jpg)

- reg寄存器值配置为ADC5_GPIO2，注意DTS中也有宏定义语法，定义在头文件qcom,spmi-vadc.h，ADC5_GPIO3值为0X13,从驱动程序中调用adc5_get_dt_channel_data接口进行进一步的解析，reg解析后最终作为硬件的channel ID,然后驱动软件通过iio总线进行ADC值获取。 ![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-24.jpg) 总结一下上面DTS配置就是选择0X13这个配置，ADC输入来自GPIO_02引脚，无内部上拉，输出无缩放。

2.3.3.2.2 ADC功能复用

由于GPIO_02要用作ADC功能，所以需要在PMD9650 pinctrl控制器中进行PIN脚功能复用的配置。
 关于PMD9650详细的GPIO DTS配置，官方的参考文档在如下位置：
 apps_proc\vendor\qcom\proprietary\devicetree\bindings\pinctrl\qcom,pmic-gpio.txt.
 该文档是结合pinctrl-spmi-gpio驱动来对DTS 配置参数进行说明，主要有如下几个方面：

| 属性 | 取值类型 | 定义描述 |
| --- | --- | --- |
| Pins | string-array | 列举使用到的pin脚名称 |
| Function | String | 复用功能，可选值"normal","func1"等,具体见PMIC spec |
| bias-disable | None | 内部无上下拉 |
| bias-pull-down | None | 内部下拉 |
| bias-pull-up | None | 内部上拉 |
| bias-high-impedance | None | 内部高阻态 |
| output-high | None | 输出为高 |
| output-low | None | 输出为低 |
| power-source | U32 | 特殊pin脚可以选择电源类型，具体见：dt-bindings/pinctrl/qcom,pmic-gpio.h |
| qcom,drive-strength | U32 | pin脚的驱动强度，具体见：dt-bindings/pinctrl/qcom,pmic-gpio.h |

按照高通文档说明，GPIO作为ADC时候，需要配置为高阻态。GPIO ADC pin脚定义地方：

![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-25.jpg)

GPIO ADC pin脚使用的地方，在oem_bms这个子节点下面，增加了adc2这个节点，用于iio驱动通过PMD9650 ADC控制器下面的ADC5_GPIO02通道读取GPIO 2PIN脚的ADC电压采样值。

![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-26.jpg)

oem_bms 驱动会解析“adc2”这个节点，最终把电池ID adc channel与该节点关联，最终注册到内核驱动的power_supply子系统，通过工作队列完成电池信息的ADC采样。

### 2.4 Modem侧GPIO配置

Modem 侧高通有一套独立的GPIO配置框架和GPIO使用指导，文档编号80-NL239-3， 文档名称Modem Subsystem GPIO Software

#### 2.4.1 GPIO配置

以SDX12平台为例，modem侧GPIO PIN脚配置在如下xml文件：

```bash
/modem_proc/core/systemdrivers/tlmm/config/sdx12/PlatformIO_MDMX_ROUTER.xml
```

![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-27.jpg)

- name 标签，代表PIN脚名称，这个依据参考文档2，后面modem侧软件获取gpio ID需要name参数。
- Type 标签，“{a,b}”a代表GPIO的编号；b代表复用功能编号，这个也已经参考文档2，0代表function 0 既GPIO功能，1代表function1功能，依次类推。

#### 2.4.2GPIO API接口使用

高通平台在modem侧通过硬件抽象层HAL屏蔽一些硬件差异，通过设备抽象层DAL提供统一的API接口用于GPIO控制。API接口定义位于：

```bash
modem_proc\core\api\systemdrivers\DDITlmm.h
```

![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-28.jpg)

DAL GPIO接口说明:

| 接口 | 说明 |
| --- | --- |
| DAL_DeviceAttach | 创建一个PIN脚管理的句柄 |
| DAL_DeviceDetach | 释放PIN脚管理的句柄 |
| DalTlmm_GetGpioId | 获取GPIO 描述符 |
| DalTlmm_ConfigGpioId | GPIO PIN脚配置 |
| DalTlmm_SelectGpioIdMode | GPIO 模式配置 |
| DalTlmm_GpioIdOut | GPIO 输出设置 |
| DalTlmm_ReleaseGpioId | 释放GPIO 描述符 |
| DAL_DeviceDetach | 释放PIN脚管理句柄 |

![在这里插入图片描述](img/%E9%AB%98%E9%80%9A%E5%B9%B3%E5%8F%B0GPIO%E5%BC%95%E8%84%9A%E5%A4%8D%E7%94%A8%E6%8C%87%E5%AF%BC_%E9%AB%98%E9%80%9Agpio%E9%85%8D%E7%BD%AE-CSDN%E5%8D%9A%E5%AE%A2-29.jpg)
