# i2c 超时的案例分析
## log分析
V871售后出现一台机器必须开机panic
```txt
[    6.010766][    C7] Kernel panic - not syncing: snd_soc_sprd_pa_aw87xxx.ko loads too long time, panic timeout = 2000 ms, loglevel = 4
[    6.012263][    C7] CPU: 7 PID: 567 Comm: android.hardwar Tainted: G           OE     5.15.149-android13-8-g881c88c00624-ab205 #1
[    6.013706][    C7] Hardware name: Unisoc UMS9621-base Board (DT)
[    6.014459][    C7] Call trace:
[    6.014847][    C7]  dump_backtrace.cfi_jt+0x0/0x8
[    6.015442][    C7]  dump_stack_lvl+0x80/0xb8
[    6.015981][    C7]  panic+0x190/0x44c
[    6.016444][    C7]  sprd_modules_exit+0x0/0x40 [native_hang_monitor]
[    6.017248][    C7]  call_timer_fn+0x58/0x248
[    6.017787][    C7]  expire_timers+0xd8/0x2ec
[    6.018327][    C7]  __run_timers+0x1c8/0x2b0
[    6.018866][    C7]  run_timer_softirq+0x3c/0x58
[    6.019436][    C7]  _stext+0x180/0x5f0
[    6.019911][    C7]  __irq_exit_rcu+0x5c/0x120
[    6.020460][    C7]  handle_domain_irq+0xdc/0x160
[    6.021041][    C7]  gic_handle_irq.35171+0x58/0x26c
```
是snd_soc_sprd_pa_aw87xxx.ko加载超时，PA芯片在小板上，怀疑是小板连接问题，但是使用正常机器拔除小板FPC
不会panic
```txt
# 正常拔除屏FPC的log
[    3.287339][T290@C5] [Awinic] [6-0058]aw87xxx_dev_get_chipid: [2] read low id is failed, ret=-5
[    3.289050][T290@C5] [Awinic] [6-0058]aw87xxx_dev_i2c_read_byte: i2c_read cnt=0 error=-5
[    3.299788][T290@C5] [Awinic] [6-0058]aw87xxx_dev_i2c_read_byte: i2c_read cnt=1 error=-5
[    3.299911][T85@C7] sprd-gnss:cali 12 time, value is 0x0
[    3.311584][T290@C5] [Awinic] [6-0058]aw87xxx_dev_i2c_read_byte: i2c_read cnt=2 error=-5
[    3.323538][T290@C5] [Awinic] [6-0058]aw87xxx_dev_i2c_read_byte: i2c_read cnt=3 error=-5
[    3.335504][T290@C5] [Awinic] [6-0058]aw87xxx_dev_i2c_read_byte: i2c_read cnt=4 error=-5
[    3.347334][T290@C5] [Awinic] [6-0058]aw87xxx_dev_get_chipid: [3] read low id is failed, ret=-5
[    3.348660][T290@C5] [Awinic] [6-0058]aw87xxx_dev_i2c_read_byte: i2c_read cnt=0 error=-5
[    3.363557][T290@C5] [Awinic] [6-0058]aw87xxx_dev_i2c_read_byte: i2c_read cnt=1 error=-5
[    3.375548][T290@C0] [Awinic] [6-0058]aw87xxx_dev_i2c_read_byte: i2c_read cnt=2 error=-5
[    3.387550][T290@C0] [Awinic] [6-0058]aw87xxx_dev_i2c_read_byte: i2c_read cnt=3 error=-5
[    3.390603][T166@C6] rstinfo: clear_resetinfo sucess!
[    3.399689][T290@C0] [Awinic] [6-0058]aw87xxx_dev_i2c_read_byte: i2c_read cnt=4 error=-5
[    3.407931][T85@C7] sprd-gnss:cali 11 time, value is 0x0
[    3.411461][T290@C0] [Awinic] [6-0058]aw87xxx_dev_get_chipid: [4] read low id is failed, ret=-5
[    3.412574][T290@C0] [Awinic] [6-0058]aw87xxx_dev_get_chipid: read low id is failed
[    3.413559][T290@C0] [Awinic] [6-0058]aw87xxx_dev_init: read chipid is failed,ret=-22
[    3.414541][T290@C0] [Awinic] [6-0058]aw87xxx_i2c_probe: pa init failed
```
可以看到aw87xxx_dev_get_chipid多次尝试读取失败，i2c_read也会多次报错，但是整个过程是很快完成，失败
后直接退出了probe，所以不会触发ko 超时panic（2S超时）

