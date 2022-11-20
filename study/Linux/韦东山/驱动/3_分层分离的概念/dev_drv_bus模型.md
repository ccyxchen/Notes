## 分层分离思想

1、在输入子系统中，系统将输入设备分离成device和handler2层，device中只做硬件相关操作，数据的处理由handler执行。这就是典型的分层分离思想。

2、 系统驱动有个总线-设备-驱动模型，其核心就是分层思想。bus层作为上层应用获取硬件数据的接口，其中有个常见的bus-platform。platform是系统抽象出来的一个总线类型，所有没有特定总线接口的硬件设备都可以设置为platform总线，常用的总线类型还有pci,mipi,i2c,spi等。

3、总线中有设备层（dev）和驱动层（drv），其中dev处理硬件信息，drv负责设备驱动的逻辑操作。可以认为dev只是提供了硬件信息，如寄存器，引脚等，这些也可以通过设备树提供。

4、dev和drv通过name属性值匹配，当二者的name相同时，加载后就会执行drv的probe函数，而在dev驱动卸载后，会调用drv的remove函数。

## dev_drv_bus实现的led驱动

```c
//向platform注册drv设备
/**
 *	platform_driver_register
 *	@drv: platform driver structure
 */
int platform_driver_register(struct platform_driver *drv)
    
/**
 *	platform_driver_unregister
 *	@drv: platform driver structure
 */
void platform_driver_unregister(struct platform_driver *drv)
    
//设置driver结构体
struct platform_driver led_driver = {
    //dev和drv匹配后会调用probe
	.probe		= led_probe,
    //dev卸载后调用remove
	.remove		= __devexit_p(led_drv_remove),
	.driver		= {
        //设置name，会和dev的name进行匹配
		.name	= "s3c-led",
	}
};

//获取dev的资源数据
/**
 *	platform_get_resource - get a resource for a device
 *	@dev: platform device
 *	@type: resource type
 *	@num: resource index
 */
struct resource *
platform_get_resource(struct platform_device *dev, unsigned int type,
		      unsigned int num)
    
//其他操作和普通字符设备驱动基本一致
```



```c
//向platform注册dev设备
//向platform总线注册dev
/**
 *	platform_device_register - add a platform-level device
 *	@pdev:	platform device we're adding
 *
 */
int platform_device_register(struct platform_device * pdev)

/**
 *	platform_device_unregister - unregister a platform-level device
 *	@pdev:	platform device we're unregistering
 *
 *	Unregistration is done in 2 steps. First we release all resources
 *	and remove it from the subsystem, then we drop reference count by
 *	calling platform_device_put().
 */
void platform_device_unregister(struct platform_device * pdev)
    
//设置device结构体
static struct platform_device led_device = {
    //和drv匹配的名字
	.name		= "s3c-led",
	.id		= 0,
    //设备资源
	.resource	= &led_resource,
	.num_resources	= ARRAY_SIZE(led_resource),
	.dev = {
        //卸载函数
		.release = led_release,
	},
};

//资源设置示例
static struct resource led_resource[] = {
	[0] = {
		.start	= GPFCON,
		.end	= GPFCON + 8 - 1,
		.flags	= IORESOURCE_MEM,
	},
	[1] = {
		.start	= 6,
		.end	= 6,
		.flags	= IORESOURCE_IO,
	},
};
```

