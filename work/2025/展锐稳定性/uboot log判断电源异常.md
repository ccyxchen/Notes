# uboot log判断电源异常
当出现uvlo或ovlo时，会打印：
```txt
[00002268] [c0] last shutdown flag ANA_REG_GLB_POR_OFF_FLAG:0x2800
[00002269] [c0] Is power off from smpl

[00003488] [c0] enter mode normal, boot_reason: Sudden momentary power loss, pwroff_reason: uvlo pwroff
```

## 源码解析：
```c
static void vlx_entry(uchar *dt_addr)
{
#ifdef CONFIG_FASTBOOT_SECURITY_DOWNLOAD
	/* clear reboot-edl flag if necessary */
	if (!fb_check_reboot_edl(NULL)) {
		(void)fb_require_reboot_edl(0);
	}
#endif

	const char *bootmode = g_env_bootmode;
	dprintf(CRITICAL,"enter mode %s, boot_reason: %s, pwroff_reason: %s\n",
		!bootmode ? "normal" : bootmode,
		!bootcause_cmdline ? "Bootcause hasn't been set yet" : bootcause_cmdline,
		!pwroffcause_cmdline ? "pwroffcause hasn't been set yet" : pwroffcause_cmdline);
    ...
}

//从ANA_REG_GLB_POR_OFF_FLAG寄存器获取关机原因
void check_poweroff_mode(void)
{
	unsigned pwroff_reason= 0;
	int ret;

	pwroff_reason = ANA_REG_GET(ANA_REG_GLB_POR_OFF_FLAG);
	dprintf(INFO,"last shutdown flag ANA_REG_GLB_POR_OFF_FLAG:0x%x\n",pwroff_reason);

	sci_adi_set(ANA_REG_GLB_POR_OFF_FLAG, 0xffff);	//clear power off flag

	ret = sci_adi_read(ANA_REG_GLB_SMPL_CTRL1) & BIT_SMPL_PWR_ON_FLAG;
	dprintf(INFO,"%s power off from smpl\n", ret ? "Is" : "Not");

	if(pwroff_reason == HWOFF_STATUS_PD )
		pwroffcause_cmdline = "device power down";
		...
}
```
![](../vx_images/383326882965527.png =806x)
![](../vx_images/504918878090440.png =767x)

