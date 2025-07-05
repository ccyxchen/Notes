# manual dump的实现
## manual dump使能
```c
//vendor/bsp/bootloader/lk/project/m2518.mk
# 7S reset config
# CONFIG_7S_RST_MODULE_EN	//0:disable module; 1:enable module
# CONFIG_7S_RST_SW_MODE		//0:hw reset,1:arm reset,power keep on	//hard for user version
# CONFIG_7S_RST_SHORT_MODE	//0:long press then release key to trigger;1:press key some time to trigger
# CONFIG_7S_RST_2KEY_MODE	//0:1Key--Normal mode; 1:2KEY
# CONFIG_7S_RST_THRESHOLD	//7S, hold key down for this time to trigger
#

GLOBAL_DEFINES += \
	CONFIG_7S_RST_SW_MODE=1 \
	CONFIG_7S_RST_MODULE_EN=1 \
	CONFIG_7S_RST_SHORT_MODE=1 \
	CONFIG_7S_RST_2KEY_MODE=1 \
	CONFIG_7S_RST_THRESHOLD=8
	
//vendor/bsp/bootloader/lk/platform/sprd_shared/driver/misc/pmic27xx_misc.c
void pmic_misc_init(void)
{
#ifdef CONFIG_ADIE_UMP9620
	if(por_wr_7s_control_enable(CONFIG_7S_RST_MODULE_EN)){
#endif
		pbint_7s_rst_cfg(CONFIG_7S_RST_MODULE_EN,
					CONFIG_7S_RST_SW_MODE,
					CONFIG_7S_RST_SHORT_MODE);
#ifdef CONFIG_ADIE_UMP9620
		por_wr_7s_control_enable(~CONFIG_7S_RST_MODULE_EN);
	}
#endif
}

# 禁用7s_rst 寄存器写保护
#ifdef CONFIG_ADIE_UMP9620
static inline int por_wr_7s_control_enable(uint32_t enable)
{
	if(enable){
		sci_adi_write(ANA_REG_GLB_POR_WR_PROT_VALUE, CONFIG_7S_WR_CONTROL_EN,BIT_POR_WR_PROT_VALUE(~0));
	}
	else{
		sci_adi_write(ANA_REG_GLB_POR_WR_PROT_VALUE, CONFIG_7S_WR_CONTROL_DISABLE,BIT_POR_WR_PROT_VALUE(~0));
	}
	return sci_adi_read(ANA_REG_GLB_POR_WR_PROT_VALUE) & BIT_POR_WR_PROT;
}
#endif

int pbint_7s_rst_cfg(uint32_t en, uint32_t sw_rst, uint32_t short_rst)
{
    pbint_7s_flag = sci_adi_read(ANA_REG_GLB_POR_SRC_FLAG);
	sci_adi_set(ANA_REG_GLB_POR_7S_CTRL, BIT_PBINT_7S_FLAG_CLR);
	udelay(10);
	sci_adi_clr(ANA_REG_GLB_POR_7S_CTRL, BIT_PBINT_7S_FLAG_CLR); //it is necessary,

	/* ignore sw_rst, please refer to config.h */
	if (en) {
		pbint_7s_rst_set_threshold(CONFIG_7S_RST_THRESHOLD);
		pbint_7s_rst_set_sw(!sw_rst);
		pbint_7s_status = ANA_REG_GET(ANA_REG_GLB_WDG_RST_MONITOR);
		dprintf(INFO,"get ANA_REG_GLB_WDG_RST_MONITOR = 0x%x\n", pbint_7s_status);
		ANA_REG_SET(ANA_REG_GLB_WDG_RST_MONITOR, 0);
		/*maintenance requirement 7s is configured soft reset in chipram*/
		if(is_7s_reset()) {
			dprintf(INFO,"is_7s_reset 0x%x\n", is_7s_reset());
			reboot_mode = sci_adi_read(ANA_REG_GLB_POR_RST_MONITOR);
			reboot_mode &= 0xFF;
			if(is_7s_reset_for_systemdump() || reboot_mode == 0xF0) {
				dprintf(INFO,"7s soft reset is changed to hard reset\n");
				pbint_7s_rst_set_sw(sw_rst);
			} else {
				dprintf(INFO,"7s hard reset is changed to soft reset\n");
				pbint_7s_rst_set_sw(!sw_rst);
			}
		} else if (pbint_7s_status == SW_7SRST_STATUS) {
			dprintf(INFO,"7s soft reset is changed to hard reset\n");
			pbint_7s_rst_set_sw(sw_rst);
		}

		pbint_7s_rst_set_swmode(short_rst);

		pbint_7s_rst_set_2keymode(CONFIG_7S_RST_2KEY_MODE);
	}
	return pbint_7s_rst_disable(!en);
}
int is_7s_reset(void)
{
	return pbint_7s_flag & PBINT_7S_SW_FLAG;
}

int is_7s_reset_for_systemdump(void)
{
	int val;
	int mask = PBINT_7S_SW_FLAG | PBINT_7S_HW_FLAG;

	val = pbint_7s_flag & mask;

	return (val == PBINT_7S_SW_FLAG);
}
```
lk中根据ANA_REG_GLB_POR_SRC_FLAG寄存器获取7s_reset标志位。bit 7 是hardware reset,bit 12是sw reset，当判断触发了hard reset或sw reset ，就设置当前的reset mode相反。ANA_REG_GLB_WDG_RST_MONITOR寄存器可以获取wdg 信息，当该值为0x1000说明发生sw reset.

### 寄存器说明
![](../vx_images/428176621752741.png =789x)
![](../vx_images/446614786050333.png =717x)
![](../vx_images/15867623347946.png =705x)
![](../vx_images/526286040566569.png =778x)
### manual dump 在kernel的实现
展锐提供驱动，可以设置7s_reset 的mode ,使能，时间，按键方式等
`vendor/bsp/kernel5.15/kernel5.15/drivers/unisoc_platform/sprd_7sreset.c`