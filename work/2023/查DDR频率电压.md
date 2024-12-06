# 查看和设置DDR频率电压

## MTK

查看当前频率
kernel-4.19:
cat /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_dump | grep -e uv -e khz

查看支持的频率和电压
kernel-4.19:
cat /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_opp_table

kernel-5.10：
cat /sys/devices/platform/soc/10012000.dvfsrc/helio-dvfsrc/dvfsrc_dump | grep -e uv -e khz
cat /sys/devices/platform/soc/10012000.dvfsrc/helio-dvfsrc/dvfsrc_opp_table

kernel 4.19 查看当前ddr频率
cat /sys/bus/platform/drivers/emi_clk_test/read_dram_data_rate

设置定频
echo %d  > /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp

O+项目需要执行命令来使能修改
echo 9595 > /sys/devices/platform/soc/10012000.dvfsrc/10012000.dvfsrc:dvfsrc-helper/dvfsrc_enable_force_mode

8786代码中定频

代码定频方式如下：
1）定义MTK_FIXDDR1600_SUPPORT这个宏。
2）修改preloader中dramc_pi_main.c

```C
DRAMC_CTX_T DramCtx_LPDDR4 =
{
    CHANNEL_DUAL, /* Channel number */
    CHANNEL_A, /* DRAM_CHANNEL */
    RANK_DUAL, /* DRAM_RANK_NUMBER_T */
    RANK_0, /* DRAM_RANK_T */

#ifdef MTK_FIXDDR1600_SUPPORT
    LP4_DDR1600, => 修改为想定的频点，如LP4_DDR2400
#else
#if DUAL_FREQ_K
    LP4_LOWEST_FREQSEL, /* Darren: it will be overwritten by gFreqTbl[DRAM_DFS_SHUFFLE_3].freq_sel (Init_DRAM) */
#else
#if __FLASH_TOOL_DA__
    LP4_DDR1600,
#else
```

3）重新编译烧录后，可以按以下方式确认：
echo 0 > /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp//定频最高
cat /sys/bus/platform/drivers/emi_clk_test/read_dram_data_rate//确认运行频率
看第二个cmd是否打印DRAM data rate=2400

抓trace
adb shell atrace gfx input view webview wm am sm audio video camera hal res dalvik rs bionic power pm ss database network adb aidl nnapi rro sched irq i2c freq idle disk mmc sync workq memreclaim regulators binder_driver binder_lock pagecache thermal > trace.txt

## 展锐平台

1、查可用频率
cat  /sys/class/devfreq/scene-frequency/sprd-governor/ddrinfo_freq_table

2、定频
echo 768 > /sys/class/devfreq/scene-frequency/sprd-governor/scaling_force_ddr_freq

3、查看当前DDR 运行频点
cat /sys/class/devfreq/scene-frequency/sprd-governor/ddrinfo_cur_freq

## 高通

高通不同芯片平台差异很大，可以通过QMVS去查，qmvs的node_modules\swsys-qmvs\
node_modules\swsys-clk-switch\bin\bimc_clock.sh脚本有列出对应的命令。

sm6225
查当前频率
`cat /sys/kernel/debug/clk/measure_only_mccc_clk/clk_measure`

调频率

```Shell
echo 1 >  /sys/kernel/debug/interconnect-test/src_port
echo 512  >  /sys/kernel/debug/interconnect-test/dst_port
echo 1 > /sys/kernel/debug/interconnect-test/get
echo 8367636 > /sys/kernel/debug/interconnect-test/peak_bw
echo 1 > /sys/kernel/debug/interconnect-test/commit
echo "active clk2 0 1 max ${REQ_KHZ}" > /d/rpm_send_msg/message
```

可用频率
`"frequencies": [200000, 547200, 1017600,1555200, 1804800,2092800]`

qm8909
查当前频率
`adb shell cat /sys/kernel/debug/clk/bimc_clk/measure`

调频率

```Shell
adb shell "echo 1 > /d/msm-bus-dbg/shell-client/mas"
adb shell "echo 512 > /d/msm-bus-dbg/shell-client/slv"
#这条要设置你要的频率，有效值：9600，50000，100000，200000，400000，533000
adb shell 'echo "active clk2 0 1 max 这里填频率" > /d/rpm_send_msg/message'   
adb shell "echo 7200000000 > /d/msm-bus-dbg/shell-client/ib"
adb shell "echo 1 > /d/msm-bus-dbg/shell-client/update_request"

# For 533 MHz, CLOCK_FREQ_REQUIRED = 533 and for 400 MHz, CLOCK_FREQ_REQUIRED = 400.
```

可用频率

```C
//rpm_proc/core/systemdrivers/clock/config/msm8909/ClockBSP.c

 const ClockMuxConfigType BIMCClockConfig[] =
 {
   {   9600000, { HAL_CLK_SOURCE_XO,     1, 1,  1, 1 }, CLOCK_VREG_LEVEL_LOW },
   {  50000000, { HAL_CLK_SOURCE_GPLL0, 16, 1,  1, 1 }, CLOCK_VREG_LEVEL_LOW },
   { 100000000, { HAL_CLK_SOURCE_GPLL0,  8, 1,  1, 1 }, CLOCK_VREG_LEVEL_LOW },
   { 200000000, { HAL_CLK_SOURCE_GPLL0,  4, 1,  1, 1 }, CLOCK_VREG_LEVEL_LOW },
   { 400000000, { HAL_CLK_SOURCE_GPLL0,  2, 1,  1, 1 }, CLOCK_VREG_LEVEL_NOMINAL },
   { 533000000, { HAL_CLK_SOURCE_BIMCPLL,  2, 1,  1, 1 }, CLOCK_VREG_LEVEL_HIGH },
   { 0 }
 };

代码定频

//rpm_proc/core/systemdrivers/clock/hw/msm8909/ClockRPM.c 

void Clock_BusSetMinMax( Clock_NPAResourcesType  *pNPAResources )
{
...

   /* Default setting for BIMC clock */
   //这里定义最小频率，值为BIMCClockConfig数组的下标
   pNPAResources->BIMCClockResource.nMinLevel = 0;
 
   hal_part_num = HAL_clk_GetHWParNum();
   if( hal_part_num == part_num_8208)
    //这里定义最大频率，值为BIMCClockConfig数组的下标
     pNPAResources->BIMCClockResource.nMaxLevel = 4;
   else
     pNPAResources->BIMCClockResource.nMaxLevel = MAX_LEVEL;

```

通用的查询方法：
根据安装的QMVS下如下脚本查询定频命令：
npm_3.0.3\node_modules\swsys-qmvs\node_modules\swsys-clk-switch\bin\bimc_clock.sh
