# 查DDR频率电压

查看当前频率
 cat /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_dump | grep -e uv -e khz

cat /sys/bus/platform/drivers/emi_clk_test/read_dram_data_rate

查看支持的频率和电压
cat /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_opp_table

设置定频
echo %d  > /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp

8786代码中定频

代码定频方式如下：
1）定义MTK_FIXDDR1600_SUPPORT这个宏。
2）修改preloader中dramc_pi_main.c
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

3）重新编译烧录后，可以按以下方式确认：
echo 0 > /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp//定频最高
cat /sys/bus/platform/drivers/emi_clk_test/read_dram_data_rate//确认运行频率
看第二个cmd是否打印DRAM data rate=2400
