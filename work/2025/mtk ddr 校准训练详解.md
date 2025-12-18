# mtk ddr 校准训练详解

platform/mt6768/src/core/main.c

main -> bldr_pre_process -> platform_init -> check_ddr_reserve_status -> 
mt_mem_init -> mt_set_emi

## 检测上次启动异常

```c
dbg_info = (top_dbg_info *) PLAT_DBG_INFO_BASE;
PLAT_DBG_INFO_BASE = (RAM_CONSOLE_SRAM_ADDR + RAM_CONSOLE_PLAT_DBG_INFO_OFFSET) 
= 0x0010EA00 + 0x540

typedef struct {
	unsigned int head[INFO_TYPE_MAX];
#ifdef DEF_LAST_DRAMC
	DEF_LAST_DRAMC last_dramc;
#endif
#ifdef DEF_LAST_EMI
	DEF_LAST_EMI last_emi;
#endif
#ifdef DEF_PLAT_SRAM_FLAG
	DEF_PLAT_SRAM_FLAG plat_sram_flag;
#endif
	unsigned int tail;
} top_dbg_info;

typedef struct {
	unsigned int ta2_result_magic;
	unsigned int ta2_result_last;
	unsigned int ta2_result_past;
	unsigned int ta2_result_checksum;
	unsigned int reboot_count;
	volatile unsigned int last_fatal_err_flag;
	volatile unsigned int fatal_err_flag;
	volatile unsigned int storage_api_err_flag;
	volatile unsigned int last_gating_err[2][2]; /* [channel][rank] */
	volatile unsigned int gating_err[2][2]; /* [channel][rank] */
	unsigned int k_voltage[DRAM_DFS_SHUFFLE_MAX];
#ifdef MTK_EMI_COMMON
	unsigned short mr5;
#endif
} LAST_DRAMC_INFO_T;

//保存dramc 信息的地址
last_dramc_info_ptr = &dbg_info->last_dramc;
// dram fatal 的异常标志
/* 0x1f -> bit[4:0] is for DDR reserve mode */
#define DDR_RSV_MODE_ERR_MASK		(0x1f)
last_dramc_info_ptr->last_fatal_err_flag & ~(DDR_RSV_MODE_ERR_MASK)

//gating err 判断
if (u4IO32Read4B(DRAMC_ADDR_SHIFT_CHN(DRAMC_REG_WDT_DBG_SIGNAL, chn)) & 0x4000) {
			dramc_crit("[dramc] found gating error in channel %d (0x%x)\n",
					chn, u4IO32Read4B(DRAMC_ADDR_SHIFT_CHN(DRAMC_REG_WDT_DBG_SIGNAL, chn)));
			ret |= (1 << chn);
		}
		
//dram的寄存器地址
platform/mt6768/src/drivers/inc/dramc_register.h
	
#define Channel_A_DRAMC_NAO_BASE_ADDRESS    0x1022C000
#define Channel_B_DRAMC_NAO_BASE_ADDRESS    0x10234000
#define Channel_A_DRAMC_AO_BASE_ADDRESS     0x1022A000
#define Channel_B_DRAMC_AO_BASE_ADDRESS     0x10232000
#define Channel_A_PHY_NAO_BASE_ADDRESS      0x1022E000
#define Channel_B_PHY_NAO_BASE_ADDRESS      0x10236000
#define Channel_A_PHY_AO_BASE_ADDRESS       0x10228000
#define Channel_B_PHY_AO_BASE_ADDRESS       0x10230000

//最终是通过 WDT_DBG_SIGNAL 寄存器的 14位判断 gating error
```

![](vx_images/476658388676571.png =746x)
![](vx_images/80466010527751.png =702x)

## RGU 配置

#define RGU_BASE            (0x10000000 + 0x00007000)
#define IO_PHYS             (0x10000000)
#define MTK_WDT_BASE            RGU_BASE
#define MTK_WDT_DEBUG_CTL        (MTK_WDT_BASE+0x0040)

rgu 的重要寄存器
![](vx_images/284686888184156.png =704x)
![](vx_images/103548427543190.png =683x)


