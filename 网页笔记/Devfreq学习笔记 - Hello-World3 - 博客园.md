# Devfreq学习笔记 - Hello-World3 - 博客园

### 一、简介

当今的复杂SoC由多个子模块协同工作组成。在执行各种用例的操作系统中，并非SoC中的所有模块都需要始终保持最高性能。为方便起见，将SoC中的子模块分组为域，从而允许某些域以较低的电压和频率运行，而其他域以较高的电压/频率对运行。

对于这些设备支持的频率和电压对，我们称之为OPP（Operating Performance Point）。对于具有OPP功能的非CPU设备，本文称之为OPP device，需要通过devfreq进行动态的调频调压。

devfreq：Generic Dynamic Voltage and Frequency Scaling (DVFS) Framework for Non-CPU Devices。是由三星电子MyungJoo Ham <myungjoo.ham@samsung.com>，提交到社区。原理和/deivers/cpufreq 非常近似。但是cpufreq驱动并不允许多个设备来注册，而且也不适合不同的设备具有不同的governor。devfreq则支持多个设备，并且允许每个设备有自己对应的governor。

如下图，devfreq framework是功耗子系统的一部分，与cpufreq，cpuidle，powermanager相互配合协作，已达到节省系统功耗的目的。

![Devfreq学习笔记 - Hello-World3 - 博客园-01](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-01.jpg)

### 二、核心数据结构

devfreq framework作为Linux Kernel一个子系统，需要为user space和其他子系统提供接口，已完成功能交互。本章从Kernel空间和user空间的角度，介绍devfreq framework的相关接口。

(1) devfreq_dev_profile 结构体，是OPP device注册到devfreq framework的数据结构，主要包含OPP设备的频率相关信息和相关的回调函数，是devfreq framework和OPP device driver的交互接口。类似设备驱动模型，将OPP device driver对devfreq使用，简化为devfreq profile结构体的填充。

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-02.jpg)

```c
struct devfreq_dev_profile {
    /*devfreq初始化频率*/
    unsigned long initial_freq;
    /*governor轮询的时间间隔，单位ms，0禁止*/
    unsigned int polling_ms;

    /*devfreq framework设置OPP device频率的回掉函数*/
    int (*target)(struct device *dev, unsigned long *freq, u32 flags);
    /*devfreq framework获取OPP device负载状态的回掉函数*/
    int (*get_dev_status)(struct device *dev, struct devfreq_dev_status *stat);
    /*devfreq framework获取OPP device当前频率的回掉函数*/
    int (*get_cur_freq)(struct device *dev, unsigned long *freq);
    /*devfreq framework退出时对OPP device的回掉函数*/
    void (*exit)(struct device *dev);

    /*OPP device支持的频率表*/
    unsigned long *freq_table;
    /*freq_table表的大小*/
    unsigned int max_state;
};
```

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-03.jpg)

(2) devfreq_governor 结构体，是governor注册到devfreq framework的数据结构，主要包含governor的相关属性和具体的函数实现。是devfreq framework和governor交互接口。

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-04.jpg)

```c
struct devfreq_governor {
    struct list_head node;

    /*该governor的名称*/
    const char name[DEVFREQ_NAME_LEN];
    /*governor是否可以切换的标志，若为1表示不可切换*/
    const unsigned int immutable;
    /*governor注册到devfreq framework的算法实现函数，返回调整后的频率*/
    int (*get_target_freq)(struct devfreq *this, unsigned long *freq);
    /*governor注册到devfreq framework的event处理函数，处理start,stop,suspend,resume等event*/
    int (*event_handler)(struct devfreq *devfreq, unsigned int event, void *data);
};
```

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-05.jpg)

(3) devfreq 设备结构体，这个是devfreq设备的核心数据结构。将上述的OPP device driver的 devfreq_dev_profile 和governor的 devfreq_governor 连接到一起，并通过设备驱动模型中device类，为user空间提供接口。

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-06.jpg)

```c
struct devfreq {
    struct list_head node;

    struct mutex lock;
    struct mutex event_lock;
    /*其class属于devfreq_class，父节点指向使用devfreq的device*/
    struct device dev;
    /*OPP device注册到devfreq framework的配置信息*/
    struct devfreq_dev_profile *profile;
    /*governor注册到devfreq framework的配置信息*/
    const struct devfreq_governor *governor;
    /*devfreq的governor的名字*/
    char governor_name[DEVFREQ_NAME_LEN];
    struct notifier_block nb;
    /*负载监控使用的delayed_work*/
    struct delayed_work work;

    unsigned long previous_freq;
    struct devfreq_dev_status last_status;
    /*OPP device传递给governor的私有数据*/
    void *data; /* private data for governors */

    ......
};
```

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-07.jpg)

### 三、工作流程

