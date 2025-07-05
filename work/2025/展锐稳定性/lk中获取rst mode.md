# lk中获取rst mode

```C
unsigned reboot_mode_check(void)
{
	static unsigned rst_mode = 0;
	static unsigned check_times = 0;

	if(!check_times) {
		rst_mode = check_reboot_mode();
		check_times++;
	}
	dprintf(INFO,"reboot_mode_check rst_mode=0x%x\n",rst_mode);

	return rst_mode;
}
 #define BIT_REG_RST_FLG ( BIT(13) ) 
  #define HWRST_STATUS_SYSDUMPEN (0x200)
unsigned check_reboot_mode(void)
{
    unsigned hw_rst_mode = ANA_REG_GET(ANA_REG_GLB_POR_SRC_FLAG);
    reg_rst_mode = hw_rst_mode;
	reg_rst_mode &= (0xffff & BIT_REG_RST_FLG);
	dprintf(INFO,"check_reboot_mode:get raw reg_rst_mode is %x\n", reg_rst_mode);
	
    reboot_reg = rst_mode = ANA_REG_GET(ANA_REG_GLB_POR_RST_MONITOR);
	sysdump_flag = rst_mode & HWRST_STATUS_SYSDUMPEN;
	dprintf(INFO,"check_reboot_mode:get raw rst_mode is %x and sysdump_flag is %x\n",rst_mode,sysdump_flag);
	rst_mode &= 0xFF;
	ANA_REG_SET(ANA_REG_GLB_POR_RST_MONITOR, sysdump_flag | 0); //clear flag

	debugf("rst_mode==%x\n",rst_mode);
	hw_wdt_int_raw = hw_watchdog_rst_pending();
	if(hw_wdt_int_raw || reg_rst_mode){
		debugf("hw watchdog rst int pending\n");
		debugf("register reboot method reg_rst_mode is %x\n", reg_rst_mode);
		if(rst_mode == HWRST_STATUS_RECOVERY) {
			bootcause_cmdline="Reboot into reocovery";
			return CMD_RECOVERY_MODE;
		} else if(rst_mode == HWRST_STATUS_FASTBOOT){
			bootcause_cmdline="Reboot into fastboot";
			return CMD_FASTBOOT_MODE;
			...
	｝else{
		dprintf(INFO,"is_7s_reset 0x%x, systemdump 0x%x\n", is_7s_reset(), is_7s_reset_for_systemdump());
		debugf("no hw watchdog and reg rst int pending\n");
		if(is_7s_reset_for_systemdump()) {
			ANA_REG_SET(ANA_REG_GLB_WDG_RST_MONITOR, SW_7SRST_STATUS);
			lr_cause = LR_ABNORMAL;
			bootcause_cmdline="7s reset for systemdump";
			return CMD_UNKNOW_REBOOT_MODE;
		} else if(hw_rst_mode & SW_EXT_RSTN_STATUS) {
			lr_cause = LR_LONG_PRESS;
			bootcause_cmdline="Software extern reset status";
			return CMD_EXT_RSTN_REBOOT_MODE;
		} else if(rst_mode == HWRST_STATUS_NORMAL2) {
			ANA_REG_SET(ANA_REG_GLB_WDG_RST_MONITOR, SW_7SRST_STATUS);
			lr_cause = LR_UNKNOWN;
			bootcause_cmdline="STATUS_NORMAL2 without watchdog pending";
			return CMD_UNKNOW_REBOOT_MODE;
		} else if(is_7s_reset()) {
			lr_cause = LR_ABNORMAL;
			bootcause_cmdline="7s reset";
			return CMD_NORMAL_MODE;
		}
		else
			return 0;
	}
    ...
}
#define WDG_INT_RST_BIT BIT_3
int hw_watchdog_rst_pending(void)
{
	u32 ret = 0;
        /*clk on*/
	ANA_REG_OR(ANA_REG_GLB_ARM_MODULE_EN, BIT_ANA_WDG_EN); //WDG enable
	ANA_REG_OR(ANA_REG_GLB_RTC_CLK_EN,    BIT_RTC_WDG_EN); //WDG Rtc enable

	if (hw_wdt_int_raw_flag == 0x355e)
		hw_wdt_int_raw_flag = wdt_rst_raw_int();
	ret = hw_wdt_int_raw_flag & WDG_INT_RST_BIT;
	dprintf(INFO,"hw watchdog int raw status 0x%x\n", ret);
	wdt_int_clr();

	return ret;
}

static inline u32 wdt_rst_raw_int(void)
{
	return ANA_REG_GET(WDG_INT_RAW);
}
```
rst mode 主要从ANA_REG_GLB_WDG_RST_MONITOR和ANA_REG_GLB_POR_RST_MONITOR寄存器获取，对应的reset mode 
可以从`vendor/bsp/bootloader/lk/platform/sprd_shared/soc/qogirn6l/include/asm/arch/check_reboot.h`查找。
如果发生了pmic watchdog，可以通过WDG_INT_RAW寄存器bit 3读取。
CMD_UNKNOW_REBOOT_MODE 对应的是manual dump.