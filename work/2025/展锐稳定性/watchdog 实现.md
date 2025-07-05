# watchdog 实现
![](vx_images/544708530757759.png =1053x)
![](../vx_images/447204933688208.png =1058x)

## AP和CM4 watchdog如何判断
lk中的定义
```C
  	"cm4_watchdog_timeout",                 //CMD_WATCHDOG_REBOOT,
  	"ap_watchdog_timeout",                  //CMD_AP_WATCHDOG_REBOOT,
```	

watchdog类型是根据 寄存器中值获取的，该值由硬件设定。
```C
unsigned check_reboot_mode(void)
{
    reboot_reg = rst_mode = ANA_REG_GET(ANA_REG_GLB_POR_RST_MONITOR);
    
    } else if(rst_mode == HWRST_STATUS_NORMAL2) {
			bootcause_cmdline="Reboot into watchdog";
			return CMD_WATCHDOG_REBOOT;
		} else if(rst_mode == HWRST_STATUS_NORMAL3) {
			bootcause_cmdline="Reboot into ap watchdog";
			return CMD_AP_WATCHDOG_REBOOT;
}
```

### bootloader的实现
bootloader阶段只有pmic watchdog
chipram代码: `vendor/bsp/bootloader/chipram/drivers/watchdog/sprd_wdt.c`
```C
//vendor/bsp/bootloader/chipram/arch/arm/cpu/armv8/qogirn6l/mcu.c
void Chip_Init (void) /*lint !e765 "Chip_Init" is used by init.s entry.s*/
{
    /* set watchdog 300s timeout */
  	start_watchdog(300 * 1000);
}

//start_watchdog 执行的内容
//使能WD的rtc clock
ANA_REG_OR (ANA_REG_GLB_ARM_MODULE_EN, BIT_ANA_WDG_EN); //WDG enable
ANA_REG_OR (ANA_REG_GLB_RTC_CLK_EN,    BIT_RTC_WDG_EN); //WDG Rtc enable
//解锁WD才能设置
ANA_REG_SET (WDG_LOCK, WDG_UNLOCK_KEY);
//如果是中断模式才使能中断
 case WDG_TIMEOUT_MODE_RESET:
	        ANA_REG_AND (WDG_CTRL, (~WDG_INT_EN_BIT));
	        break;

case WDG_TIMEOUT_MODE_INT:
	        ANA_REG_OR (WDG_CTRL, WDG_INT_EN_BIT);
	
//设置超时时间，等待load 完成后，才能进行下一次的设置
u32 cnt = 0;
	while((ANA_REG_GET(WDG_INT_RAW) & WDG_LD_BUSY_BIT) && ( cnt < ANA_WDG_LOAD_TIMEOUT_NUM ))
		cnt++;
	ANA_REG_SET( WDG_LOAD_HIGH, (u16)(((value) >> 16 ) & 0xffff));
	ANA_REG_SET( WDG_LOAD_LOW , (u16)((value)  & 0xffff) );
	
//如果是开始WD，使能计数器，如果是停止就禁用
case WDG_TIMER_STATE_STOP:
		ANA_REG_AND (WDG_CTRL, (~WDG_CNT_EN_BIT));
		break;

	case WDG_TIMER_STATE_START:
	        ANA_REG_OR (WDG_CTRL, WDG_CNT_EN_BIT | WDG_RST_EN_BIT);
	        break;
	        
//最后清除WD的解锁状态
ANA_REG_SET (WDG_LOCK, (~WDG_UNLOCK_KEY));
```

lk代码: `vendor/bsp/bootloader/lk/platform/sprd_shared/driver/watchdog/sprd_wdt.c`
lk中和chipram是一样的

### kernel的实现
Pmic watchdog 源码：
vendor/bsp/kernel5.15/kernel5.15/drivers/watchdog/sprd_pmic_wdt.c

pmic的watchdog 驱动主要设置相关的寄存器，看门狗触发时有中断和复位2种行为，可以单独使能这2种行为，
设置独立的超时时间。
主要的寄存器：
7.3.4.2.3 WDG_CTRL (add wdg_new wdg_rst_en)
Description: Watchdog control
![](../vx_images/69743273514689.png =696x)
bit0: 使能超时中断
bit1: 启动和停止计时器
bit2: 版本设置，新版本在加载值时不用判断忙位，只需要读取一次计数值
bit3: 使能超时重置

PMIC的watchdog只使能了reset，超时时间是300S, 每250S喂狗，关键代码如下：
 