本章节主要介绍devfreq framework在系统中的工作流程，从初始化，频率调整，退出机制几个方便介绍devfreq framework的运行机制和函数调用逻辑。

1.初始化

(1) evfreq framework 初始化。

(2) governor初始化，然后add_governor。//int devfreq_add_governor(struct devfreq_governor \*governor)。

(3) OPP device创建devfreq，然后add_device。//struct devfreq \*devfreq_add_device(struct device \*dev, struct devfreq_dev_profile \*profile, const char \*governor_name, void \*data)

(1) evfreq framework 初始化

逻辑非常简单清晰，主要完成以下的任务，然后为governor的初始化和OPP device 创建devfreq device做好准备。代码实现：kernel/drivers/devfreq/

a.创建devfreq设备类。

b.创建工作队列，用于负载监控work调用运行。

c.加入到subsys_initcall，系统启动时初始化。

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-08.jpg)

```c
static int __init devfreq_init(void) //drivers/devfreq/devfreq.c
{
    /*创建devfreq设备类*/
    devfreq_class = class_create(THIS_MODULE, "devfreq");
    /*创建名为"devfreq"的工作队列，用于负载监控work的调度运行*/
    devfreq_wq = create_freezable_workqueue("devfreq_wq");

    devfreq_class->dev_groups = devfreq_groups;
}
subsys_initcall(devfreq_init);
```

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-09.jpg)

(2) governors初始化

系统中可支持多个governors，在系统启动时进行初始化，并注册到devfreq framework中， 后续OPP device创建devfreq设备，会根据governor名字从已经初始化好的governor 列表中，查找对应的governor实例。

a.填充governor的结构体，不同类型的governor，会有不同的实现。

b.将governor加入到devfreq framework的governor列表中。

c.加入到subsys_initcall，系统启动时初始化。

下面这个是以 simple_ondemand 这个governor来介绍governor的初始化和注册。

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-10.jpg)

```c
static struct devfreq_governor devfreq_simple_ondemand = {
    .name = DEVFREQ_GOV_SIMPLE_ONDEMAND, //"simple_ondemand"
    .get_target_freq = devfreq_simple_ondemand_func,
    .event_handler = devfreq_simple_ondemand_handler,
};

static int __init devfreq_simple_ondemand_init(void)
{
    return devfreq_add_governor(&devfreq_simple_ondemand);
}
subsys_initcall(devfreq_simple_ondemand_init);
```

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-11.jpg)

目前系统默认支持下面几种governor：

simple_ondemand：按需调整模式；根据系统负载动态频率，平衡性能和功耗

Performance：性能优先模式，调整到最大频率

Powersave：功耗优先模式，调整到最小频率

Userspace：用户指定模式，调整到用户设置的频率.

Passive：被动模式，使用设备指定方法做调整或跟随父devfreq设备的governor

可以根据自己的设备特性，通过填充 devfreq_governor 结构体和实现 get_target_freq 方法和 event_handler，完成的自己的governor。devfreq framework的架构设计对governor扩展，支持极好。

(3) OPP device通过devfreq framework创建devfreq device。

以UFS设备为例，介绍OPP device用devfreq framework来添加devfreq设备的过程。代码位置：kernel/drivers/scsi/ufs/ufshcd.c

首先，OPP device driver通过devfreq framework创建devfreq设备。

a.将ufs设备的core clk的添加到opp子系统中，devfreq_add_device 函数中，会从opp子系统中获取clk信息。

b.将OPP device相关频率信息和回调函数，并填充devfreq profile数据结构。

c.调用devfreq_add_device函数，将devfreq profile数据结构，governor名字，添加到devfreq framework。

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-12.jpg)

```c
static int ufshcd_devfreq_init(struct ufs_hba *hba)
{
    struct devfreq *devfreq;
    struct ufs_clk_scaling *scaling = &hba->clk_scaling;
    ......

    /*将可用最大最小频率添加到OPP子系统*/
    clki = list_first_entry(clk_list, struct ufs_clk_info, list);
    dev_pm_opp_add(hba->dev, clki->min_freq, 0);
    dev_pm_opp_add(hba->dev, clki->max_freq, 0);

    /*初始化devfreq配置结构体*/
    scaling->profile.polling_ms = 60;
    scaling->profile.target = ufshcd_devfreq_target;
    scaling->profile.get_dev_status = ufshcd_devfreq_get_dev_status;

    /*通过devfreq_add_device函数，配置文件和governor，创建devfreq设备*/
    devfreq = devfreq_add_device(hba->dev, &scaling->profile, DEVFREQ_GOV_SIMPLE_ONDEMAND, gov_data);

    ......
}
```

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-13.jpg)

devfreq_add_device 创建devfreq设备的流程如下：

a. 根据传入的governor名字，从governor列表中，获取对应的governor实例。

