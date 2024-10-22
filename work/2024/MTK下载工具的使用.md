# 使用MTK下载工具的总结

## Download 原理

### USB comport Type

下载时需通过USB port来通信和download，MTK平台download时有两种usb com port

#### Bootrom comport

>* 手机在bootrom阶段枚举出的usb port，其PID/VID default 为0003/0E8D
>* 手机flash没有preloader的情况或者在手机有preloader的情况下通过KPCOL0 pin接地的方式会枚举出该com port

#### Preloader comport

>* 手机在preloader阶段枚举出的usb port，其PID/VID default为2000/0E8D
>* 手机flash上有preloader的情况，默认枚举出该com port，而不会枚举出bootrom usb port

#### DA（download agent）

>下载时运行在手机ram的一段代码，负责与PC tool通信并完成下载等相关操作。

#### Scatterfile

>存放在SW img中的一个配置文件，用于记录手机SW img下载相关信息

#### Download flow diagram

>brom/preloader枚举出usb port后，tool通过usb port和手机通信，把DA下载到手机ram并跳转执行DA
>DA先对手机硬件做初始化，然后循环接收PC cmd执行download等相关操作

下图为bootrom方式下载的框图
![1](/tmpimage/MTK下载工具的使用2024-08-05-10-26-50.png)

## MTK USB驱动枚举的端口

MTK 的soc芯片内运行有一个Boot rom 系统，该系统保存在片内rom区域，是无法修改的，且代码不开源。当主板中没有下载preloader时，默认上电或插入USB就会启动BROM，BROM的功能是下载软件或配合下载工具完成其他功能（如执行BROM适配器跑ETT bin程序）。

安装MTK的USB驱动后，该驱动能适配2种USB端口，一种是BROM中USB端口，一种是preloader中的USB端口。

1. 对于MTK默认的软硬件设计

   * 在机器关机或下电情况下，直接插USB线，会跑到preloader中，则电脑中端口就是preloader的枚举端口。
   * 按住power + 音量- 再接入USB线，会跑BROM程序，电脑中端口是BROM枚举的端口。

2. 对于Oplus的设计

   * 在机器关机或下电情况下，直接插USB线，会直接开机，不会枚举出下载端口。
   * 按住power + 音量+- 再接入USB线，会跑到preloader中，电脑中端口是preloader枚举的端口。
   * 强制下载点接地，会跑BROM程序，电脑中端口是BROM枚举的端口。