```C
 //驱动probe 启动看门狗
 static int sprd_pmic_wdt_probe(struct platform_device *pdev)
{
    sprd_wdt_feeder_init(pmic_wdt);    
｝

static void sprd_wdt_feeder_init(struct sprd_pmic_wdt *pmic_wdt)
{
	int cpu = 0;
	do {
		pmic_wdt->feed_task = kthread_create_on_node(sprd_wdt_feeder,
							    pmic_wdt,
							    cpu_to_node(cpu),
							    "watchdog_feeder/%d",
							    cpu);

		kthread_bind(pmic_wdt->feed_task, cpu);
	} while (0);

	if (IS_ERR(pmic_wdt->feed_task))
		pr_err("Can't crate watchdog_feeder thread!\n");
	else {
		sprd_pmic_wdt_start(pmic_wdt);
		wake_up_process(pmic_wdt->feed_task);
		pr_err("sprd pmic wdt:pmic_timeout %d,feed %d\n", pmic_timeout, feed_period);
	}
	mutex_unlock(pmic_wdt->lock);
}
//启动看门狗
static int sprd_pmic_wdt_start(struct sprd_pmic_wdt *pmic_wdt)
{
	u32 val;
	int ret;

	sprd_pmic_wdt_load_value(pmic_wdt, pmic_timeout);
	sprd_pmic_wdt_unlock(pmic_wdt);
	ret = regmap_read(pmic_wdt->regmap, pmic_wdt->base + SPRD_PMIC_WDT_CTRL, &val);
	val |= SPRD_PMIC_WDT_CNT_EN_BIT | SPRD_PMIC_WDT_RST_EN_BIT;
	ret = regmap_write(pmic_wdt->regmap, pmic_wdt->base + SPRD_PMIC_WDT_CTRL, val);
	regmap_read(pmic_wdt->regmap, pmic_wdt->base + SPRD_PMIC_WDT_CTRL, &pmic_wdt->wdt_ctrl);
	sprd_pmic_wdt_lock(pmic_wdt);

	return 0;
}

static void pmic_wdt_kick(struct sprd_pmic_wdt *pmic_wdt)
{
	sprd_pmic_wdt_load_value(pmic_wdt, pmic_timeout);
}
//喂狗线程的函数
static int sprd_wdt_feeder(void *data)
{
	struct sprd_pmic_wdt *pmic_wdt = data;

	do {
		if (kthread_should_stop())
			break;

		if (pmic_wdt->wdt_enabled && !pmic_wdt->wdt_flag)
			pmic_wdt_kick(pmic_wdt);

		set_current_state(TASK_INTERRUPTIBLE);
		schedule_timeout(feed_period * HZ);
	} while (1);

	return 0;
}
```

pmic watchdog 驱动中会判断SP启动后，让SP接管PMIC 的狗，并停止pmic watchdog喂狗线程。
从这里也能理解为什么只有开机早期会出现abnormal mode的panic。

```C
//注册SP的钩子
rval = sbuf_register_notifier(SIPC_ID_PM_SYS, SMSG_CH_TTY, 0,
				      sprd_pmic_wdt_init, pmic_wdt);

//钩子函数中启动	wdt_kwork		      
static void sprd_pmic_wdt_init(int event, void *data)
{
	struct sprd_pmic_wdt *pmic_wdt = data;

	switch (event) {
	case SBUF_NOTIFY_READY:
		dev_info(pmic_wdt->dev, "sbuf ready for pmic wdt init!\n");
		pm_wakeup_event(pmic_wdt->dev, PMIC_WDT_WAKE_UP_MS);
		kthread_queue_work(&pmic_wdt->wdt_kworker, &pmic_wdt->wdt_kwork);
		pmic_wdt->wdt_flag = 1;
		break;
	case SBUF_NOTIFY_READ:
		if (!pmic_wdt->wdt_flag) {
			dev_info(pmic_wdt->dev, "sbuf read for pmic wdt init!\n");
			pm_wakeup_event(pmic_wdt->dev, PMIC_WDT_WAKE_UP_MS);
			kthread_queue_work(&pmic_wdt->wdt_kworker, &pmic_wdt->wdt_kwork);
			pmic_wdt->wdt_flag = 1;
		}
		break;
	default:
		return;
	}
}

//kwork的注册
kthread_init_worker(&pmic_wdt->wdt_kworker);
	kthread_init_work(&pmic_wdt->wdt_kwork, sprd_pmic_wdt_work);
	pmic_wdt->wdt_thread = kthread_run(kthread_worker_fn, &pmic_wdt->wdt_kworker,
					   "pmic_wdt_worker");
					   
//kwork的处理函数主要是根据cmdline的参数，获取cmd,然后发送给SP处理
if (!strncmp("wdten", pmic_wdt_info[i], strlen(pmic_wdt_info[i]))) {
			if (pmic_wdt->wdten)
				p_cmd = "watchdog on";
			else
				p_cmd = "watchdog rstoff";
		} else if (!strncmp("dswdten", pmic_wdt_info[i], strlen(pmic_wdt_info[i]))) {
			if (pmic_wdt->sleep_en)
				p_cmd = "dswdt on";
			else
				p_cmd = "dswdt off";
		}
		
nwrite = sbuf_write(SIPC_ID_PM_SYS, SMSG_CH_TTY, 0, p_cmd, len,
					    msecs_to_jiffies(timeout));
			pr_err("cm4 watchdog on/off: len = %d, nwrite = %d\n", len, nwrite);
			
//在SP中初始化完成后，停止pmic喂狗线程
regmap_read(pmic_wdt->regmap, pmic_wdt->base + SPRD_PMIC_WDT_LOAD_HIGH,
				    &val);
			if (val != SPRD_PMIC_WDT_LOAD_VAULE_HIGH && nwrite == len) {
				if (!IS_ERR_OR_NULL(pmic_wdt->feed_task)) {
					kthread_stop(pmic_wdt->feed_task);
					pmic_wdt->feed_task = NULL;
				}
				break;
			}
```