* 异常panic的I2C读：
```txt
[    4.923735][T295@C7] sprd-i2c 222a0000.i2c: addr: 0x58 dma transfertimeout!
[    4.924610][T295@C7] sprd-i2c 222a0000.i2c: I2C_CTL = 0x1c4106
[    4.925331][T295@C7] sprd-i2c 222a0000.i2c: I2C_ADDR_CFG = 0xb0
[    4.926062][T295@C7] sprd-i2c 222a0000.i2c: I2C_COUNT = 0x1
[    4.926752][T295@C7] sprd-i2c 222a0000.i2c: I2C_STATUS = 0x14201
[    4.927495][T295@C7] sprd-i2c 222a0000.i2c: ADDR_DVD0 = 0xc0012
[    4.928236][T295@C7] sprd-i2c 222a0000.i2c: ADDR_DVD1 = 0x0
[    4.928925][T295@C7] sprd-i2c 222a0000.i2c: ADDR_STA0_DVD = 0x24
[    4.929689][T295@C7] [Awinic] [6-0058]aw87xxx_dev_i2c_read_byte: i2c_read cnt=0 error=-110
```
异常时会打印 dma transfertimeout!，正常的没有，进一步对比代码
```C
static int sprd_i2c_dma_handle_msg(struct i2c_adapter *i2c_adap,
			       struct i2c_msg *msg, bool is_last_msg)
{
    ...
    //i2c wait completion的超时是1S
    i2c_time_left = wait_for_completion_timeout(&i2c_dev->complete,
				msecs_to_jiffies(I2C_DMA_XFER_TIMEOUT));
	dma_time_left = wait_for_completion_timeout(&i2c_dev->dma_complete,
				msecs_to_jiffies(DMA_XFER_TIMEOUT));

	sprd_i2c_clear_start(i2c_dev);
	sprd_i2c_enable_dma(i2c_dev, false);

	if (msg->flags & I2C_M_RD) {
		dma_unmap_single(i2c_dev->dev,
				i2c_dev->dma.dma_phys_addr,
				i2c_dev->count,
				DMA_FROM_DEVICE);
		i2c_put_dma_safe_msg_buf(dma_buf_read, msg, true);
	} else {
		dma_unmap_single(i2c_dev->dev,
				i2c_dev->dma.dma_phys_addr,
				i2c_dev->count,
				DMA_TO_DEVICE);
		i2c_put_dma_safe_msg_buf(dma_buf_write, msg, true);
	}

	if ((!i2c_time_left) || (!dma_time_left)) { 
		dev_err(i2c_dev->dev, "addr: 0x%x dma transfertimeout!\n", msg->addr);
		sprd_i2c_dump_reg(i2c_dev);
		if (i2c_dev->rst != NULL) {
			ret = reset_control_reset(i2c_dev->rst);
			if (ret < 0)
				dev_err(i2c_dev->dev, "i2c soft reset failed, ret = %d\n", ret);
		}
		return -ETIMEDOUT;
	}

	return i2c_dev->err;
}
```

可以看到是在等待DMA  传输完成超时了，而拔除FPC的I2C不通，不会走到I2C传输，所以不会卡住1S，
不会造成超时

对比error的返回值：
```txt
异常：
[    4.929689][T295@C7] [Awinic] [6-0058]aw87xxx_dev_i2c_read_byte: i2c_read cnt=0 error=-110
正常：
[    3.289050][T290@C5] [Awinic] [6-0058]aw87xxx_dev_i2c_read_byte: i2c_read cnt=0 error=-5
```
异常的error 值是ETIMEOUT ,正常是EIO，也能说明异常时I2C是通的但是卡主了。

进一步发现异常log整个I2C6 都是卡住的：
```txt
//FLASH
[    3.356365][T295@C6] sprd-i2c 222a0000.i2c: addr: 0x63 dma transfertimeout!
[    3.357244][T295@C6] sprd-i2c 222a0000.i2c: I2C_CTL = 0x1c4106
[    3.357965][T295@C6] sprd-i2c 222a0000.i2c: I2C_ADDR_CFG = 0xc6
[    3.358696][T295@C6] sprd-i2c 222a0000.i2c: I2C_COUNT = 0x1
[    3.359384][T295@C6] sprd-i2c 222a0000.i2c: I2C_STATUS = 0x14201
[    3.360137][T295@C6] sprd-i2c 222a0000.i2c: ADDR_DVD0 = 0xc0012
[    3.360869][T295@C6] sprd-i2c 222a0000.i2c: ADDR_DVD1 = 0x0
[    3.361558][T295@C6] sprd-i2c 222a0000.i2c: ADDR_STA0_DVD = 0x24
[    3.362348][T295@C6] FLASH_OCP81375: 295 331 sprd_flash_ocp81375_init : device id not match! device_id 0x0
//PA
[    4.923735][T295@C7] sprd-i2c 222a0000.i2c: addr: 0x58 dma transfertimeout!
[    4.924610][T295@C7] sprd-i2c 222a0000.i2c: I2C_CTL = 0x1c4106
[    4.925331][T295@C7] sprd-i2c 222a0000.i2c: I2C_ADDR_CFG = 0xb0
[    4.926062][T295@C7] sprd-i2c 222a0000.i2c: I2C_COUNT = 0x1
[    4.926752][T295@C7] sprd-i2c 222a0000.i2c: I2C_STATUS = 0x14201
[    4.927495][T295@C7] sprd-i2c 222a0000.i2c: ADDR_DVD0 = 0xc0012
[    4.928236][T295@C7] sprd-i2c 222a0000.i2c: ADDR_DVD1 = 0x0
[    4.928925][T295@C7] sprd-i2c 222a0000.i2c: ADDR_STA0_DVD = 0x24
[    4.929689][T295@C7] [Awinic] [6-0058]aw87xxx_dev_i2c_read_byte: i2c_read cnt=0 error=-110

```

## 分析结果
硬件查到I2C6 短路了，I2C短路会造成总线超时，而I2C连接异常是直接不通。