b.发送 DEVFREQ_GOV_START 到governor，开始管理OPP device的频率。

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-14.jpg)

```c
struct devfreq *devfreq_add_device(struct device *dev, struct devfreq_dev_profile *profile, const char *governor_name, void *data)
{
    ......
    /*通过governor的名字找到governor实例*/
    governor = find_devfreq_governor(devfreq->governor_name);
    ......
    /*发送DEVFREQ_GOV_START事件，governor开始管理频率*/
    devfreq->governor->event_handler(devfreq, DEVFREQ_GOV_START, NULL);
    ......
}
```

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-15.jpg)

2. 频率调整过程

![Devfreq学习笔记 - Hello-World3 - 博客园-16](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-16.jpg)

如上图所示，频率调整过程中，分工非常明确，devfreq framework是大管家负责监控程序的运行，governor提供管理算法，OPP device提供自身的负载状态和频率设置的方法实现。系统中有不同的governor，而且不同的governor有不同的管理算法，但是频率调整过程是一样的。本小节，以 simple_ondemand governor 为例，讲述governor的管理过程。

(1) governor 的 event_handler 收到 DEVFREQ_GOV_START 事件，调用对应的函数，调度工作队列，运行负载监控程序。

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-17.jpg)

```c
static int devfreq_simple_ondemand_handler(struct devfreq *devfreq, unsigned int event, void *data)
{
    switch (event) {
    case DEVFREQ_GOV_START:
        devfreq_monitor_start(devfreq); /*对应的DEVFREQ_GOV_START事件的处理函数*/
        break;

    case DEVFREQ_GOV_STOP:
        devfreq_monitor_stop(devfreq);
        break;

    case DEVFREQ_GOV_INTERVAL:
        devfreq_interval_update(devfreq, (unsigned int *)data);
        break;

    case DEVFREQ_GOV_SUSPEND:
        devfreq_monitor_suspend(devfreq);
        break;

    case DEVFREQ_GOV_RESUME:
        devfreq_monitor_resume(devfreq);
        break;

    default:
        break;
    }

    return 0;
}

void devfreq_monitor_start(struct devfreq *devfreq)
{
    /*开始提交“内核工作线程”监控负载状态*/
    INIT_DEFERRABLE_WORK(&devfreq->work, devfreq_monitor);
    if (devfreq->profile->polling_ms) {
        queue_delayed_work(devfreq_wq, &devfreq->work, msecs_to_jiffies(devfreq->profile->polling_ms));
    }
}
```

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-18.jpg)

(2) 负载监控程序。

a.调用 governor 的 get_target_freq 方法，获取下一次的调频目标值。

b.调用OPP device注册到 devfreq framework 的target函数，设置新的频率信息。

c.调度延迟工作队列，延迟OPP device 设置的轮询间隔后，再次运行。

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-19.jpg)

```c
int update_devfreq(struct devfreq *devfreq)
{
    /*获取要调频到的结果频率*/
    devfreq->governor->get_target_freq(devfreq, &freq);

    /*在调频前后都有通知发出来*/
    devfreq_notify_transition(devfreq, &freqs, DEVFREQ_PRECHANGE);
    /*调用OPP devices的target函数设置目标频率*/
    devfreq->profile->target(devfreq->dev.parent, &freq, flags);
    devfreq_notify_transition(devfreq, &freqs, DEVFREQ_POSTCHANGE);
}

static void devfreq_monitor(struct work_struct *work)
{

    err = update_devfreq(devfreq);

    /*进行以polling_ms为周期的周期监控*/
    queue_delayed_work(devfreq_wq, &devfreq->work, msecs_to_jiffies(devfreq->profile->polling_ms));
}
```

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-20.jpg)

(3) governor 的 get_target_freq 方法，调用opp device注册到devfreq framework的回调函数，获取当前device负载信息，根据算法，返回调整频率。

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-21.jpg)

```c
static inline int devfreq_update_stats(struct devfreq *df)
{
    if (df->profile->get_dev_status)
        /*调用OPP device注册到devfreq framework的回调函数，获取负载状态*/
        return df->profile->get_dev_status(df->dev.parent, &df->last_status);
    else
        return -ENODEV;
}

static int devfreq_simple_ondemand_func(struct devfreq *df, unsigned long *freq) /*.get_target_freq = devfreq_simple_ondemand_func*/
{
    /*获取设备当前状态*/
    err = devfreq_update_stats(df);

    stat = &df->last_status;

    /*然后使用stat与df->data指定的阈值比较，进行目标频率的设定*/
    if (data && data->simple_scaling) {
        if (stat->busy_time * 100 > stat->total_time * dfso_upthreshold) /*如果忙的时间大于70%,就给最大频率*/
            *freq = max;
        else if (stat->busy_time * 100 < stat->total_time * (dfso_upthreshold - dfso_downdifferential)) /*如果忙的时间小于5%,就给最小频率*/
            *freq = min;
        else
            *freq = df->previous_freq; /*否则还是之前频率*/
        return 0;
    }

}
```

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-22.jpg)

