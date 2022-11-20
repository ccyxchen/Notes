## 下载最新内核源码
使用GitHub上的源码库
`git clone https://github.com/ccyxchen/linux.git`

## 编译内核
1、设置交叉编译
使用的交叉编译工具链是`gcc-arm-10.2-2020.11-x86_64-arm-none-linux-gnueabihf`
Makefile中设置
```xml
+ARCH		?= arm
+CROSS_COMPILE ?= arm-none-linux-gnueabihf-
```

2、使用s3c2440公板配置文件作为参考
`make s3c2410_defconfig`
其中包含大部分与s3c2410相识的主板配置，如Mini2440,SMDK2440,这里以SMDK2440为基础做更改
SMDK2440设置的晶振频率不正确，导致输出乱码，所以要在`arch/arm/mach-s3c/mach-smdk2440.c`设置时钟。
SMDK2440没有网络设备，这里要增加DM9000作为平台网络设备。
```c
s3c2440_init_clocks(12000000);

+/* DM9000AEP 10/100 ethernet controller */
+
+static struct resource smdk2440_dm9k_resource[] = {
+	[0] = DEFINE_RES_MEM(MACH_SMDK2440_DM9K_BASE, 4),
+	[1] = DEFINE_RES_MEM(MACH_SMDK2440_DM9K_BASE + 4, 4),
+	[2] = DEFINE_RES_NAMED(IRQ_EINT7, 1, NULL, IORESOURCE_IRQ
+						| IORESOURCE_IRQ_HIGHEDGE),
+};
+
+/*
+ * The DM9000 has no eeprom, and it's MAC address is set by
+ * the bootloader before starting the kernel.
+ */
+static struct dm9000_plat_data smdk2440_dm9k_pdata = {
+	.flags		= (DM9000_PLATF_16BITONLY | DM9000_PLATF_NO_EEPROM),
+};
+
+static struct platform_device smdk2440_device_eth = {
+	.name		= "dm9000",
+	.id		= -1,
+	.num_resources	= ARRAY_SIZE(smdk2440_dm9k_resource),
+	.resource	= smdk2440_dm9k_resource,
+	.dev		= {
+		.platform_data	= &smdk2440_dm9k_pdata,
+	},
+};
+
 static struct platform_device *smdk2440_devices[] __initdata = {
 	&s3c_device_ohci,
 	&s3c_device_lcd,
 	&s3c_device_wdt,
 	&s3c_device_i2c0,
 	&s3c_device_iis,
+	&smdk2440_device_eth,
 };
```

3、打开eabi接口支持
make menuconfig 设置支持arm eabi 

## uboot如何引导板子
### 通过机器码匹配相应主板
1、uboot中设置默认的machid
`set machid 163` smdk2440
`set machid 7cf` mini2440

2、通过machid传递给内核
3、内核匹配machid，找到主板的初始化结构体，并调用初始化函数

## 内核中machid处理流程
1、各主板的配置文件中，如`arch/arm/mach-s3c24xx/mach-smdk2440.c`，有如下对machine_desc结构体的定义，这个结构体就是各主板用来进行特定配置的。
```c
//arch/arm/mach-s3c24xx/mach-smdk2440.c
MACHINE_START(S3C2440, "SMDK2440")
	/* Maintainer: Ben Dooks <ben-linux@fluff.org> */
	.atag_offset	= 0x100,

	.init_irq	= s3c2440_init_irq,
	.map_io		= smdk2440_map_io,
	.init_machine	= smdk2440_machine_init,
	.init_time	= smdk2440_init_time,
MACHINE_END

//arch/arm/include/asm/mach/arch.h
/*
 * Set of macros to define architecture features.  This is built into
 * a table by the linker.
 */
#define MACHINE_START(_type,_name)			\
static const struct machine_desc __mach_desc_##_type	\
 __used							\
 __attribute__((__section__(".arch.info.init"))) = {	\
	.nr		= MACH_TYPE_##_type,		\
	.name		= _name,

#define MACHINE_END				\
};

/* 展开后就是 */
static const struct machine_desc __mach_desc_S3C2440	\
 __used							\
 __attribute__((__section__(".arch.info.init"))) = {	\
    //定义机器码，对应主板
	.nr		= MACH_TYPE_S3C2440,		\
	.name		= SMDK2440,
			\
    /* Maintainer: Ben Dooks <ben-linux@fluff.org> */
	.atag_offset	= 0x100,

	.init_irq	= s3c2440_init_irq,
	.map_io		= smdk2440_map_io,
	.init_machine	= smdk2440_machine_init,
	.init_time	= smdk2440_init_time,
};

//arch/arm/include/generated/asm/mach-types.h
#define MACH_TYPE_S3C2440              362
```

2、内核启动时，会判断machine_desc结构体中的nr成员是否与r1寄存器相等，若相等则使用此结构体进行后面的初始化工作，否则继续查找，如果没有匹配的machine_desc，则返回0报错。（看起来在kernel 5最新代码上已经不使用这种机制，待查看git记录后更新）