# minidump和sysdump原理
## minidump基础
sysdumpdb分区数据存储格式

|                     susdumpdb 空间分布                     |             |
| --------------------------------------------------------- | ----------- |
| struct dumpdb_header                                      |             |
| struct mini_data_header                                   |             |
| struct mini_area_info*5                                   |             |
| struct mini_area_header                                   | area 部分X5 |
| struct mini_section_info\* area section num               | area 部分   |
| mini_area_header->section_num \*mini_section_info->s_size | area 部分   |

minidump 是基于展锐的sysdump 驱动，该驱动会使用一块预留的内存区域保存sysdump和minidump的结构体。
其中minidump的关键结构体为：
```c
/* the struct to save minidump all infomation  */
struct minidump_info{
	char kernel_magic[6];  				  /* make sure minidump data valid */
	struct regs_info regs_info;			  /* | struct pt_regs | 			*/
	struct regs_memory_info regs_memory_info;	  /* | memory amount regs |  , need paddr and size, if paddr invalid set it as 0  */
	struct section_info_total section_info_total;	  /* | sections | , text,rodata,page_table ....,may be logbuf in here */
	int minidump_elfhdr_size;			  /* minidump elfhdr data size: update in uboot  */
	int minidump_elfhdr_size_comp;			  /* minidump elfhdr data size,after compressed  */
	struct minidump_data_desc  desc;		  /* minidump contents description */
	int minidump_data_size;				  /* minidump data total size: regs_all_size + reg_memory_all_size + section_all_size  */
	int compressed;					  /* indicate if minidump data compressed */
	struct exception_info_item exception_info;	  /* exception info */
};

struct section_info_total{
	struct section_info section_info[SECTION_NUM_MAX];
	int total_size;
	int total_num;
};

struct section_info{
	char section_name[SECTION_NAME_MAX];
	/*Get teh value in kernel use to record elfhdr info in uboot*/
	unsigned long section_start_vaddr;
	unsigned long section_end_vaddr;
	/*Get the value in kernel by __pa  use to get memory contents in uboot */
	unsigned long section_start_paddr;
	unsigned long section_end_paddr;
	int section_size;
	int section_size_comp; 			/* size after compressed  */
};

//需要保存的子系统log存放在section_info结构体中，每个section_info对应一份log，log的内存是子系统自己申请
的，其物理地址保存在section_start_paddr和section_end_paddr

//新建minidump的section：
/**
 * save extend debug information of modules in minidump, such as: cm4, iram...
 *
 * @name:	the name of the modules, and the string will be a part
 *		of the file name.
 *		note: special characters can't be included in the file name,
 *		such as:'?','*','/','\','<','>',':','"','|'.
 *
 * @paddr_start:the start paddr in memory of the modules debug information
 * @paddr_end:	the end paddr in memory of the modules debug information
 *
 * Return: 0 means success, -1 means fail.
 */
int minidump_save_extend_information(const char *name, unsigned long paddr_start,
								unsigned long paddr_end)
```
开机LK阶段会检测硬件寄存器，判断发生dump后，保存minidump到sysdumpdb 分区
重启到系统，使用minidumpd 程序将新出现的sysdumpdb 内容解析到/data/minidump 目录下

minidumpd 程序：system/vendor/sprd/modules/minidump/
该程序读取sysdumpdb 内保存的结构体信息，提取出minidump 文件

本地编译出mindump的x86 版本，可以提取sysdumpdb 导出分区文件

### LK 导出minidump
#### lk 中处理minidump的源码
`vendor/bsp/bootloader/lk/app/sprdboot/minidump.c`
reset mode (int) 和对应的字符串：
```C
/* NOTE: the array need be updated on the basis of 'boot_mode_enum_type' */
char *rstmode[CMD_MAX_MODE] = {
	"undefind mode",			//CMD_UNDEFINED_MODE=0,
	"power down",				//CMD_POWER_DOWN_DEVICE,
	"normal",				//CMD_NORMAL_MODE,
	"download",				//CMD_DOWNLOAD_MODE
	"recovery",				//CMD_RECOVERY_MODE,
	"fastboot",				//CMD_FASTBOOT_MODE,
	"alarm",				//CMD_ALARM_MODE,
	"charge",				//CMD_CHARGE_MODE,
	"engtest",				//CMD_ENGTEST_MODE,
	"cm4_watchdog_timeout",			//CMD_WATCHDOG_REBOOT ,
	"ap_watchdog_timeout",			//CMD_AP_WATCHDOG_REBOOT ,
	"framework crash",			//CMD_SPECIAL_MODE,
	"manual_dump",				//CMD_UNKNOW_REBOOT_MODE,
	"kernel_crash",				//CMD_PANIC_REBOOT,
	"vmm_panic",				//CMD_VMM_PANIC_MODE
	"tos_panic",				//CMD_TOS_PANIC_MODE
	"ext rstn reboot",                      //CMD_EXT_RSTN_REBOOT_MODE,
	"calibration",				//CMD_CALIBRATION_MODE,
	"usb mux",                              //CMD_USB_MUX_MODE
	"autodloader",				//CMD_AUTODLOADER_REBOOT,
	"autotest",				//CMD_AUTOTEST_MODE,
	"iq reboot",				//CMD_IQ_REBOOT_MODE,
	"sleep",				//CMD_SLEEP_MODE,
	"sprd disk",				//CMD_SPRDISK_MODE,
	"apk mmi",				//CMD_APKMMI_MODE,
	"upt",					//CMD_UPT_MODE,
	"apkmmi auto",				//CMD_APKMMI_AUTO_MODE,
	"abnormal mode",                        //CMD_ABNORMAL_REBOOT_MODE,
	"silent",                               //CMD_SILENT_MODE,
	"bootloader panic",                     //CMD_BOOTLOADER_PANIC_MODE,
	"sml panic",				//CMD_SML_PANIC_MODE,
};
```
##### 寄存器说明
ANA_REG_GLB_POR_SRC_FLAG:
![](../vx_images/593505268496001.png =796x)
ANA_REG_GLB_POR_RST_MONITOR:
![](../vx_images/285384322374828.png =800x)
WDG_INT_RAW:
![](../vx_images/183535170005544.png =788x)
![](../vx_images/285365199988899.png =779x)
![](../vx_images/385072883171549.png =770x)

