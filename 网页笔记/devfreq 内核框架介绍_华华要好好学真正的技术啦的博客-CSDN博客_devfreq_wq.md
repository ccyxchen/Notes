# (176条消息) devfreq 内核框架介绍_华华要好好学真正的技术啦的博客-CSDN博客_devfreq_wq

**目录**

[一 应用背景](https://blog.csdn.net/weixin_39059738/article/details/104260671#%E4%B8%80.%E5%BA%94%E7%94%A8%E8%83%8C%E6%99%AF)

[二 软件框架介绍](https://blog.csdn.net/weixin_39059738/article/details/104260671#%E4%BA%8C.%E8%BD%AF%E4%BB%B6%E6%A1%86%E6%9E%B6%E4%BB%8B%E7%BB%8D)

[三 API和用户接口](https://blog.csdn.net/weixin_39059738/article/details/104260671#%E4%B8%89%20API%E4%BB%8B%E7%BB%8D)

[3.1 device注册接口介绍](https://blog.csdn.net/weixin_39059738/article/details/104260671#3.1%20device%E6%B3%A8%E5%86%8C%E6%8E%A5%E5%8F%A3%E4%BB%8B%E7%BB%8D)

[3.2 governor使用接口介绍](https://blog.csdn.net/weixin_39059738/article/details/104260671#3.2%20governor%E4%BD%BF%E7%94%A8%E6%8E%A5%E5%8F%A3%E4%BB%8B%E7%BB%8D)

[3.2.1 governor注册接口](https://blog.csdn.net/weixin_39059738/article/details/104260671#3.2.1%20governor%E6%B3%A8%E5%86%8C%E6%8E%A5%E5%8F%A3)

[3.2.2 governor调频接口](https://blog.csdn.net/weixin_39059738/article/details/104260671#3.2.2%C2%A0%20governor%E8%B0%83%E9%A2%91%E6%8E%A5%E5%8F%A3)

[3.2.3 monitor机制接口](https://blog.csdn.net/weixin_39059738/article/details/104260671#3.2.3%20monitor%E6%9C%BA%E5%88%B6%E6%8E%A5%E5%8F%A3)

[3.3 用户层接口](https://blog.csdn.net/weixin_39059738/article/details/104260671#3.3%20%E7%94%A8%E6%88%B7%E5%B1%82%E6%8E%A5%E5%8F%A3)

[四 编程模板](https://blog.csdn.net/weixin_39059738/article/details/104260671#%E5%9B%9B.%E7%BC%96%E7%A8%8B%E6%A8%A1%E6%9D%BF)

[4.1 dts配置](https://blog.csdn.net/weixin_39059738/article/details/104260671#4.1%20dts%E9%85%8D%E7%BD%AE)

[4.1.1 定义工作性能表：](https://blog.csdn.net/weixin_39059738/article/details/104260671#4.1.1%20%E5%AE%9A%E4%B9%89%E5%B7%A5%E4%BD%9C%E6%80%A7%E8%83%BD%E8%A1%A8%EF%BC%9A)

[4.1.2 引用工作性能表：](https://blog.csdn.net/weixin_39059738/article/details/104260671#4.1.2%20%E5%BC%95%E7%94%A8%E5%B7%A5%E4%BD%9C%E6%80%A7%E8%83%BD%E8%A1%A8%EF%BC%9A)

[4.2 底层driver实现](https://blog.csdn.net/weixin_39059738/article/details/104260671#4.2%20%E5%BA%95%E5%B1%82driver%E5%AE%9E%E7%8E%B0)

[4.2.1 底层driver需要实现的回调函数](https://blog.csdn.net/weixin_39059738/article/details/104260671#4.2.1%20%E5%BA%95%E5%B1%82driver%E9%9C%80%E8%A6%81%E5%AE%9E%E7%8E%B0%E7%9A%84%E5%9B%9E%E8%B0%83%E5%87%BD%E6%95%B0)

[4.2.2 probe时注册devfreq框架](https://blog.csdn.net/weixin_39059738/article/details/104260671#4.2.2%20probe%E6%97%B6%E6%B3%A8%E5%86%8Cdevfreq%E6%A1%86%E6%9E%B6)

[4.3 governor的注册](https://blog.csdn.net/weixin_39059738/article/details/104260671#4.3%20governor%E7%9A%84%E6%B3%A8%E5%86%8C)

[4.3.1 governor需要实现的回调函数](https://blog.csdn.net/weixin_39059738/article/details/104260671#4.3.1%20governor%E9%9C%80%E8%A6%81%E5%AE%9E%E7%8E%B0%E7%9A%84%E5%9B%9E%E8%B0%83%E5%87%BD%E6%95%B0)

[4.3.2 governor向devfreq的注册](https://blog.csdn.net/weixin_39059738/article/details/104260671#4.3.2%20governor%E5%90%91devfreq%E7%9A%84%E6%B3%A8%E5%86%8C)

[五 框架分析](https://blog.csdn.net/weixin_39059738/article/details/104260671#%E4%BA%94.%20%E6%A1%86%E6%9E%B6%E5%88%86%E6%9E%90)

[5.1 devfreq框架初始化](https://blog.csdn.net/weixin_39059738/article/details/104260671#5.1%20devfreq%E6%A1%86%E6%9E%B6%E5%88%9D%E5%A7%8B%E5%8C%96)

[5.2 对device的管理](https://blog.csdn.net/weixin_39059738/article/details/104260671#5.2%20%E5%AF%B9device%E7%9A%84%E7%AE%A1%E7%90%86)

# 一 应用背景

对于可以调频的设备，我们可以通过在不同场景和需求下调节设备的频率，可以达到节省功耗的目的。CPU有单独的cpufreq[框架](https://so.csdn.net/so/search?q=%E6%A1%86%E6%9E%B6&spm=1001.2101.3001.7020)来控制和管理其频率，但是不兼容普通的设备。对于普通设备，我们可以通过devfreq 框架来方便地实现调频操作。

# 二 软件框架介绍

devfreq框架存在的意义，是为了将调频逻辑的公共部分，比如数据结构，调频方法等抽象出来，减少重复代码的产生，方便驱动工程师实现设备的调频操作。

我们这里将有调频需求的设备称为device_freq，以便后续的讨论。有了devfreq框架，驱动工程师只需要按照devfreq框架提供的函数原型，实现具体设备的具体调频操作，同时选取合适的governor，并将device_freq和底层调频方法一同注册进devfreq框架，就能够实现调频。

这里的governor ,其实指的是不同的调频策略。所谓的调频策略，包括什么时候对设备进行调频，以及将设备的频率调整到多大。不同的设备，有不同的调频策略，因此devfreq将设备的调频策略抽象出来，以供设备选择。具体的设备也可以根据自己的需求，实现自己的governor，并注册进devfreq框架。以内核提供的最简单的userspace_governor为例 ，其调频策略就很简单——调频的时机是当用户通过给定的文件节点输入目标频率F时，就执行调频操作；且将设备的频率调整为F。

以上提到的两个概念，device_freq和 governor，是devfreq框架的两个核心主题，这里做一个总结：

1. device_freq，是需要调频的设备，需要通过devfreq框架提供的接口进行注册；

2. governor，是具体的调频策略，也需要通过devfreq框架提供的接口进行注册；governor可由用户自己实现，也可以选用内核已有的governor。

整体上，devfreq的软件框架如下所示：

![(176条消息) devfreq 内核框架介绍_华华要好好学真正的技术啦的博客-CSDN博客_devfreq_wq-01](img/(176%E6%9D%A1%E6%B6%88%E6%81%AF)%20devfreq%20%E5%86%85%E6%A0%B8%E6%A1%86%E6%9E%B6%E4%BB%8B%E7%BB%8D_%E5%8D%8E%E5%8D%8E%E8%A6%81%E5%A5%BD%E5%A5%BD%E5%AD%A6%E7%9C%9F%E6%AD%A3%E7%9A%84%E6%8A%80%E6%9C%AF%E5%95%A6%E7%9A%84%E5%8D%9A%E5%AE%A2-CSDN%E5%8D%9A%E5%AE%A2_devfreq_wq-01.jpg)

上图中，devfreq框架内部维护了两个链表，一个链表Governor_list是用于管理系统中所有注册进来的governor，还有一个devfreq_list 是用于管理系统中所有的可调频的设备device_freq。

一个拥有opp_table的可调频设备，需要实现自己的调频函数（图中的xxx_devfreq_profile），再通过devfreq提供的接口（devm_devfreq_add_device）来注册进devfreq框架。在注册时，device_freq会指定自己的governor，devfreq框架负责将device_freq和governor进行匹配 。

用户可以实现自己的governor，并通过接口（devfreq_add_governor）注册进devfreq框架。

# 三 API和用户接口

## 3.1 device注册接口介绍

device_freq通过接口devm_devfreq_add_device注册进devfreq框架：该接口的定义如下所示：

```cpp
struct devfreq *devm_devfreq_add_device(struct device *dev,
                    struct devfreq_dev_profile *profile,
                    const char *governor_name,
                    void *data);
```

设备在调用该函数时，device_freq需要传递四个参数：

1. @dev：设备的device结构体

2. @governor_name：调频设备必须指定一个governor，因为没有governor就无法实现调频。device_freq注册时，devfreq框架会根据该字段自动寻找匹配的governor ，将二者关联。

3. @data：该字段用于governor和device_freq之间传递信息，由用户自己定义，框架并不关心这个数据。

4. @profile: 该profile是一个结构体，类似于去银行注册银行卡时填写的信息表，定义如下（讲解见注释）：

```cpp
struct devfreq_dev_profile {
    /* 在注册时，设备初始的工作频率，必须 */
    unsigned long initial_freq;
    /*
     * 当governor启动monitor机制时，monitor会每隔一定的时间更新设备的频率，这个位段就指定了该
     * 时间间隔。当该值为0时，表示不启用monitor机制。
     */
    unsigned int polling_ms;
    /* 底层设备的调频函数，设备必须自己实现该函数，并在注册时通过该结构体提供给框架 */
    int (*target)(struct device *dev, unsigned long *freq, u32 flags);
    /* 该函数目前很少被用到，可以不实现 */
    int (*get_dev_status)(struct device *dev,
            ¦   ¦ struct devfreq_dev_status *stat);
    /* 底层设备的获取当前设备频率的函数，设备必须自己实现该函数，并提供给框架 */
    int (*get_cur_freq)(struct device *dev, unsigned long *freq);
    /* 可选的退出函数，当devfreq设备发生错误时，框架会回调该函数。一般不需要实现。 */
    void (*exit)(struct device *dev);
    /*
     * 设备支持的频点表。如果已经在dts中引用了opp_table，并通过dev_pm_opp_of_add_table
     * 关联到opp_table，以下两个字段会由devfreq自动填入。
     */
    unsigned long *freq_table;
    /* 该设备最多支持的频点数 */
    unsigned int max_state;
};
```

可见，该profile结构体包含了device_freq设备在注册进devfreq框架时需要填写的所有信息，其中必须提供的信息包括：

- 初始频率initial_freq；
- 设备调频函数target
- 设备当前频率的获取函数get_cur_freq

另外，devfreq框架需要知道设备支持的所有频点。因此可以在profile中将freq_table和max_state填写，注册的时候由devfreq框架读取；但是更加规范的方法是在dts中引用一个opp_table，然后在设备注册进devfreq框架前，调用dev_pm_opp_of_add_table将设备和opp_table相关联；这样，devfreq框架会自动读取设备的opp_table，将信息整合，代替freq_table和 max_state字段。

## 3.2 governor使用接口介绍

### 3.2.1 governor注册接口

governor的注册接口比较简单：

```cpp
int devfreq_add_governor(struct devfreq_governor *governor);
```

这里，重点关注传参类型struct devfreq_governor：

```cpp
struct devfreq_governor {
    struct list_head node;

    const char name[DEVFREQ_NAME_LEN];
    const unsigned int immutable;
    int (*get_target_freq)(struct devfreq *this, unsigned long *freq);
    int (*event_handler)(struct devfreq *devfreq,
                unsigned int event, void *data);
};
```

governor结构体由以下几个部分组成：

- 节点node，用于加入全局链表governor_list
- governor的名字，用于在device注册进来时进行匹配
- immutable 标志位，当置为1时，表示使用该governor的设备不可以动态更换其他的governor
- get_target_freq回调函数，是具体的调频策略实现，用于给出某个时间点设备的目标调节频率，也是整个governor的核心操作之一。
- event_handler回调函数，用于处理框架发送给governor的事件。典型的事件包括：DEVFREQ_GOV_START，DEVFREQ_GOV_STOP等。例如，当有设备注册进框架，并匹配到该governor时，devfreq框架调用该函数，并传递DEVFREQ_GOV_START事件类型。

### 3.2.2  governor调频接口

前面提到，governor负责具体的调频策略，也就是说，何时进行调频也是governor决定的。比如，userspace_governor的策略，就是当用户通过文件节点输入设备频率时，开始进行调频操作。governor可通过调用以下接口进行调频：

```cpp
int update_devfreq(struct devfreq *devfreq);
```

第一眼看到这个函数或许会有疑惑，为什么传参里面没有出现目标频率这个参数？调用完这个函数，设备的频率会变成多少？事实上，该函数内部会先调用governor->get_target_freq 回调函数获取governor推荐的目标频率，然后再调用设备的target回调函数，实现一次具体的调频操作。

### 3.2.3 monitor机制接口

devfreq为governor实现了一种基本的调频策略，就是每隔一段时间就调用 update_devfreq函数更新设备的频率，称之为monitor机制。monitor机制的相关API包括：

```cpp
extern void devfreq_monitor_start(struct devfreq *devfreq);
extern void devfreq_monitor_stop(struct devfreq *devfreq);
extern void devfreq_monitor_suspend(struct devfreq *devfreq);
extern void devfreq_monitor_resume(struct devfreq *devfreq);
```

start接口用于开启monitor模式，可以在devfreq向governor 发送DEVFREQ_GOV_START事件时调用该函数；

stop接口用于开关闭monitor模式，可以在devfreq向governor 发送DEVFREQ_GOV_STOP事件时调用该函数；

suspend接口用于暂停monitor模式，可以在devfreq向governor 发送DEVFREQ_GOV_SUSPEND事件时调用该函数；

resume接口用于暂停monitor模式，可以在devfreq向governor 发送DEVFREQ_GOV_RESUME事件时调用该函数；

## 3.3 用户层接口

所有注册进devfreq框架的设备，都会在/sys/class/devfreq/xxxx-device/下生成以下文件节点：

| 节点名称 | 读操作 | 写操作 |
| --- | --- | --- |
| governor | 返回device的governor名称 | 写入目标governorB的名字，可以替换当前governorA |
| available governors | 获取所有支持的governor名字 | 不支持 |
| cur_freq | 获取设备当前的频率 | 不支持 |
| target_freq | 获取上一个使用的频点 | 不支持 |
| polling_interval | 获取当前值 | 修改当前值 |
| min_freq | 获取设备支持的最小值 | 修改设备支持的最小值 |
| max_freq | 获取设备支持的最大值 | 修改设备支持的最大值 |
| available frequencies | 获取设备支持的所有频点信息 | 不支持 |
| trans_state | 获取设备的调频历史纪录 | 不支持 |

# 四 编程模板

## 4.1 dts配置

### 4.1.1 定义工作性能表：

对于使用devfreq框架的设备，都需要在dts中预先定义一个工作性能表。例如，对于可以工作在三个频点上的设备，可以在dts中预先定义以下的性能工作表：

```cpp
xxx_opp_table: xxx_opp_table {
    compatible = "operating-points-v2";

    opp@800000000 {
        opp-hz = /bits/ 64 <800000000>;
    };
    opp@3200000000 {
        opp-hz = /bits/ 64 <3200000000>;
    };
    opp@3800000000 {
        opp-hz = /bits/ 64 <3800000000>;
    };
};
```

内核在初始化的过程中，会通过opp框架，将以上的性能表添加至一个全局的链表中。

### 4.1.2 引用工作性能表：

定义好性能表后，在device对应的dts中引用对应的性能表：

```cpp
xxx: xxx_dev {
    ...;
    operating-points-v2 = <&xxx_opp_table>;
}
```

## 4.2 底层driver实现

### 4.2.1 底层driver需要实现的回调函数

底层driver必须实现两个回调函数：

1. 调频动作的具体实现，target函数；

2. 当前device的工作频率的获取，get_cur_freq函数；

例程如下所示：

```cpp
static int xxx_freq_target(struct device *dev, unsigned int *freq, u32 flags)
{
    struct dev_pm_opp *opp;
    unsigned long rate;
    rcu_read_lock();
    /* 根据参数freq，遍历device引用的性能表，匹配最接近的性能点opp */
    opp = devfreq_recommended_opp(dev, freq, flags);
    if (IS_ERR(opp)) {
        rcu_read_unlock();
        printk(KERN_ERR "failed to find opp for %lu hz\n", *freq);
        return PTR_ERR(opp);
    }
    /* 获取性能点opp中的频率信息 */
    rate = dev_pm_opp_get_freq(opp);
    rcu_read_unlock();

    /* 根据具体调频的方法，进行调频操作 */
    return xxx_change_rate(rate);
}

static int xxx_get_cur_freq(struct device *dev, unsigned long *freq)
{
    unsigned long rate;

    /* 根据device具体的方法，获得当前device的工作频率 */
    rate = xxx_get_freq(...);
    *freq = rate;
    return 0
}

static struct devfreq_dev_profile xxx_devfreq_profile = {
    .polling_ms = 0,
    .target = xxx_freq_target,
    .get_cur_freq = xxx_get_cur_freq,
}
```

### 4.2.2 probe时注册devfreq框架

注册包含两步：

1.将device添加至opp框架；

2.将device和其实现的回调函数添加至devfreq框架，并指定governor。

例程代码如下所示：（这里governor使用的是userspace）

```cpp
static int xxx_probe(struct platform_device *pdev)

{
    struct device *dev = &pdev->dev;
    int ret;

    ...;
    /* 1. 将device和dts中引用的opp表相关联 */
    ret = dev_pm_opp_of_add_table(dev);
    if (ret)
        printk(KERN_ERR, "cannot add opp table!\n");

    xxx_devfreq_profile.initial_freq = xxxx;
    /* 2. 将device注册到devfreq框架, governer设置为userspace */
    ret = devm_devfreq_add_device(dev, &xxx_devfreq_profile, "userspace", NULL);
    if (ret)
        printk(KERN_ERR, "cannot add device to devfreq!\n");
    ...;

}
```

## 4.3 governor的注册

对于一个支持dvfs的设备，若想通过devfreq框架管理该设备的调频调压，必须同时实现该设备的governor ，因为核心的调频操作，需要governor的调频策略，给出目标频率。

下面以governor_userspace为例，说明governor的注册方法。

### 4.3.1 governor需要实现的回调函数

governor在向框架注册时，需要提前准备好两个回调函数：

1.get_target_freq：该函数用于实现具体的调频策略，给出governor建议的目标调节频率。对于userspace_governor来说，其调频策略很简单，目标频率就是用户通过文件节点输入的频率。

2.event_handler：该函数用于处理devfreq框架向governor发送的事件。典型的事件包括：

- 当有设备注册进devfreq框架，且该设备的governor设定为该governor时，框架向governor发送DEVFREQ_GOV_START事件。
- 当有设备从devfreq框架注销，且该设备的governor设定为该governor时，框架向governor发送DEVFREQ_GOV_STOP事件。
- ...

以上两个回调函数，governor_userspace的实现代码如下所示：

```cpp
struct userspace_data {
    unsigned long user_frequency;
    bool valid;
};

/* userspace_governor给出的目标频率来自用户层的输入 */
static int devfreq_userspace_func(struct devfreq *df, unsigned long *freq)
{
    struct userspace_data *data = df->data;

    /* 每次当用户通过文件节点设置目标频率时，data将被更新 */
    if (data->valid)
        *freq = data->user_frequency;
    else
        *freq = df->previous_freq; /* No user freq specified yet */

    return 0;
}

/* userspace_governor只处理START和STOP两个事件 */
static int devfreq_userspace_handler(struct devfreq *devfreq,
            unsigned int event, void *data)
{
    int ret = 0;

    switch (event) {
    case DEVFREQ_GOV_START:
        ret = userspace_init(devfreq);
        break;
    case DEVFREQ_GOV_STOP:
        userspace_exit(devfreq);
        break;
    default:
        break;
    }

    return ret;
}

static struct devfreq_governor devfreq_userspace = {
    .name = "userspace",
    .get_target_freq = devfreq_userspace_func,
    .event_handler = devfreq_userspace_handler,
};
```

其中，我们重点关注userspace_init函数。使用该governor的设备注册进devfreq框架时，会调用该函数：

```cpp
static struct attribute *dev_entries[] = {
    &dev_attr_set_freq.attr,
    NULL,
};
static const struct attribute_group dev_attr_group = {
    .name   = DEVFREQ_GOV_USERSPACE, //"userspace"
    .attrs  = dev_entries,
};
static int userspace_init(struct devfreq *devfreq)
{
    int err = 0;
    struct userspace_data *data = kzalloc(sizeof(struct userspace_data),
                    ¦   ¦ GFP_KERNEL);

    if (!data) {
        err = -ENOMEM;
        goto out;
    }
    data->valid = false;
    devfreq->data = data;

    err = sysfs_create_group(&devfreq->dev.kobj, &dev_attr_group);
out:
    return err;
}
```

可以看出，userspace_init函数为使用该governor的设备在/sys文件系统下添加了名为"userspace"文件夹，并且该文件夹下有一个名为"set_freq"的节点。通过该节点，我们可以进行调频操作和读取当前设备频率的操作。 相关代码如下所示：

```cpp
static ssize_t store_freq(struct device *dev, struct device_attribute *attr,
            ¦ const char *buf, size_t count)
{
    struct devfreq *devfreq = to_devfreq(dev);
    struct userspace_data *data;
    unsigned long wanted;
    int err = 0;

    mutex_lock(&devfreq->lock);
    data = devfreq->data;
    /* 读取用户输入的目标频率 */
    sscanf(buf, "%lu", &wanted);
    data->user_frequency = wanted;
    data->valid = true;
    /* 调用核心的调频函数，对该设备进行调频 */
    err = update_devfreq(devfreq);
    if (err == 0)
        err = count;
    mutex_unlock(&devfreq->lock);
    return err;
}

static ssize_t show_freq(struct device *dev, struct device_attribute *attr,
            ¦char *buf)
{
    struct devfreq *devfreq = to_devfreq(dev);
    struct userspace_data *data;
    int err = 0;

    mutex_lock(&devfreq->lock);
    data = devfreq->data;

    if (data->valid)
        err = sprintf(buf, "%lu\n", data->user_frequency);
    else
        err = sprintf(buf, "undefined\n");
    mutex_unlock(&devfreq->lock);
    return err;
}

static DEVICE_ATTR(set_freq, 0644, show_freq, store_freq);
```

### 4.3.2 governor向devfreq的注册

当准备好以上回调函数后，就可以将通过devfreq提供的接口devfreq_add_governor，将governor注册进devfreq框架。以governor_userspace为例，governor的注册方法如下：

```cpp
static int __init devfreq_userspace_init(void)
{
    return devfreq_add_governor(&devfreq_userspace);
}
subsys_initcall(devfreq_userspace_init);
```

# 五 框架分析

## 5.1 devfreq框架初始化

devfreq框架的初始化很简单，只是在sys/class/目录下创建了名为devfreq的类，并指定了该类下面的所有device所具备的文件属性。具体代码如下所示：

```cpp
static int __init devfreq_init(void)
{
    /* 创建devfreq类 */
    devfreq_class = class_create(THIS_MODULE, "devfreq");
    if (IS_ERR(devfreq_class)) {
        pr_err("%s: couldn't create class\n", __FILE__);
        return PTR_ERR(devfreq_class);
    }
    /* 创建工作队列 */
    devfreq_wq = create_freezable_workqueue("devfreq_wq");
    if (!devfreq_wq) {
        class_destroy(devfreq_class);
        pr_err("%s: couldn't create workqueue\n", __FILE__);
        return -ENOMEM;
    }
    devfreq_class->dev_groups = devfreq_groups;

    return 0;
}
subsys_initcall(devfreq_init);
```

这样，所有注册进devfreq框架的device，在其目录下都会自动创建以下文件节点：

```cpp
static struct attribute *devfreq_attrs[] = {
    &dev_attr_governor.attr,
    &dev_attr_available_governors.attr,
    &dev_attr_cur_freq.attr,
    &dev_attr_available_frequencies.attr,
    &dev_attr_target_freq.attr,
    &dev_attr_polling_interval.attr,
    &dev_attr_min_freq.attr,
    &dev_attr_max_freq.attr,
    &dev_attr_trans_stat.attr,
    NULL,
};
ATTRIBUTE_GROUPS(devfreq);
```

## 5.2 对device的管理

devfreq框架很大一部分代码是对注册进来的device的管理。我们可以从3.2.2小节中device向devfreq注册的接口devm_devfreq_add_device入手，对相关代码进行分析。

devm_devfreq_add_device函数内部主要调用了函数devfreq_add_device，该函数较长，我们节选核心的部分进行分析：

1. 首先在全局链表devfreq_list中，查看该设备是否已经注册，如果已经注册，直接返回错误：

```cpp
struct devfreq *devfreq_add_device(struct device *dev,
                ¦  struct devfreq_dev_profile *profile,
                ¦  const char *governor_name,
        /       ¦  void *data)
{
    struct devfreq *devfreq;
    struct devfreq_governor *governor;
    static atomic_t devfreq_no = ATOMIC_INIT(-1);
    int err = 0;

    ...;
    mutex_lock(&devfreq_list_lock);
    devfreq = find_device_devfreq(dev);
    mutex_unlock(&devfreq_list_lock);
    if (!IS_ERR(devfreq)) {
        dev_err(dev, "%s: Unable to create devfreq for the device.\n",
            __func__);
        err = -EINVAL;
        goto err_out;
    }
    ...;
```

2. 然后，为内部使用的devfreq类型的特殊设备分配内存，并对其进行初始化。这里，特别注意，注册进来的设备，成为内部的devfreq设备的父设备，而且，注册时 profile必须提供设备的初始频率 initial_freq：

```cpp
    /* devfreq内部使用结构体struct devfreq来管理设备 */
    devfreq = kzalloc(sizeof(struct devfreq), GFP_KERNEL);
    if (!devfreq) {
        err = -ENOMEM;
        goto err_out;
    }

    mutex_init(&devfreq->lock);
    mutex_lock(&devfreq->lock);
    /* 其父设备为注册进来的device，这样，内部维护的devfreq设备就和原注册设备相关联起来 */
    devfreq->dev.parent = dev;
    devfreq->dev.class = devfreq_class;
    devfreq->dev.release = devfreq_dev_release;
    devfreq->profile = profile;
    strncpy(devfreq->governor_name, governor_name, DEVFREQ_NAME_LEN);
    devfreq->previous_freq = profile->initial_freq;
    devfreq->last_status.current_frequency = profile->initial_freq;
    devfreq->data = data;
    ....
```

3. devfreq框架是如何知道该设备支持哪些频点的呢？一种方式是device在注册进来的时候，通过profile结构体，预先设填好freq_table和max_state字段，显然这种方式比较笨，一般不会使用；还有一种方式，就是由devfreq框架通过设备注册时的传参device，使用opp框架的帮助函数来读取该设备支持的opp_table。相关代码如下所示：

```cpp
    if (!devfreq->profile->max_state && !devfreq->profile->freq_table) {
        mutex_unlock(&devfreq->lock);
        err = set_freq_table(devfreq);
        if (err < 0)
            goto err_dev;
        mutex_lock(&devfreq->lock);
    }
```

其中核心的处理函数set_freq_table，首先通过dev_pm_opp_get_opp_count获取设备的频点数，将该频点数设置为max_state的值。再动态分配freq_table，使用dev_pm_opp_find_freq_ceil依次读取与设备关联的opp_table中的频率值，填充进freq_table中。相关代码如下：

```cpp
static int set_freq_table(struct devfreq *devfreq)
{
    struct devfreq_dev_profile *profile = devfreq->profile;
    struct dev_pm_opp *opp;
    unsigned long freq;
    int i, count;
    /* Initialize the freq_table from OPP table */
    count = dev_pm_opp_get_opp_count(devfreq->dev.parent);
    if (count <= 0)
        return -EINVAL;

    profile->max_state = count;
    profile->freq_table = devm_kcalloc(devfreq->dev.parent,
                    profile->max_state,
                    sizeof(*profile->freq_table),
                    GFP_KERNEL);
    if (!profile->freq_table) {
        profile->max_state = 0;
        return -ENOMEM;
    }

    for (i = 0, freq = 0; i < profile->max_state; i++, freq++) {
        opp = dev_pm_opp_find_freq_ceil(devfreq->dev.parent, &freq);
        if (IS_ERR(opp)) {
            devm_kfree(devfreq->dev.parent, profile->freq_table);
            profile->max_state = 0;
            return PTR_ERR(opp);
        }
        dev_pm_opp_put(opp);
        profile->freq_table[i] = freq;
    }

    return 0;
}
```

4. 根据device的opp_table读取最大值和最小值：

```cpp
    devfreq->scaling_min_freq = find_available_min_freq(devfreq);
    if (!devfreq->scaling_min_freq) {
        mutex_unlock(&devfreq->lock);
        err = -EINVAL;
        goto err_dev;
    }
    devfreq->min_freq = devfreq->scaling_min_freq;

    devfreq->scaling_max_freq = find_available_max_freq(devfreq);
    if (!devfreq->scaling_max_freq) {
        mutex_unlock(&devfreq->lock);
        err = -EINVAL;
        goto err_dev;
    }
    devfreq->max_freq = devfreq->scaling_max_freq;
```

5. 根据profile指定的名字绑定具体的governor，并将新创建的devfreq添加至全局的链表统一管理：

```cpp
    governor = try_then_request_governor(devfreq->governor_name);
    if (IS_ERR(governor)) {
        dev_err(dev, "%s: Unable to find governor for the device\n",
            __func__);
        err = PTR_ERR(governor);
        goto err_init;
    }

    devfreq->governor = governor;
    err = devfreq->governor->event_handler(devfreq, DEVFREQ_GOV_START,
                        NULL);
    if (err) {
        dev_err(dev, "%s: Unable to start governor for the device\n",
            __func__);
        goto err_init;
    }

    list_add(&devfreq->node, &devfreq_list);
```

//TODO增加对governor管理的文档；增加统一文件节点的介绍
