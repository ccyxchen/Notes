# 查DDR频率电压

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
