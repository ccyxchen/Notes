# socdump的原理

soc dump在minidump中对应的文件是etb_data，主要是从ETB寄存器中导出值。

```c
//通过写寄存器关闭ETB
void sprd_etb_hw_dis(void)
{
	u32 ffcr;
	CS_UNLOCK(ETB_BASE);

	ffcr = readl(ETB_BASE + ETB_FFCR_LK);
	/* stop formatter when a stop has completed */
	ffcr |= ETB_FFCR_STOP_FI_LK;
	writel(ffcr, ETB_BASE + ETB_FFCR_LK);
	/* manually generate a flush of the system */
	ffcr |= ETB_FFCR_FON_MAN_LK;
	writel(ffcr, ETB_BASE + ETB_FFCR_LK);

	writel(0x0, ETB_BASE + ETB_CTL_REG_LK);
	CS_LOCK(ETB_BASE);
}

void sprd_etb_dump (void)
{
	int i;
	unsigned char *buf_ptr = NULL;
	u32 read_data;
	u32 read_ptr, write_ptr;
	u32 frame_off, frame_endoff;

	buf_ptr = (unsigned char *)etb_dump_mem;

	CS_UNLOCK(ETB_BASE);

	read_ptr = readl(ETB_BASE + ETB_RAM_READ_POINTER_LK);
	write_ptr = readl(ETB_BASE + ETB_RAM_WRITE_POINTER_LK);
	etb_buf_size = readl(ETB_BASE + ETB_RAM_DEPTH_LK_REG);

	frame_off = write_ptr % ETB_FRAME_SIZE_WORDS;
	frame_endoff = ETB_FRAME_SIZE_WORDS - frame_off;
	if (frame_off)
		write_ptr += frame_endoff;

	if ((readl(ETB_BASE + ETB_STATUS_LK_REG) & ETB_STATUS_RAM_FULL_LK) == 0)
		writel(0x0, ETB_BASE + ETB_RAM_READ_POINTER_LK);
	else
		writel(write_ptr, ETB_BASE + ETB_RAM_READ_POINTER_LK);

	for (i = 0; i < etb_buf_size; i++) {
		read_data = readl(ETB_BASE + ETB_RAM_READ_DATA_LK_REG);
		*buf_ptr++ = read_data >> 0;
		*buf_ptr++ = read_data >> 8;
		*buf_ptr++ = read_data >> 16;
		*buf_ptr++ = read_data >> 24;
	}

	if (frame_off) {
		buf_ptr -= (frame_endoff * 4);
		for (i = 0; i < frame_endoff; i++) {
			*buf_ptr++ = 0x0;
			*buf_ptr++ = 0x0;
			*buf_ptr++ = 0x0;
			*buf_ptr++ = 0x0;
		}
	}

	//writel(read_ptr, ETB_BASE + ETB_RAM_READ_POINTER_LK);
	/* Read_pointer has been set as 0x7cb0 in sprd_log_point.c
         * Read_pointer should be set as 0x0 to dump etb.bin for soc_dump function
        */
	writel(0x0, ETB_BASE + ETB_RAM_READ_POINTER_LK);
	CS_LOCK(ETB_BASE);
}

#ifdef CONFIG_ETB_DUMP
void save_soc_dump_to_minidump(void)
{
	struct section_info_extend section_info_extend;
	int ret;

	dump_logd ("Start to dump ETB trace data to minidump\n");
	sprd_etb_hw_dis();
	sprd_etb_dump();
	section_info_extend.paddr = &etb_dump_mem[0];
	section_info_extend.size = etb_buf_size * 4;
	memset(section_info_extend.section_name, 0, SECTION_NAME_LEN_MAX);
	memcpy(section_info_extend.section_name, ETB_DATA, strlen(ETB_DATA));
	dump_logd("section_name: %s \n", section_info_extend.section_name);
	ret = sysdump_save_extend_info(&section_info_extend);
	if (ret)
		dump_loge("save soc_dump to bootloader section failed ! \n");
}
#endif
```