AP watchdog 源码：
vendor/bsp/kernel5.15/kernel5.15/drivers/unisoc_platform/hang_debug/sprd_wdf.c
vendor/bsp/kernel5.15/kernel5.15/drivers/watchdog/sprd_wdt_fiq.c

AP 的watchdog通过hang_debug 函数实现，其中sprd_wdt_fiq.c中实现了看门狗开始，启用禁用等
功能函数：
```C
//主要的功能函数
static const struct watchdog_ops sprd_wdt_fiq_ops = {
	.owner = THIS_MODULE,
	.start = sprd_wdt_fiq_start,
	.stop = sprd_wdt_fiq_stop,
	.set_timeout = sprd_wdt_fiq_set_timeout,
	.set_pretimeout = sprd_wdt_fiq_set_pretimeout,
	.get_timeleft = sprd_wdt_fiq_get_timeleft,
};

//因为只有在线CPU的线程会更新看门狗，当系统休眠时就需要禁用看门狗
int sprd_wdt_fiq_syscore_suspend(void)
{
	if (!wdt_fiq)
		return -ENODEV;

	if (!wdt_fiq->sleep_en) {
		if (watchdog_active(&wdt_fiq->wdd))
			sprd_wdt_fiq_stop(&wdt_fiq->wdd);

		if (!wdt_fiq->data->eb_always_on)
			sprd_wdt_fiq_disable(wdt_fiq);
	}
	return 0;
}
EXPORT_SYMBOL(sprd_wdt_fiq_syscore_suspend);

void sprd_wdt_fiq_syscore_resume(void)
{
	int ret;

	if (!wdt_fiq)
		return;

	ret = sprd_wdt_fiq_enable(wdt_fiq);
	if (ret)
		return;

	if (watchdog_active(&wdt_fiq->wdd)) {
		ret = sprd_wdt_fiq_start(&wdt_fiq->wdd);
		if (ret)
			return;
	}
}
EXPORT_SYMBOL(sprd_wdt_fiq_syscore_resume);

static struct syscore_ops sprd_wdt_fiq_syscore_ops = {
	.resume = sprd_wdt_fiq_syscore_resume,
	.suspend = sprd_wdt_fiq_syscore_suspend
};
```

AP watchdog的主要功能在hang_debug/sprd_wdf.c实现，主要通过为每个CPU创建独立线程，
并在线程中启动hrtimer 去喂狗，定时器时间设置为8S.
cpu_feed_mask记录了在线CPU的位掩码，cpu_feed_bitmap 记录已喂狗的CPU，当所有在线CPU
都喂狗了，就调用wdd->ops->start 喂AP 狗，然后清除cpu_feed_bitmap重新开始喂狗。