3. 删除devfreq设备

(1) 直接调用device_unregister函数注销devfreq设备。

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-23.jpg)

```c
int devfreq_remove_device(struct devfreq *devfreq)
{
    ...
    device_unregister(&devfreq->dev);
    ...
}
```

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-24.jpg)

(2) device_unregister 注销过程中会调用 devfreq_dev_release 函数，完成下面的事务。

a.发送 DEVFREQ_GOV_STOP event，governor停止运行；

b.回调OPP device注册到devfreq framework的exit函数；

c.释放devfreq device申请的资源。

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-25.jpg)

```c
static void devfreq_dev_release(struct device *dev) //devfreq_add_device()中初始化赋值的
{
    /*如果governor存在，发送DEVFREQ_GOV_STOP事件，停止governor运行*/
    if (devfreq->governor)
        devfreq->governor->event_handler(devfreq,  DEVFREQ_GOV_STOP, NULL);

    /*如果OPP device注册的有exit()，调用它*/
    if (devfreq->profile->exit)
        devfreq->profile->exit(devfreq->dev.parent);
}
```

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-26.jpg)

### 四、架构设计

1.devfreq framework将多种OPP device和多种governor进行抽象，对OPP device提供了统一的接口，来满足其对devfreq的需求。对governor提供统一的实现格式，为后续扩展不同governor，提供很好的架构支持。是一个典型的子系统实现模式。为后续在我们自己做子系统架构设计，提供了一个很好的参考。

![Devfreq学习笔记 - Hello-World3 - 博客园-27](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-27.jpg)

2. 用户空间文件节点

devfreq framework不仅为Kernel空间的设备驱动提供了标准化接口，也为user空间提供了标准化的文件节点，方便user空间的程序，更好的监控和修改。相关文件节点介绍内核文档：kernel/Documentation/ABI/testing/sysfs-class-devfreq(-event)。

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-28.jpg)

```
/sys/class/devfreq/xxx.ufshc # ls -l
-r--r--r-- 1 root root 4096 2020-06-07 18:15 available_frequencies
-r--r--r-- 1 root root 4096 2020-06-07 18:15 available_governors
-r--r--r-- 1 root root 4096 2020-06-07 18:15 cur_freq
lrwxrwxrwx 1 root root    0 2020-06-01 10:57 device -> ../../../xxx.ufshc
-rw-r--r-- 1 root root 4096 2020-06-07 18:15 governor
-rw-rw-r-- 1 root root 4096 2020-06-07 18:15 max_freq
-rw-rw-r-- 1 root root 4096 2020-06-07 18:15 min_freq
-rw-r--r-- 1 root root 4096 2020-06-07 18:15 polling_interval
drwxr-xr-x 2 root root    0 2020-06-07 18:15 power
lrwxrwxrwx 1 root root    0 2020-06-01 10:57 subsystem -> ../../../../../../class/devfreq
-r--r--r-- 1 root root 4096 2020-06-07 18:15 target_freq
-r--r--r-- 1 root root 4096 2020-06-07 18:15 trans_stat
-rw-r--r-- 1 root root 4096 1970-02-25 01:42 uevent
```

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-29.jpg)

available_frequencies: 可用的频率列表

available_governors：可用的governor

cur_freq：当前频率

governor: 当前governor

max_freq：最大频率

min_freq ：最小频率

polling_interval：governor调度的时间间隔，单位是ms.

target_freq：目标频率

trans_stat：状态调整表记录

代码实现位置：kernel/drivers/devfreq/devfreq.c //struct attribute \*devfreq_attrs[]

### 五、调试笔记和总结

1.可以cat trans_stat来查看频率转移表。

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-30.jpg)

```
/sys/class/devfreq/xxx.ufshc # cat trans_stat
     From  :   To
           :  37500000 300000000   time(ms)
*  37500000:         0       133   3343228
  300000000:       133         0    162660
Total transition : 266
```

![复制代码](img/Devfreq%E5%AD%A6%E4%B9%A0%E7%AC%94%E8%AE%B0%20-%20Hello-World3%20-%20%E5%8D%9A%E5%AE%A2%E5%9B%AD-31.jpg)

2.TODO: 解释每一个governor的算法
/sys/class/devfreq/xxx.ufshc # cat available_governors
cdspl3 compute mem_latency bw_hwmon vidc-ar50-llcc vidc-ar50-ddr msm-vidc-llcc msm-vidc-ddr gpubw_mon bw_vbif msm-adreno-tz userspace powersave performance simple_ondemand

参考： https://blog.csdn.net/feelabclihu/article/details/105592301
