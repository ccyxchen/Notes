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
 

## MR初始化和 ZQ calibration

Init_DRAM -> DFSInitForCalibration -> DramcInit -> DramcSetting_Olympus_LP4_ByteMode -> DramcModeRegInit_LP4 -> DramcZQCalibration


### ZQ cal 详解

一、调用与时序位置（LPDDR4）

vApplyConfigBeforeCalibration() 先设置 ZQCS/时序相关寄存器。
DramcModeRegInit_LP4() 中对每个 channel/rank 调用 DramcZQCalibration()。
校准完成后继续 MR 设置与后续 CBT/其他校准。
相关位置：

dramc_pi_calibration_api.c
dramc_pi_basic_api.c
dramc_register.h
二、ZQ 校准主流程（DramcZQCalibration）
实际执行的是 ZQCAL + ZQLAT 两个阶段，带响应轮询与超时保护：

备份寄存器：MRS / DRAMC_PD_CTRL / CKECTRL
强制时钟常开：DRAMC_PD_CTRL_MIOCKCTRLOFF=1
CKE 固定为 ON：CKEFixOnOff(..., CKE_FIXON, ...)
选择 rank：MRS_MRSRK = u1GetRank(p)，并 MPC_OPTION_MPCRKEN=1
发起 ZQCAL：SPCMD_ZQCEN=1
轮询 SPCMDRESP_ZQC_RESPONSE，TIME_OUT_CNT=100，每次 mcDELAY_US(1)
成功后 SPCMD_ZQCEN=0，延时 1us
发起 ZQLAT：SPCMD_ZQLATEN=1
轮询 SPCMDRESP_ZQLAT_RESPONSE
成功后 SPCMD_ZQLATEN=0，延时 1us
恢复寄存器，记录校准成功
位置：dramc_pi_calibration_api.c

三、ZQCS 相关配置（校准前与运行期）
在 vApplyConfigBeforeCalibration() 里先把 ZQCS 的时序和通道交错策略定好：

SHU_SCINTV_TZQLAT = 0x1B：确保 tZQCAL 满足最小 1us
SHU_CONF3_ZQCSCNT = 0x1ff：每隔多少 refresh 触发 ZQCS
DRAMCTRL_ZQCALL = 0：禁用 “双 rank 同时 ZQ” 的 HW 机制，避免共享 ZQ pin 冲突
双通道时 ZQCS_ZQCSDUAL=1 并设置 ZQCSMASK 交错
SPCMDCTRL_ZQCSDISB 和 SPCMDCTRL_ZQCALDISB 置 0（允许 ZQ 相关命令）
位置：dramc_pi_calibration_api.c
寄存器位定义：dramc_register.h

运行期（DramcRunTimeConfig）会根据宏开关决定是否启用 ZQCS：

LP4：通过 SPCMDCTRL_ZQCALDISB 控制
LP3：通过 SPCMDCTRL_ZQCSDISB 控制
位置：dramc_pi_basic_api.c

四、LPDDR3 的 ZQ 初始化差异
LPDDR3 不走 SPCMD_ZQCEN/ZQLATEN，而是在 DramcModeRegInit_LP3() 里通过
MR10 = 0xFF 执行 ZQ Init。
位置：dramc_pi_basic_api.c

五、关键寄存器/位（与代码一致）

ZQCAL/ZQLAT 触发：DRAMC_REG_SPCMD
SPCMD_ZQCEN
SPCMD_ZQLATEN
响应轮询：DRAMC_REG_SPCMDRESP
SPCMDRESP_ZQC_RESPONSE
SPCMDRESP_ZQLAT_RESPONSE
ZQCS 周期与时序：
DRAMC_REG_SHU_CONF3 -> SHU_CONF3_ZQCSCNT
DRAMC_REG_SHU_SCINTV -> SHU_SCINTV_TZQLAT
双通道交错：DRAMC_REG_ZQCS
ZQCS_ZQCSDUAL
ZQCS_ZQCSMASK
位置：dramc_register.h

