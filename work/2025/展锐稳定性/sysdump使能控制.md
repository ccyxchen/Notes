# sysdump使能控制

## 代码解析
```C
//读取sysdumpdb,设置sysdump和minidump的使能
int init_dump_status(struct dumpdb_header *dump_status_header, int *minidump_status,
					int *fulldump_status, int rst_mode)
{
	if((IS_ORIG_STATUS(dump_status_header->dump_flag)) || (rst_mode == CMD_RECOVERY_MODE)) {
		dump_status_header->dump_flag &= SYSDUMP_STATUS_MASK;
		dump_logd("dump status is orig:  (0x%x)\n", dump_status_header->dump_flag);
		dump_status_header->dump_flag |= AP_FULL_DUMP_ENABLE;
		dump_logd("Debug mode , set ap full dump enable default . (0x%x) \n", dump_status_header->dump_flag);
		dump_status_header->dump_flag |= AP_MINI_DUMP_ENABLE;
		dump_logd("Always set ap mini dump enable default .  (0x%x) \n", dump_status_header->dump_flag);
                /* record the status of dumpdb_header struct */
		record_dumpdb_header_status(dump_status_header);
                /*      updadte dump flag data */
		if (common_raw_write(SYSDUMPDB_PARTITION_NAME, (uint64_t)(sizeof(struct dumpdb_header)), (uint64_t)(sizeof(struct dumpdb_header)), (uint64_t)0, (char*)dump_status_header)) {
			dump_loge(" update dump flag  %s error.\n", SYSDUMPDB_PARTITION_NAME);
			return -1;
		}
		*minidump_status = !!(dump_status_header->dump_flag & AP_MINI_DUMP_ENABLE);
		*fulldump_status = !!(dump_status_header->dump_flag & AP_FULL_DUMP_ENABLE);
	} else {
		dump_logd("...Status Changed... , read saved status (0x%x)\n", dump_status_header->dump_flag);
		*minidump_status = !!(dump_status_header->dump_flag & AP_MINI_DUMP_ENABLE);
		*fulldump_status = !!(dump_status_header->dump_flag & AP_FULL_DUMP_ENABLE);
	}
	return 0;
}

//sysdump标志打开，并且reset 类型是panic的几种才进行sysdump
int is_dump_allow(int rst_mode, int status)
{
	int exc_mode;

	exc_mode = is_sysdump_boot_mode(rst_mode);

	if(status && exc_mode)
		return 1;

	return 0;
}

int is_sysdump_boot_mode(int rst_mode)
{
	int i;
	int len;

	len = sizeof(dump_mode) / sizeof(int);

#define TRUE 1
#define FALSE 0

	for(i = 0; i < len; i++) {
		if (rst_mode == dump_mode[i])
			return TRUE;
	}

	return FALSE;
}

/* boot modes that need enter sysdump, the new exception mode should be added here */
int dump_mode[] = {
	CMD_WATCHDOG_REBOOT,
	CMD_AP_WATCHDOG_REBOOT,
	CMD_UNKNOW_REBOOT_MODE,
	CMD_SPECIAL_MODE,
	CMD_PANIC_REBOOT,
	CMD_VMM_PANIC_MODE,
	CMD_TOS_PANIC_MODE,
	CMD_EXT_RSTN_REBOOT_MODE,
	CMD_ABNORMAL_REBOOT_MODE,
	CMD_BOOTLOADER_PANIC_MODE,
	CMD_SML_PANIC_MODE,
};
```

## 使能sysdump的方法
1. 使用fastboot 命令
`fastboot setdump $subcmd`

```c
char *fastboot_subcmd[] = {
	"full-enable",			//CMD_FULL_ENABLE
	"full-disable",			//CMD_FULL_DISABLE
	"mini-enable",			//CMD_MINI_ENABLE
	"mini-disable",			//CMD_MINI_DISABLE
	"status",			//CMD_STATUS
	"autoreboot-enable",		//CMD_AUTOREBOOT_ENABLE
	"autoreboot-disable",		//CMD_AUTOREBOOT_ENABLE
	"dataoutput",			//CMD_DATAOUTPUT
};
```

2. adb 命令
展锐提供工具systemDebuggerd
`/vendor/vendor/sprd/modules/sysdump/`

```c++
#define SPRD_SYSDUMP_CONFIG   "/proc/sprd_sysdump"
#define SPRD_SYSDUMP_PROP   "persist.vendor.sysdump"
#define VERSION_INFO "ro.product.name"
#define DEBUG_FULLDUMP_PROP  "vendor.debug.sysdump.enabled"
#define DEFAULT_PROP_VALUE  "error"
#define SPRD_7S_RESET_PROP "persist.vendor.eng.reset" /*0: soft mode, 1: hard mode*/

int get_ops_type(const char *ops)
{
	int enable = -1;
	if (!strcmp(ops, "true"))
		enable = 1;
	else if (!strcmp(ops, "false"))
		enable = 0;
	else
		ALOGD(" invalid ops  : %s , do nothing  \n", ops);
	return enable;
}

/* only prop status changed means modification ops*/
int is_modify_status(void)
{
	char fulldump_prop_enable[128] = {0};
	int modify_flag = 0;
	int status = -1;

	/*	judge fulldump modification ops */
	if (-1 == property_get(DEBUG_FULLDUMP_PROP, fulldump_prop_enable, DEFAULT_PROP_VALUE)) {
		ALOGD(" get prop error : %s : %s  \n", DEBUG_FULLDUMP_PROP, fulldump_prop_enable);
		return 0;
	} else {
		ALOGD("get prop ok : %s : %s  \n", DEBUG_FULLDUMP_PROP, fulldump_prop_enable);
		status = get_ops_type(fulldump_prop_enable);
		if(-1 == status ) {
			modify_flag = 0;
			ALOGD("modify_flag : %d , need do other ops ...... \n", modify_flag);
		} else {

			if(status)
				set_dump_status(FULL_DUMP_ENABLE);
			else
				set_dump_status(FULL_DUMP_DISENABLE);
			modify_flag = 1;
			ALOGD("modify_flag : %d , do not do other ops, return  ...... \n", modify_flag);
		}
	}
	return modify_flag;
}
```
命令：
```shell
setprop vendor.debug.sysdump.enabled true
systemDebuggerd
```