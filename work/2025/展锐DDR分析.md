# 展锐DDR分析

## 初始化

DDR频率定义：
vendor/bsp/bootloader/chipram/ddr/ddr_init/init/ddrc/r3p3/ddrc_tmg_cfg.c

```C
const DDRC_FREQ_INFO_T ddrc_freq_info_lp4[] =
{//      1               2       3       4       5       6       7       8      9      10      11
    {DDR_CLK_384M,      0x00,  0x01,   0x07,   0x03,   0x07,   0x01,   0x03,   0x00,   0x0,    0x0},
    {DDR_CLK_533M,      0x00,  0x01,   0x07,   0x03,   0x07,   0x01,   0x02,   0x01,   0x0,    0x1},
    {DDR_CLK_768M,      0x01,  0x00,   0x03,   0x01,   0x03,   0x01,   0x03,   0x02,   0x0,    0x2},
    {DDR_CLK_1066M,     0x01,  0x00,   0x01,   0x00,   0x01,   0x03,   0x02,   0x03,   0x1,    0x2},
    {DDR_CLK_1244M,     0x01,  0x00,   0x01,   0x00,   0x01,   0x02,   0x01,   0x04,   0x1,    0x2},
    {DDR_CLK_1536M,     0x01,  0x00,   0x01,   0x00,   0x01,   0x01,   0x03,   0x05,   0x1,    0x3},
    {DDR_CLK_1866M,     0x01,  0x00,   0x01,   0x00,   0x01,   0x01,   0x01,   0x06,   0x1,    0x3},
    {DDR_CLK_2133M,     0x01,  0x00,   0x01,   0x00,   0x01,   0x01,   0x02,   0x07,   0x1,    0x3},
};

//clk 转换为 fn
void dmc_freq_sel_search(u32 ddr_clk, u32* fn)
{
	switch (ddr_clk) {
		case 2133: *fn = 0x7; break;
		case 1866: *fn = 0x6; break;
		case 1536: *fn = 0x5; break;
		case 1244: *fn = 0x4; break;
		case 1066: *fn = 0x3; break;
		case 768:  *fn = 0x2; break;
		case 533:  *fn = 0x1; break;
		case 384:  *fn = 0x0; break;
		default: spl_error_handler(PHASE_DDR_INIT_FREQ_SEL_FAILED);
	}
}

//DDR初始化

//vendor/bsp/bootloader/chipram/ddr/ddr_init/init/ddrc/r3p3/ddrc_init.c

void sdram_init()
{
    //以低频初始化ＤＤＲ
    dram_init_from_low_freq(BOOT_FREQ_POINT);

    //设置最高频点
    dram_freq_auto_detect(&train_high_point);
    
    //执行DDR training
    ddrc_train_flow(ddr_mode, train_high_point);
    
    //将DDR频率设置为 CLK_DDR_FREQ
    ddrc_target_point_set(target_ddr_clk, train_high_point);
    
//执行 ddr test
    dram_info.bist_fail_addr = BIST_PASS_KEY;
	if (rst_mode == 0x00 && hw_wdt_int_raw != 0x8) {
		/* narmol boot all bist */
		rst_normal_all_bist();
	}

	/*other boot SPECIFIC bist test and reset bist config for retention*/
	if (dmc_ddr_test(SCAN_SPECIFIC_ADDR, 0x0, BIST_RESERVE_SIZE - 1)) {
		dmc_print_str("bist failed\n");
		spl_error_handler(PHASE_DDR_BIST_FAILED);
	}

}
```

## training 分析

```C
void ddrc_train_flow(u32 ddr_mode, u32 train_top_clk)
{
	//bist[2] addr not use Only open bist0 and bist1
	u64 addr = 0;
	u32 fn, ddr_clk;
	u32 result = 0;

	REG32(PUB_APB_BASE_ADDR + 0x403c + 0x1000) = 0x1 << 4;//enable clk dmc ch4 by setting dmc_axi_ch_clk_eb[4]
	REG32(PUB_APB_BASE_ADDR + 0x4000 + 0x1000) = 0x1 << 20;//enable pub clk aon to enable dmc phy hclk
	//获取频率数量
	dmc_freq_sel_search(train_top_clk, &dram_info.fn_max);
	dmc_phy_train_pre_set();
	for (fn = LP4_TRAIN_START_FN; fn <= dram_info.fn_max; fn++) {
		ddr_clk = (freq_info + fn)->ddr_clk;
		//对每个频率执行training
		dmc_phy_train(ddr_clk, fn);
		//first 4k byte
		reg_bit_set(DMC_CTL0_(0x0144), 16, 1, 0x1);//enable ctrl update
	//training后执行测试	
    result = dmc_ddr_test(SCAN_SPECIFIC_ADDR, 0, 0xff0);
		if (dram_info.cs1_size) {
			//use 4kb in last ddr space
			addr = (dram_info.cs0_size + dram_info.cs1_size - 0x1000);
			//last 4k
			result += dmc_ddr_test(SCAN_SPECIFIC_ADDR, addr, addr + 0x1000 - 1);
		}

		if (result) {
			print_string("train bist failed\n");
			spl_error_handler(PHASE_DDR_BIST_FAILED);
		}
		reg_bit_set(DMC_CTL0_(0x0144), 16, 1, 0x0);//disable ctrl update
	}
	REG32(PUB_APB_BASE_ADDR + 0x403c + 0x2000) = 0x1 << 4;//enable clk dmc ch4 by setting dmc_axi_ch_clk_eb[4]
	REG32(PUB_APB_BASE_ADDR + 0x4000 + 0x2000) = 0x1 << 20;//disable pub clk aon to disable dmc phy hclk
}
```