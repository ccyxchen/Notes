# MTK mem test
## mem test 代码
`vendor/mediatek/proprietary/bootable/bootloader/preloader/platform/common/emi/emi_mem_test.c`
测试的函数：
```C
void emi_bist_test(void) //这个目前是没有使用的，应该需要硬件支持

//这2个函数只有6899、6991在用，且需要特定条件
int emi_complex_cpu_mem_test (void) 
void emi_simple_cpu_mem_test(PTR_T addr, U32 len, U32 *pass_count, U32 *err_count) 
//某些平台会用，在ETT测试Init_DRAM时执行：固定使用部分内存地址进行软件的读写对比测试
//vendor/mediatek/proprietary/bootable/bootloader/preloader/platform/mt6853/src/drivers/dramc_utility.c
int dramc_complex_mem_test (unsigned int start, unsigned int len)

//所有平台都会执行complex_mem_test，很多是平台定义的
//vendor/mediatek/proprietary/bootable/bootloader/preloader/platform/mt6768/src/drivers/memory.c
int
complex_mem_test (unsigned int start, unsigned int len)
//也有通用的，只有6899、6991在用：
vendor/mediatek/proprietary/bootable/bootloader/preloader/platform/common/dramc/memory_test.c

MOD_SRC :=

ifeq ("$(CFG_COMMON_DRAMC)", "1")
MOD_SRC += \
	dram_calibration_data.c \
	dramc_top_api.c \
	memory.c \
	memory_test.c \
	lz4.c
endif
```
![](vx_images/419841563267205.png =930x)

## emi_complex_cpu_mem_test 函数执行条件
![](vx_images/372626372788656.png =983x)
![](vx_images/47134415166875.png =1003x)
只有mt6991和mt6899会执行emi_complex_cpu_mem_test，以mt6899说明执行条件

emi_complex_cpu_mem_test
    -->  SLT_Test_DFS_and_Memory_Test
        --> SLT_test_flow
            --> SLT_test_before_exit
                --> Init_DRAM //must defined(DRAM_SLT)
                
```c
#if defined(SLT)
#define DRAM_SLT //open it when SLT ready
```
DDR 的 SLT 是指 DDR 的系统级测试（System Level Test）。它是在仿真的终端使用场景中对 DDR 芯片进行测试，通过实际运行和使用来检验芯片功能。
需要定义SLT 才会执行，目前所有项目都是没有定义的。

emi_complex_cpu_mem_test
    --> HQA_report_used_vcore_shmoo_test
        --> Init_DRAM

```c
#if defined(FOR_HQA_REPORT_USED)
#if defined(FOR_HQA_REPORT_USED_VCORE_SHMOO_TEST)
#if SUPPORT_SAVE_TIME_FOR_CALIBRATION
	//only full K do slt test, fast K skip slt test to save test time
	if (p->femmc_Ready == 0)
		HQA_report_used_vcore_shmoo_test(p);
#else
	HQA_report_used_vcore_shmoo_test(p);
#endif
#endif
#endif

#define FALSE 0

#ifndef FOR_DV_SIMULATION_USED
#define FOR_DV_SIMULATION_USED                                                 \
	(FALSE) ////calibration funciton for DV simulation. Code changed due to different compiler
#endif

#if (!FOR_DV_SIMULATION_USED && !__ETT__)
// for preloader/lk customize
//#include "dramc_ddr_type_custom.h"
#undef CFG_LPDDR_ENABLE
#define CFG_LPDDR_ENABLE 1
...
#endif

#if (FOR_DV_SIMULATION_USED == 0)
#define FOR_HQA_TEST_USED // HQA test used, to print result for easy report
#define FOR_HQA_REPORT_USED
#if CFG_LPDDR_ENABLE
#define FOR_HQA_REPORT_USED_VCORE_SHMOO_TEST // HQA test used, to test lv @ every freq
#define FOR_HQA_REPORT_USED_CBT
#endif
#endif

#if !__ETT__
#if (FOR_DV_SIMULATION_USED == 0)
// Preloader: using config CFG_DRAM_CALIB_OPTIMIZATION to identify
#define SUPPORT_SAVE_TIME_FOR_CALIBRATION CFG_DRAM_CALIB_OPTIMIZATION
#define FAST_K SUPPORT_SAVE_TIME_FOR_CALIBRATION
#else
// DV simulation, use full calibration flow
#define SUPPORT_SAVE_TIME_FOR_CALIBRATION 0
#endif

# DRAM Calibration Optimization:
# DRAM calib data will be stored to storage device to enhance DRAM init speed.
CFG_DRAM_CALIB_OPTIMIZATION :=1
```
可以看到在打开traing 存储到磁盘的功能时，full k 会执行该测试，fast k 不执行。
## emi_simple_cpu_mem_test 函数执行条件
![](vx_images/77712295183796.png =1107x)
emi_simple_cpu_mem_test
    --> mem_test
        --> mt_mem_init(void)
            --> dev_dram_init()                   --> platform_init (必执行)
                --> platform_init_hw_bottom_half
                    -->  cmd_notify_init_hw 
emi_simple_cpu_mem_test
    -->  vDramCPUReadWriteTestAfterCalibration
        --> Init_DRAM   (必执行)