CPU线程的函数执行时机：
成员名称	类型/签名	作用	执行时机
.store	struct task_struct **	存储每个CPU线程的 task_struct 指针（内核内部使用）。	内核自动管理，用户无需干预。
.thread_should_run	bool (*)(unsigned int cpu)	检查线程是否应该继续运行（返回 false 时线程暂停）。每次线程循kthread_should_stop）。
.create	int (*)(unsigned int cpu)	线程创建时的自定义初始化（非必须）。	在 thread_fn 首次运行前调用（每CPU一次）。
.thread_fn	void (*)(unsigned int cpu)	线程的主函数，执行实际任务（如调试检测）。	线程启动后循环执行，直到 thread_should_run 返回 false 或线程被停止。
.thread_comm	const char *	线程名称模板（%u 替换为CPU编号）。	线程创建时使用（如生成 hang_debug/0、hang_debug/1）。
.setup	void (*)(unsigned int cpu)	CPU上线时的初始化（如启用硬件定时器）。	对应CPU被热插拔上线时调用。
.park	void (*)(unsigned int cpu)	CPU下线时线程挂起的清理操作（保存状态）。	对应CPU被热插拔下线时调用。
.unpark	void (*)(unsigned int cpu)	CPU重新上线时线程恢复的初始化操作（恢复状态）。	对应CPU从下线状态重新上线时调用。
```C
//创建每CPU的线程
BUG_ON(smpboot_register_percpu_thread(&hang_debug_threads));

static struct smp_hotplug_thread hang_debug_threads = {
	.store			= &hang_debug_task_store,
	.thread_should_run	= hang_debug_should_run,
	.create			= hang_debug_create,
	.thread_fn		= hang_debug_task,
	.thread_comm	= "hang_debug/%u",
	.setup			= sprd_wdf_hrtimer_enable,
	.park			= hang_debug_park,
	.unpark			= hang_debug_unpark,
};

//在线程设置前会执行，创建并启动定时器
static void sprd_wdf_hrtimer_enable(unsigned int cpu)
{
	struct hrtimer *hrtimer = this_cpu_ptr(&sprd_wdt_hrtimer);

	hrtimer_init(hrtimer, CLOCK_MONOTONIC, HRTIMER_MODE_REL);
	hrtimer->function = sprd_wdt_timer_func;
	hrtimer_start(hrtimer, ms_to_ktime(g_interval),
		      HRTIMER_MODE_REL_PINNED);
}

//定时器回调函数中唤醒线程的执行，并更新定时器重新计数
static enum hrtimer_restart sprd_wdt_timer_func(struct hrtimer *hrtimer)
{
	/**
	 * hrtimer_cancel will be called in disable wdt context, however,
	 * check wdt_disable here to bail out early. mutex shouldn't be
	 * added here to avoid dead-lock due to mutex would have been held
	 * before hrtimer_cancel.
	 */
	if (wdt_disable) {
		pr_debug("hrtimer func: wdt_disable\n");
		return HRTIMER_NORESTART;
	}

	__this_cpu_write(g_enable, 1);
	wake_up_process(__this_cpu_read(hang_debug_task_store));
	hrtimer_forward_now(hrtimer, ms_to_ktime(g_interval));
	return HRTIMER_RESTART;
}

//线程执行函数中，判断在线CPU都已喂狗，就会重置AP 狗，并清除CPU喂狗标志
static void hang_debug_task(unsigned int cpu)
{

	mutex_lock(&wdf_mutex);
	if (wdt_disable)
		goto out;

	cpu_feed_bitmap |= (1U << cpu);
	if (cpu_feed_mask == cpu_feed_bitmap) {
		pr_debug("feed wdt cpu_feed_bitmap = 0x%08x\n", cpu_feed_bitmap);
		cpu_feed_bitmap = 0;
#if IS_ENABLED(CONFIG_SPRD_WATCHDOG_FIQ)
		if (wdd->ops->start)
			wdd->ops->start(wdd);
#endif
	} else
		pr_debug("cpu_feed_bitmap = 0x%08x\n", cpu_feed_bitmap);

	__this_cpu_write(g_enable, 0);
out:
	mutex_unlock(&wdf_mutex);
}

//CPU下线时，关闭定时器，并清除该CPU在线标志，喂一次AP狗
static void hang_debug_park(unsigned int cpu)
{
	struct hrtimer *hrtimer = this_cpu_ptr(&sprd_wdt_hrtimer);

	mutex_lock(&wdf_mutex);
	cpu_feed_mask &= (~(1U << cpu));
	cpu_feed_bitmap = 0;
	pr_debug("offline cpu = %u\n", cpu);

	if (wdt_disable)
		goto out;
#if IS_ENABLED(CONFIG_SPRD_WATCHDOG_FIQ)
	if (wdd->ops->start)
		wdd->ops->start(wdd);
#endif
	hrtimer_cancel(hrtimer);
out:
	mutex_unlock(&wdf_mutex);
}

//CPU上线时，重启定时器，设置该CPU在线标志，喂一次AP狗
static void hang_debug_unpark(unsigned int cpu)
{

	mutex_lock(&wdf_mutex);
	cpu_feed_mask |= (1U << cpu);
	cpu_feed_bitmap = 0;
	pr_debug("online cpu = %u\n", cpu);

	if (wdt_disable)
		goto out;
#if IS_ENABLED(CONFIG_SPRD_WATCHDOG_FIQ)
	if (wdd->ops->start)
		wdd->ops->start(wdd);
#endif
	hrtimer_start(this_cpu_ptr(&sprd_wdt_hrtimer),
			ms_to_ktime(g_interval),
			HRTIMER_MODE_REL_PINNED);
out:
	mutex_unlock(&wdf_mutex);
}
```