##### 流程图：
[lk中的dump流程图.drawio](../lk中的dump流程图.drawio)
#### lk 中处理sysdump的源码
`vendor/bsp/bootloader/lk/app/sprdboot/sysdump.c`

### kernel的sysdump机制

sysdump 驱动在初始化时会注册一些钩子函数，在发生panic, 处理器间中断停止，reboot 等事件时，会执行相应的函数，
这些函数负责保存关键的寄存器和堆栈数据到sysdump的结构体。

代码：
`vendor/bsp/kernel5.15/kernel5.15/drivers/unisoc_platform/sysdump/`
```makefile
sysdump-$(CONFIG_SPRD_SYSDUMP) += \
		unisoc_sysdump.o \
		unisoc_vmcoreinfo.o \
		last_kmsg.o

obj-$(CONFIG_SPRD_SYSDUMP) += sysdump.o

native_hang_monitor-$(CONFIG_SPRD_NATIVE_HANG_MONITOR) += hang_monitor.o sprd_modules_notify.o
obj-$(CONFIG_SPRD_NATIVE_HANG_MONITOR) += native_hang_monitor.o

obj-$(CONFIG_UNISOC_LASTKMSG)	+= unisoc_last_kmsg.o
unisoc_last_kmsg-y := unisoc_dump_info.o
unisoc_last_kmsg-$(CONFIG_UNISOC_DUMP_IO)   += unisoc_dump_io.o
```
#### panic的原因和堆栈获取
```C
struct exception_info_item {
	char kernel_magic[8];  /* "K2.0" :make sure excep data valid */
	char exception_serialno[EXCEPTION_INFO_SIZE_SHORT];
	char exception_kernel_version[EXCEPTION_INFO_SIZE_MID];
	char exception_reboot_reason[EXCEPTION_INFO_SIZE_SHORT];
	char exception_panic_reason[EXCEPTION_INFO_SIZE_SHORT];
	char exception_time[EXCEPTION_INFO_SIZE_SHORT];
	char exception_file_info[EXCEPTION_INFO_SIZE_SHORT];
	int  exception_task_id;
	char exception_task_family[EXCEPTION_INFO_SIZE_SHORT];
	char exception_pc_symbol[EXCEPTION_INFO_SIZE_SHORT];
	char exception_stack_info[EXCEPTION_INFO_SIZE_LONG];
};

//reason 是由panic的通知回调函数传入的，该值由panic提供
struct notifier_block {
	notifier_fn_t notifier_call;
	struct notifier_block __rcu *next;
	int priority;
};

typedef	int (*notifier_fn_t)(struct notifier_block *nb,
			unsigned long action, void *data);

static struct notifier_block sysdump_panic_event_nb = {
	.notifier_call	= sysdump_panic_event,
	.priority	= INT_MAX - 2,
};

//stack的获取
//通过current 获取panic的堆栈，核心的接口是
entries  = stack_trace_save_tsk(cur, stack_entries, MAX_STACK_TRACE_DEPTH, 0);

for (i = 0; i < entries; i++) {
		off = strlen(sprd_minidump_info->exception_info.exception_stack_info);
		plen = EXCEPTION_INFO_SIZE_LONG - ALIGN(off, 8);
		if (plen > 16) {
			sz = snprintf(symbol, 96, "[<%lx>] %pS\n",
					(unsigned long)stack_entries[i],
					(void *)stack_entries[i]);
			if (ALIGN(sz, 8) - sz) {
				memset_io(symbol + sz - 1, ' ', ALIGN(sz, 8) - sz);
				memset_io(symbol + ALIGN(sz, 8) - 1, '\n', 1);
			}
			if (ALIGN(sz, 8) <= plen)
				memcpy(
				sprd_minidump_info->exception_info.exception_stack_info + ALIGN(off, 8),
				symbol, ALIGN(sz, 8));
		}
	}
```

%pS 的作用
1. 内核调试专用

%pS 是 Linux 内核特有的格式说明符，用于将内核地址转换为可读的符号信息（如函数名、偏移量等）。

需要内核配置 CONFIG_KALLSYMS 支持（启用符号表）。

2. 输出格式

若地址能解析到符号：函数名+偏移量（如 do_sys_open+0x10）。

若无法解析：直接显示 16 进制地址（类似 %px）。