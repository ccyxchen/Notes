# magic键触发panic
触发方式：同时按住Vu Vd,再双击pwr key
代码：
`vendor\bsp\kernel5.15\kernel5.15\drivers\unisoc_platform\sysdump\unisoc_sysdump.c`
该功能通过sysdump 驱动实现，驱动初始化时注册了输入句柄检测按键输入事件，当同时按住音量加减再双击
电源键，就会触发回调函数里的BUG_ON。
```C
//注册输入句柄
static int sysdump_sysctl_init(void)
{
	if (input_register_handler(&sysdump_handler))
		pr_err("regist sysdump_handler failed.\n");
		
//句柄实现
static struct input_handler sysdump_handler = {
	.event = sysdump_event,
	.connect	= sysdump_connect,
	.disconnect	= sysdump_disconnect,
	.name = "sysdump_crashkey",
	.id_table	= sysdump_ids,
};

//输入事件处理函数，只处理KEY类型
static void sysdump_event(struct input_handle *handle,
	unsigned int type, unsigned int code, int value)
{
	if (type == EV_KEY && code != BTN_TOUCH)
		sprd_debug_check_crash_key(code, value);
}

//处理按键判断
void sprd_debug_check_crash_key(unsigned int code, int value)
{
	static unsigned int volup_p;
	static unsigned int voldown_p;
	static unsigned int loopcount;
	static unsigned long vol_pressed;

	/*  Enter Force Upload
	 *  hold the volume down and volume up
	 *  and then press power key twice
	 */
	if (value) {
		if (code == KEY_VOLUMEUP)
			volup_p = SYSDUMP_MAGIC_VOLUP;
		if (code == KEY_VOLUMEDOWN)
			voldown_p = SYSDUMP_MAGIC_VOLDN;

		if ((volup_p == SYSDUMP_MAGIC_VOLUP) && (voldown_p == SYSDUMP_MAGIC_VOLDN)) {
			if (!vol_pressed)
				vol_pressed = jiffies;

			if (code == KEY_POWER) {
				pr_info("%s: Crash key count : %d,vol_pressed:%ld\n", __func__,
					++loopcount, vol_pressed);
				if (time_before(jiffies, vol_pressed + 5 * HZ)) {
#if (!defined CONFIG_SPRD_DEBUG && defined CONFIG_SPRD_CLOSE_CRASH_KEY)
					if ((loopcount == 2) && (atomic_read(&sysdump_status) == 1))
						BUG_ON(1);
					else
						pr_info("On user version and sysdump is disabled, crash key do not trigger panic.\n");
#else
					if (loopcount == 2)
						BUG_ON(1);
#endif
				} else {
					pr_info("%s: exceed 5s(%u) between power key and volup/voldn key\n",
						__func__, jiffies_to_msecs(jiffies - vol_pressed));
					volup_p = 0;
					voldown_p = 0;
					loopcount = 0;
					vol_pressed = 0;
				}
			}
		}
	} else {
		if (code == KEY_VOLUMEUP) {
			volup_p = 0;
			loopcount = 0;
			vol_pressed = 0;
		}
		if (code == KEY_VOLUMEDOWN) {
			voldown_p = 0;
			loopcount = 0;
			vol_pressed = 0;
		}
	}
}
```