## ddr reserve mode 

开机判断并处理 reserve mode

bldr_pre_process -> platform_init -> check_ddr_reserve_status

check_ddr_reserve_status函数会判断是否使能reserve mode以及是否进入成功,如果已经使能,
则需要执行release_dram去初始化并推出self-refresh

```C
//开机 reserve mode 处理
void check_ddr_reserve_status(void)
{
    int dcs_success = rgu_is_emi_dcs_success(), dvfsrc_success = rgu_is_dvfsrc_success();
    int dcs_en = rgu_is_emi_dcs_enable(), dvfsrc_en = rgu_is_dvfsrc_enable();

#ifdef DDR_RESERVE_MODE
    int counter = TIMEOUT;
	//判断是reserve mode 启动的
    if(rgu_is_reserve_ddr_enabled())
    {
      g_ddr_reserve_enable = 1;
#ifdef LAST_DRAMC
      dram_fatal_set_ddr_rsv_mode_flow();
#endif
		//reserve mode  启动成功,设置成功标志
      if(rgu_is_reserve_ddr_mode_success())
      {
        while(counter)
        {
          if(rgu_is_dram_slf())
          {
            g_ddr_reserve_success = 1;
            break;
          }
          counter--;
        }
		//启动后处于自刷新模式才算成功
        if(counter == 0)
        {
          dramc_crit("[DDR Reserve] ddr reserve mode success but DRAM not in self-refresh!\n");
          g_ddr_reserve_success = 0;
#ifdef LAST_DRAMC
	  	  dram_fatal_set_ddr_rsv_mode_err();
#endif
        }
      }
      else
      {
        dramc_crit("[DDR Reserve] ddr reserve mode FAIL!\n");
        g_ddr_reserve_success = 0;
#ifdef LAST_DRAMC
	  dram_fatal_set_ddr_rsv_mode_err();
#endif
      }
	//判断dcs 和 dvfs 是否正常
	if ((dcs_en == 1 && dcs_success == 0) || (dvfsrc_en == 1 && dvfsrc_success == 0)) {
		dramc_crit("[DDR Reserve] DRAM content might be corrupted -> clear g_ddr_reserve_success\n");
		g_ddr_reserve_success = 0;

		if (dvfsrc_en == 1 && dvfsrc_success == 0) {
			dramc_crit("[DDR Reserve] DVFSRC fail!\n");
#if 0//def LAST_DRAMC
			dram_fatal_set_dvfsrc_err();
#endif
		}

		if (dcs_en == 1 && dcs_success == 0) {
			dramc_crit("[DDR Reserve] DCS fail!\n");
#if 0 //def LAST_DRAMC
			dram_fatal_set_emi_dcs_err();
#endif
		}
	} else {
		dramc_crit("[DDR Reserve] DCS/DVFSRC success! (dcs_en=%d, dvfsrc_en=%d)\n", dcs_en, dvfsrc_en);
	}
	//做reserve mode 的设置并退出自刷新
	/* release dram, no matter success or failed */
	release_dram();
    }
    else
    {
      dramc_crit("[DDR Reserve] ddr reserve mode not be enabled yet\n");
      g_ddr_reserve_enable = 0;
    }
#endif
}

//判断成功进入reserve mode的关键log
int rgu_is_reserve_ddr_mode_success(void)
{
	unsigned int wdt_dbg_ctrl;

	/*
	 * MTK_DDR_RESERVE_RTA bit will be reset by modifying register MODE.
	 * Read DEBUG_CTL value kept by mtk_wdt_get_debug_ctl().
	 */
	wdt_dbg_ctrl = mtk_wdt_get_debug_ctl();

	if (wdt_dbg_ctrl & MTK_DDR_RESERVE_RTA) {
		RGULOG("WDT DDR reserve mode success! %x\n", wdt_dbg_ctrl);
		return 1;
	} else {
		RGULOG("WDT DDR reserve mode FAIL! %x\n", wdt_dbg_ctrl);
		return 0;
	}
}
```
 退出 ddr reserve mode 的log
 [DDR Reserve] release dram from self-refresh PASS!
 