六、容易踩的点（建议重点关注）

MIOCK 必须常开：若没 MIOCKCTRLOFF=1，响应轮询可能超时。
CKE 必须 Fix ON：ZQ 命令依赖 CKE 有效。
Rank 选择：MRS_MRSRK 与 MPCRKEN 不对会导致校准落到错误 rank。
双通道 ZQ pin 共享：ZQCSMASK 交错必须正确，否则同一时刻双通道触发。
注释/位名不一致：例如 ZQCALDISB/ZQCSDISB 的注释和位名语义不完全一致，建议基于实际行为再验证。
时间常量：当前轮询超时约 100us（100 次 * 1us），若遇到慢器件可能需要调整 TIME_OUT_CNT。

## Command Bus Training

函数 vCalibration_Flow_LP4 -> CmdBusTrainingLP4 -> DramcWriteLeveling -> DramcRxdqsGatingCal 
-> DramcRxWindowPerbitCal -> DramcTxWindowPerbitCal -> DramcRxdatlatCal -> DramcTxOECalibration -> DramcRxdqsGatingPostProcess -> DramcDualRankRxdatlatCal -> 


## AI 分析流程
文件地图（DRAMC 主体）

dramc_pi_main.c
入口与编排层：全局上下文 DramCtx_LPDDR4/LPDDR3，Init_DRAM() 主入口，CBT 模式转换，广播开关，电压/频率设置，校准流程编排，保存/加载快速校准数据等。
dramc_pi_basic_api.c
底层寄存器与基础操作：vDramcInit_PreSettings()、DramcInit()、DdrUpdateACTiming()、频率切换/DFS、模式寄存器读写、延迟/门控/Tracking 等。
dramc_pi_calibration_api.c
校准算法库：CMD/CA training、Write leveling、Gating、Rx/Tx per-bit、Datlat、DQSOSC、ZQ 等。
dramc_pi_ddr_reserve.c
DDR Reserve/Resume：SPM/时钟门控、寄存器保存恢复、SR 状态处理。
dramc_pi_api.h
关键配置宏、类型与接口声明。核心结构体 DRAMC_CTX_T 定义在这里。
dramc_common.h
通用类型与日志/延时宏，跨平台配置。
dramc_register.h
寄存器地址与 bitfield 定义。
相关但外围的协作文件（EMI/电源）

emi.c
EMI 侧配置、DRAM 类型与 timing 选择、与 DRAMC 初始化衔接。
emi.h
emi_hw.h
emi_mpu_mt.h
另外在 DRAMC 代码里会直接引用 pmic.h、pll.h、voltage.h 等电源/时钟接口。

核心数据结构（理解 DRAMC 行为的“总开关”）

DRAMC_CTX_T（在 dramc_pi_api.h）
包含 channel/rank、频率/DFS、dram_type、CBT/DBI/ODT、test pattern、vendor/revision、ranksize、校准 bypass 标志等。绝大多数 API 都通过这个上下文驱动。
主流程（Init_DRAM 视角）

Init_DRAM() 选择 LP4/LP3 上下文，映射 dram_cbt_mode_extern 到内部 CBT 模式。
根据 LP4/LP3 打开/关闭 broadcast。
执行 Global_Option_Init 与 Global_Option_Init2 等全局配置（与 EMI 参数关联）。
EMI_Init() 完成 EMI 侧配置。
vDramcInit_PreSettings() 做校准前必须的寄存器/复位准备。
DramcSave_Time_For_Cal_Init() 尝试读取离线校准结果，设置 bypass 标志。
DramcInit() 设置基本寄存器、AC Timing、调用校准前准备。
校准流程（LP4/LP3 不同分支）调用 dramc_pi_calibration_api.c 中的训练/校准函数。
vApplyConfigAfterCalibration() 等完成后处理，并可能保存校准结果。
DDR Reserve/Resume 时走 dramc_pi_ddr_reserve.c 的 SPM 协调流程。



