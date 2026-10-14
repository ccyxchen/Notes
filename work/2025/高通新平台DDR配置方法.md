# 高通新平台DDR配置方法

高通在新平台上 XBL不开源，xbl的二进制程序存放在
`nonhlos/BOOT.MXF.2.0/boot_images/boot/QcomPkg/SocPkg/Netrani/Bin/LAA/RELEASE/sign/xbl_sc.elf`
如果更新了xbl_sc.elf，重新编译xbl后，需要烧录xbl_s.melf xbl_config.elf shrm.elf

新平台上通过 eCDT 修改  DDR参数，并编译进xbl_config.elf中。

## 使用QDUTT修改eCDT

从 QPM安装 QDUTT
![](vx_assets/db5cf09a-532f-4700-b09a-1d288ec602c6/274468238791867.png =1007x)

下面以SM7435为例修改eCDT, 实现降频
打开QDUTT，target 选择对应的芯片平台，选eCDT
![](vx_assets/db5cf09a-532f-4700-b09a-1d288ec602c6/424008466706825.png =577x)

SM7435支持LPDDR5和LPDDR4，以LP4为例，点击open选择源码中高通已有的eCDT json文件.
`nonhlos/BOOT.MXF.2.0/boot_images/boot/QcomPkg/SocPkg/Netrani/Settings/DSF/release/target/Netrani/LPDDR4X/ECDT.json`
一般高通的eCDT 中有针对某些厂商DDR的配置，我们修改eCDT 只需要在高通eCDT基础上新增
自己的配置就行。

![](vx_assets/db5cf09a-532f-4700-b09a-1d288ec602c6/545108165408504.png =387x)
![](vx_assets/db5cf09a-532f-4700-b09a-1d288ec602c6/138529402813256.png =833x)

以降频到1708MHz为例，选择Override Type的 Disable Frequency项，勾选2092MHz禁用这个频率，再点OK生效。
Manufacture ID这些都不设置，表示对所有的DDR都生效。
![](vx_assets/db5cf09a-532f-4700-b09a-1d288ec602c6/196483011859984.png =824x)
点击Save 生成 eCDT和 xbl_config.elf
![](vx_assets/db5cf09a-532f-4700-b09a-1d288ec602c6/533230926088004.png =828x)

选eCDT bin再点OK，会生成eCDT.json和 eCDT bin,其中  eCDT bin包括ECDT_POST_DEVICE_INIT.bin和
ECDT_PRE_DEVICE_INIT.bin 这2个文件，eCDT bin 用于生成 DCT文件，源码中是通过 DCT文件将eCDT编译
进xbl_config.elf的。
![](vx_assets/db5cf09a-532f-4700-b09a-1d288ec602c6/352544253765109.png =572x)

选xbl config elf 可以生成xbl_config.elf和 eCDT bin
 ![](vx_assets/db5cf09a-532f-4700-b09a-1d288ec602c6/203842225774675.png =577x)

其中红框中的3项是必须设置的，xbl_config.elf 是原始的elf 文件，可以选择 源码中编译生成的，
也可以用release 版本下的。
其中源码中路径位于
nonhlos\BOOT.MXF.2.0\boot_images\boot\QcomPkg\SocPkg\Netrani\Bin\LAA\RELEASE\xbl_config.elf

ddi和sectool 都是源码里的路径
ddi.py : nonhlos\BOOT.MXF.2.0\boot_images\boot\QcomPkg\Tools\DDI\ddi.py
sectools : nonhlos\Netrani.LA.2.5\common\sectoolsv2\ext

设置好后，点击ok,就会编译并生成新的 xbl_config.elf和 DCB bin

xbl_config.elf 位于 C:\Qualcomm\QDUTT\eCDT\SM7435_LP4\compose/xbl_config.elf
DCB bin位于  C:\Qualcomm\QDUTT\eCDT\SM7435_LP4\decompose 目录下
![](vx_assets/db5cf09a-532f-4700-b09a-1d288ec602c6/410783885513846.png =673x)

如果验证了 eCDT 的修改，需要放到源码里，就将上面生成的这几个DCB bin文件，把文件前面的 “_”去掉，
再替换源码中
`nonhlos/BOOT.MXF.2.0/boot_images/boot/QcomPkg/SocPkg/Netrani/Settings/DSF/release/target/Netrani`
下的同名文件，注意替换源码中的eCDT.json是不会生效的。

## 参考资料
1、qdutt 工具配置eCDT
[80-NR058-9_REV_K_QDUTT_ECDT_User_Guide.pdf](vx_attachments/232669499368520/80-NR058-9_REV_K_QDUTT_ECDT_User_Guide.pdf)
2、修改DDR频率方法
[KBA-250710005905_REV_1_Reduce_Ddr_frequence.pdf](vx_attachments/232669499368520/KBA-250710005905_REV_1_Reduce_Ddr_frequence.pdf)
3、新平台 xlb_sc 不开源说明
[KBA-211116202006_REV_3_How_to_upgrade_XBL_SC.pdf](vx_attachments/232669499368520/KBA-211116202006_REV_3_How_to_upgrade_XBL_SC.pdf)
