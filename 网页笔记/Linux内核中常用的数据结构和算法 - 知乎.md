# Linux内核中常用的数据结构和算法 - 知乎

首发于

[异步图书](https://www.zhihu.com/column/epubit)

写文章

登录

![Linux内核中常用的数据结构和算法](img/Linux%E5%86%85%E6%A0%B8%E4%B8%AD%E5%B8%B8%E7%94%A8%E7%9A%84%E6%95%B0%E6%8D%AE%E7%BB%93%E6%9E%84%E5%92%8C%E7%AE%97%E6%B3%95%20-%20%E7%9F%A5%E4%B9%8E-01.jpg)

Linux内核中常用的数据结构和算法[

![人邮异步社区](img/Linux%E5%86%85%E6%A0%B8%E4%B8%AD%E5%B8%B8%E7%94%A8%E7%9A%84%E6%95%B0%E6%8D%AE%E7%BB%93%E6%9E%84%E5%92%8C%E7%AE%97%E6%B3%95%20-%20%E7%9F%A5%E4%B9%8E-02.jpg)

](https://www.zhihu.com/people/epubit)[人邮异步社区](https://www.zhihu.com/people/epubit)官方微信：异步社区，人民邮电出版社旗下IT专业图书旗舰社区342 人赞同了该文章

Linux内核代码中广泛使用了数据结构和算法，其中最常用的两个是链表和红黑树。

## 链表

Linux内核代码大量使用了链表这种数据结构。链表是在解决数组不能动态扩展这个缺陷而产生的一种数据结构。链表所包含的元素可以动态创建并插入和删除。链表的每个元素都是离散存放的，因此不需要占用连续的内存。链表通常由若干节点组成，每个节点的结构都是一样的，由有效数据区和指针区两部分组成。有效数据区用来存储有效数据信息，而指针区用来指向链表的前继节点或者后继节点。因此，链表就是利用指针将各个节点串联起来的一种存储结构。

**（1）单向链表**

单向链表的指针区只包含一个指向下一个节点的指针，因此会形成一个单一方向的链表，如下代码所示。

```text
struct list {
    int data;   /*有效数据*/
    struct list *next; /*指向下一个元素的指针*/
};
```

如图所示，单向链表具有单向移动性，也就是只能访问当前的节点的后继节点，而无法访问当前节点的前继节点，因此在实际项目中运用得比较少。

![Linux内核中常用的数据结构和算法 - 知乎-03](img/Linux%E5%86%85%E6%A0%B8%E4%B8%AD%E5%B8%B8%E7%94%A8%E7%9A%84%E6%95%B0%E6%8D%AE%E7%BB%93%E6%9E%84%E5%92%8C%E7%AE%97%E6%B3%95%20-%20%E7%9F%A5%E4%B9%8E-03.jpg)

单向链表示意图

**（2）双向链表**

如图所示，双向链表和单向链表的区别是指针区包含了两个指针，一个指向前继节点，另一个指向后继节点，如下代码所示。

```text
struct list {
    int data;   /*有效数据*/
    struct list *next; /*指向下一个元素的指针*/
    struct list *prev; /*指向上一个元素的指针*/
};
```

![Linux内核中常用的数据结构和算法 - 知乎-04](img/Linux%E5%86%85%E6%A0%B8%E4%B8%AD%E5%B8%B8%E7%94%A8%E7%9A%84%E6%95%B0%E6%8D%AE%E7%BB%93%E6%9E%84%E5%92%8C%E7%AE%97%E6%B3%95%20-%20%E7%9F%A5%E4%B9%8E-04.jpg)

双向链表示意图

**（3）Linux[内核链表](https://www.zhihu.com/search?q=%E5%86%85%E6%A0%B8%E9%93%BE%E8%A1%A8&search_source=Entity&hybrid_search_source=Entity&hybrid_search_extra=%7B%22sourceType%22%3A%22article%22%2C%22sourceId%22%3A58087261%7D)实现**

单向链表和双向链表在实际使用中有一些局限性，如数据区必须是固定数据，而实际需求是多种多样的。这种方法无法构建一套通用的链表，因为每个不同的数据区需要一套链表。为此，Linux内核把所有链表操作方法的共同部分提取出来，把不同的部分留给代码编程者自己去处理。Linux内核实现了一套纯链表的封装，链表节点数据结构只有指针区而没有数据区，另外还封装了各种操作函数，如创建[节点函数](https://www.zhihu.com/search?q=%E8%8A%82%E7%82%B9%E5%87%BD%E6%95%B0&search_source=Entity&hybrid_search_source=Entity&hybrid_search_extra=%7B%22sourceType%22%3A%22article%22%2C%22sourceId%22%3A58087261%7D)、插入节点函数、删除节点函数、遍历节点函数等。

Linux内核链表使用struct list_head数据结构来描述。

```text
<include/linux/types.h>

struct list_head {
    struct list_head *next, *prev;
};
```

struct list_head数据结构不包含[链表节点](https://www.zhihu.com/search?q=%E9%93%BE%E8%A1%A8%E8%8A%82%E7%82%B9&search_source=Entity&hybrid_search_source=Entity&hybrid_search_extra=%7B%22sourceType%22%3A%22article%22%2C%22sourceId%22%3A58087261%7D)的数据区，通常是嵌入其他数据结构，如struct page数据结构中嵌入了一个[lru链表节点](https://www.zhihu.com/search?q=lru%E9%93%BE%E8%A1%A8%E8%8A%82%E7%82%B9&search_source=Entity&hybrid_search_source=Entity&hybrid_search_extra=%7B%22sourceType%22%3A%22article%22%2C%22sourceId%22%3A58087261%7D)，通常是把page数据结构挂入[LRU链表](https://www.zhihu.com/search?q=LRU%E9%93%BE%E8%A1%A8&search_source=Entity&hybrid_search_source=Entity&hybrid_search_extra=%7B%22sourceType%22%3A%22article%22%2C%22sourceId%22%3A58087261%7D)。

```text
<include/linux/mm_types.h>

struct page {
    ...
    struct list_head lru;
    ...
}
```

链表头的初始化有两种方法，一种是静态初始化，另一种动态初始化。把next和prev指针都初始化并指向自己，这样便初始化了一个带头节点的空链表。

```text
<include/linux/list.h>

/*静态初始化*/
#define LIST_HEAD_INIT(name) { &(name), &(name) }

#define LIST_HEAD(name) \
    struct list_head name = LIST_HEAD_INIT(name)

/*动态初始化*/
static inline void INIT_LIST_HEAD(struct list_head *list)
{
    list->next = list;
    list->prev = list;
}
```

添加节点到一个链表中，内核提供了几个接口函数，如list_add()是把一个节点添加到表头，list_add_tail()是插入表尾。

```text
<include/linux/list.h>

void list_add(struct list_head *new, struct list_head *head)
list_add_tail(struct list_head *new, struct list_head *head)
```

遍历节点的[接口函数](https://www.zhihu.com/search?q=%E6%8E%A5%E5%8F%A3%E5%87%BD%E6%95%B0&search_source=Entity&hybrid_search_source=Entity&hybrid_search_extra=%7B%22sourceType%22%3A%22article%22%2C%22sourceId%22%3A58087261%7D)。

```text
#define list_for_each(pos, head) \
for (pos = (head)->next; pos != (head); pos = pos->next)
```

这个宏只是遍历一个一个节点的当前位置，那么如何获取节点本身的数据结构呢？这里还需要使用list_entry()宏。

```text
#define list_entry(ptr, type, member) \
    container_of(ptr, type, member)
container_of()宏的定义在kernel.h头文件中。
#define container_of(ptr, type, member) ({            \
    const typeof( ((type *)0)->member ) *__mptr = (ptr);    \
    (type *)( (char *)__mptr - offsetof(type,member) );})

#define offsetof(TYPE, MEMBER) ((size_t) &((TYPE *)0)->MEMBER)
```

其中offsetof()宏是通过把0地址转换为type类型的指针，然后去获取该结构体中member成员的指针，也就是获取了member在type结构体中的偏移量。最后用指针ptr减去offset，就得到type结构体的真实地址了。

下面是遍历链表的一个例子。

```text
<drivers/block/osdblk.c>

static ssize_t class_osdblk_list(struct class *c,
                struct class_attribute *attr,
                char *data)
{
    int n = 0;
    struct list_head *tmp;

    list_for_each(tmp, &osdblkdev_list) {
        struct osdblk_device *osdev;

        osdev = list_entry(tmp, struct osdblk_device, node);

        n += sprintf(data+n, "%d %d %llu %llu %s\n",
            osdev->id,
            osdev->major,
            osdev->obj.partition,
            osdev->obj.id,
            osdev->osd_path);
    }
    return n;
}
```

## 红黑树

红黑树（Red Black Tree）被广泛应用在内核的内存管理和进程调度中，用于将排序的元素组织到树中。红黑树被广泛应用在计算机科学的各个领域中，它在速度和实现复杂度之间提供一个很好的平衡。

红黑树是具有以下特征的二叉树。

每个节点或红或黑。

- 每个叶节点是黑色的。
- 如果结点都是红色，那么两个子结点都是黑色。
- 从一个[内部结点](https://www.zhihu.com/search?q=%E5%86%85%E9%83%A8%E7%BB%93%E7%82%B9&search_source=Entity&hybrid_search_source=Entity&hybrid_search_extra=%7B%22sourceType%22%3A%22article%22%2C%22sourceId%22%3A58087261%7D)到叶结点的简单路径上，对所有叶节点来说，黑色结点的数目都是相同的。

红黑树的一个优点是，所有重要的操作（例如插入、删除、搜索）都可以在*O*(log *n*)时间内完成，*n*为树中元素的数目。经典的算法教科书都会讲解红黑树的实现，这里只是列出一个内核中使用红黑树的例子，供读者在实际的驱动和内核编程中参考。这个例子可以在[内核代码](https://www.zhihu.com/search?q=%E5%86%85%E6%A0%B8%E4%BB%A3%E7%A0%81&search_source=Entity&hybrid_search_source=Entity&hybrid_search_extra=%7B%22sourceType%22%3A%22article%22%2C%22sourceId%22%3A58087261%7D)的documentation/Rbtree.txt文件中找到。

```text
#include <linux/init.h>
#include <linux/list.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/slab.h>
#include <linux/mm.h>
#include <linux/rbtree.h>

MODULE_AUTHOR("figo.zhang");
MODULE_DESCRIPTION(" ");
MODULE_LICENSE("GPL");

  struct mytype {
     struct rb_node node;
     int key;
};

/*红黑树根节点*/
 struct rb_root mytree = RB_ROOT;
/*根据key来查找节点*/
struct mytype *my_search(struct rb_root *root, int new)
  {
     struct rb_node *node = root->rb_node;

     while (node) {
          struct mytype *data = container_of(node, struct mytype, node);

          if (data->key > new)
               node = node->rb_left;
          else if (data->key < new)
               node = node->rb_right;
          else
               return data;
     }
     return NULL;
  }

/*插入一个元素到红黑树中*/
  int my_insert(struct rb_root *root, struct mytype *data)
  {
     struct rb_node **new = &(root->rb_node), *parent=NULL;

     /* 寻找可以添加新节点的地方 */
     while (*new) {
          struct mytype *this = container_of(*new, struct mytype, node);

          parent = *new;
          if (this->key > data->key)
               new = &((*new)->rb_left);
          else if (this->key < data->key) {
               new = &((*new)->rb_right);
          } else
               return -1;
     }

     /* 添加一个新节点 */
     rb_link_node(&data->node, parent, new);
     rb_insert_color(&data->node, root);

     return 0;
  }

static int __init my_init(void)
{
     int i;
     struct mytype *data;
     struct rb_node *node;

     /*插入元素*/
     for (i =0; i < 20; i+=2) {
          data = kmalloc(sizeof(struct mytype), GFP_KERNEL);
          data->key = i;
          my_insert(&mytree, data);
     }

     /*遍历红黑树，打印所有节点的key值*/
      for (node = rb_first(&mytree); node; node = rb_next(node))
          printk("key=%d\n", rb_entry(node, struct mytype, node)->key);

     return 0;
}

static void __exit my_exit(void)
{
     struct mytype *data;
     struct rb_node *node;
     for (node = rb_first(&mytree); node; node = rb_next(node)) {
          data = rb_entry(node, struct mytype, node);
          if (data) {
                rb_erase(&data->node, &mytree);
                kfree(data);
          }
     }
}
module_init(my_init);
module_exit(my_exit);
```

mytree是红黑树的根节点，my_insert()实现插入一个元素到红黑树中，my_search()根据key来查找节点。内核大量使用红黑树，如虚拟地址空间VMA的管理。

## 无锁环形缓冲区

生产者和消费者模型是计算机编程中最常见的一种模型。生产者产生数据，而消费者消耗数据，如一个网络设备，硬件设备接收网络包，然后应用程序读取网络包。环形缓[冲区](https://www.zhihu.com/search?q=%E5%86%B2%E5%8C%BA&search_source=Entity&hybrid_search_source=Entity&hybrid_search_extra=%7B%22sourceType%22%3A%22article%22%2C%22sourceId%22%3A58087261%7D)是实现生产者和消费者模型的经典算法。环形缓冲区通常有一个读指针和一个写指针。读指针指向[环形缓冲区](https://www.zhihu.com/search?q=%E7%8E%AF%E5%BD%A2%E7%BC%93%E5%86%B2%E5%8C%BA&search_source=Entity&hybrid_search_source=Entity&hybrid_search_extra=%7B%22sourceType%22%3A%22article%22%2C%22sourceId%22%3A58087261%7D)中可读的数据，写指针指向环形缓冲区可写的数据。通过移动读指针和写指针实现缓冲区数据的读取和写入。

在Linux内核中，KFIFO是采用无锁环形缓冲区的实现。FIFO的全称是“First In First Out”，即先进先出的数据结构，它采用环形缓冲区的方法来实现，并提供一个无边界的字节流服务。采用环形缓冲区的好处是，当一个数据元素被消耗之后，其余数据元素不需要移动其存储位置，从而减少复制，提高效率。

（1）创建KFIFO

在使用KFIFO之前需要进行初始化，这里有静态初始化和动态初始化两种方式。

```text
<include/linux/kfifo.h>

int kfifo_alloc(fifo, size, gfp_mask)
```

该函数创建并分配一个大小为size的KFIFO环形缓冲区。第一个参数fifo是指向该环形缓冲区的struct kfifo数据结构；第二个参数size是指定缓冲区元素的数量；第三个参数gfp_mask表示分配KFIFO元素使用的分配掩码。

静态分配可以使用如下的宏。

```text
#define DEFINE_KFIFO(fifo, type, size)
#define INIT_KFIFO(fifo)
```

（2）入列

把数据写入KFIFO环形缓冲区可以使用kfifo_in()函数接口。

```text
int kfifo_in(fifo, buf, n)
```

该函数把buf指针指向的*n*个数据复制到KFIFO环形缓冲区中。第一个参数fifo指的是KFIFO环形缓冲区；第二个参数buf指向要复制的数据的buffer；第三个数据是要复制数据元素的数量。

（3）出列

从KFIFO环形缓冲区中列出或者摘取数据可以使用kfifo_out()函数接口。

```text
#define    kfifo_out(fifo, buf, n)
```

该函数是从fifo指向的环形缓冲区中复制*n*个数据元素到buf指向的缓冲区中。如果KFIFO环形缓冲区的数据元素小于*n*个，那么复制出去的数据元素小于*n*个。

（4）获取缓冲区大小

KFIFO提供了几个接口函数来查询环形缓冲区的状态。

```text
#define kfifo_size(fifo)
#define kfifo_len(fifo)
#define    kfifo_is_empty(fifo)
#define    kfifo_is_full(fifo)
```

[kfifo_size](https://www.zhihu.com/search?q=kfifo_size&search_source=Entity&hybrid_search_source=Entity&hybrid_search_extra=%7B%22sourceType%22%3A%22article%22%2C%22sourceId%22%3A58087261%7D)()用来获取环形缓冲区的大小，也就是最大可以容纳多少个数据元素。kfifo_len()用来获取当前环形缓冲区中有多少个有效数据元素。kfifo_is_empty()判断环形缓冲区是否为空。kfifo_is_full()判断环形缓冲区是否为满。

（5）与用户空间数据交互

KFIFO还封装了两个函数与用户空间数据交互。

```text
#define    kfifo_from_user(fifo, from, len, copied)
#define    kfifo_to_user(fifo, to, len, copied)
```

kfifo_from_user()是把from指向的用户空间的len个数据元素复制到KFIFO中，最后一个参数copied表示成功复制了几个数据元素。kfifo_to_user()则相反，把KFIFO的数据元素复制到用户空间。这两个宏结合了copy_to_user()、copy_from_user()以及KFIFO的机制，给驱动开发者提供了方便。

本文来源于《奔跑吧Linux内核 入门篇》

![Linux内核中常用的数据结构和算法 - 知乎-05](img/Linux%E5%86%85%E6%A0%B8%E4%B8%AD%E5%B8%B8%E7%94%A8%E7%9A%84%E6%95%B0%E6%8D%AE%E7%BB%93%E6%9E%84%E5%92%8C%E7%AE%97%E6%B3%95%20-%20%E7%9F%A5%E4%B9%8E-05.jpg)

[《奔跑吧 Linux内核 入门篇》(张天飞)【摘要 书评 试读】- 京东图书​item.jd.com/12546036.html?dist=jd

![Linux内核中常用的数据结构和算法 - 知乎-06](img/Linux%E5%86%85%E6%A0%B8%E4%B8%AD%E5%B8%B8%E7%94%A8%E7%9A%84%E6%95%B0%E6%8D%AE%E7%BB%93%E6%9E%84%E5%92%8C%E7%AE%97%E6%B3%95%20-%20%E7%9F%A5%E4%B9%8E-06.jpg)

](https://link.zhihu.com/?target=https%3A//item.jd.com/12546036.html%3Fdist%3Djd)

奔跑吧 Linux内核》作者又一力作，内含70余个创新实验，配套视频+教学PPT，带你轻松入门Linux内核开发！

- 原理+基础，从调试Linux内核到动手编写一个简单的内核模块，真正从零开始学习Linux内核。
- 实验+案例，70余个创新实验贯穿全书，与你分享业内一线项目经验。
- 课件+视频，教学资源丰富，视频讲解透彻，与你共享精品在线配套资源。
- 涵盖当前Linux社区中新的开发工具和社区运作方式，反映Linux内核社区新发展。

**内容提要**

本书是一本介绍Linux内核实践的入门书，基于Linux 4.0内核，重点讲解Linux内核的理论和实验。本书分为12章，包括Linux系统入门、Linux内核基础知识、内核编译和调试、内核模块、简单的字符设备驱动、系统调用、内存管理、进程管理、同步管理、中断管理、调试和性能优化，以及如何参与开源社区等内容。此外，本书还介绍了Linux内核社区常用的开发工具和理论，如Vim 8和git工具等。**书中包括70多个实验，帮助读者深入理解Linux内核。**

发布于 2019-03-02 08:44

[Linux](https://www.zhihu.com/topic/19554300)

[Linux 开发](https://www.zhihu.com/topic/19610306)

[Linux 内核](https://www.zhihu.com/topic/19614193)

​赞同 342​

​5 条评论

​分享

​喜欢

​收藏

​申请转载

​

### 文章被以下专栏收录

[

![异步图书](img/Linux%E5%86%85%E6%A0%B8%E4%B8%AD%E5%B8%B8%E7%94%A8%E7%9A%84%E6%95%B0%E6%8D%AE%E7%BB%93%E6%9E%84%E5%92%8C%E7%AE%97%E6%B3%95%20-%20%E7%9F%A5%E4%B9%8E-07.jpg)

](https://www.zhihu.com/column/epubit)

## 异步图书

IT类的大咖推荐书单分享

### 推荐阅读

[linux内存管理之用户空间与内核空间详解Linux 操作系统和驱动程序运行在内核空间，应用程序运行在用户空间，两者不能简单地使用指针传递数据，因为Linux使用的虚拟内存机制，用户空间的数据可能被换出，当内核空间使用用户空间指…linux发表于linux...](https://zhuanlan.zhihu.com/p/151744011)

[

![Linux中文件系统分类，以及基础使用方法](img/Linux%E5%86%85%E6%A0%B8%E4%B8%AD%E5%B8%B8%E7%94%A8%E7%9A%84%E6%95%B0%E6%8D%AE%E7%BB%93%E6%9E%84%E5%92%8C%E7%AE%97%E6%B3%95%20-%20%E7%9F%A5%E4%B9%8E-08.jpg)

Linux中文件系统分类，以及基础使用方法喜欢编程的狗子](https://zhuanlan.zhihu.com/p/351984326)

[Linux内核文件系统的实现linux内核相关视频解析： 手把手带你实现一个Linux内核文件系统 90分钟了解Linux内存架构，numa的优势，slab的实现，vmalloc的原理Linux文件管理从用户的层面介绍了Linux管理文件的方式。Li…linux发表于linux...](https://zhuanlan.zhihu.com/p/351698932)

[

![Linux内核部分文件分析](img/Linux%E5%86%85%E6%A0%B8%E4%B8%AD%E5%B8%B8%E7%94%A8%E7%9A%84%E6%95%B0%E6%8D%AE%E7%BB%93%E6%9E%84%E5%92%8C%E7%AE%97%E6%B3%95%20-%20%E7%9F%A5%E4%B9%8E-09.jpg)

Linux内核部分文件分析星云博创](https://zhuanlan.zhihu.com/p/434399626)

## 5 条评论

​切换为时间排序

写下你的评论...

发布

- ![知乎用户](img/Linux%E5%86%85%E6%A0%B8%E4%B8%AD%E5%B8%B8%E7%94%A8%E7%9A%84%E6%95%B0%E6%8D%AE%E7%BB%93%E6%9E%84%E5%92%8C%E7%AE%97%E6%B3%95%20-%20%E7%9F%A5%E4%B9%8E-10.jpg) 知乎用户2019-03-09每次看到红黑树的插入删除脑阔疼​2​回复​踩​ 举报

- ![知乎用户](img/Linux%E5%86%85%E6%A0%B8%E4%B8%AD%E5%B8%B8%E7%94%A8%E7%9A%84%E6%95%B0%E6%8D%AE%E7%BB%93%E6%9E%84%E5%92%8C%E7%AE%97%E6%B3%95%20-%20%E7%9F%A5%E4%B9%8E-11.jpg) 知乎用户2019-03-20大佬就是传说中的手写红黑树?​1​回复​踩​ 举报

- [ ![林克](img/Linux%E5%86%85%E6%A0%B8%E4%B8%AD%E5%B8%B8%E7%94%A8%E7%9A%84%E6%95%B0%E6%8D%AE%E7%BB%93%E6%9E%84%E5%92%8C%E7%AE%97%E6%B3%95%20-%20%E7%9F%A5%E4%B9%8E-12.jpg) ](https://www.zhihu.com/people/jian-hui-72-63)[林克](https://www.zhihu.com/people/jian-hui-72-63)2019-12-06这个是arm的，对于理解x86的会有多大的区别呀？​赞​回复​踩​ 举报

- [ ![sandy khanm](img/Linux%E5%86%85%E6%A0%B8%E4%B8%AD%E5%B8%B8%E7%94%A8%E7%9A%84%E6%95%B0%E6%8D%AE%E7%BB%93%E6%9E%84%E5%92%8C%E7%AE%97%E6%B3%95%20-%20%E7%9F%A5%E4%B9%8E-13.jpg) ](https://www.zhihu.com/people/sandy-khanm)[sandy khanm](https://www.zhihu.com/people/sandy-khanm)2019-03-24很好，看内核的代码很有帮助​赞​回复​踩​ 举报

- [ ![Ender Wiggin](img/Linux%E5%86%85%E6%A0%B8%E4%B8%AD%E5%B8%B8%E7%94%A8%E7%9A%84%E6%95%B0%E6%8D%AE%E7%BB%93%E6%9E%84%E5%92%8C%E7%AE%97%E6%B3%95%20-%20%E7%9F%A5%E4%B9%8E-14.jpg) ](https://www.zhihu.com/people/andrew-wiggin-)[Ender Wiggin](https://www.zhihu.com/people/andrew-wiggin-)2019-03-10大学时学的都还给老师了，就记得完全公平调度是红黑树的 ![[飙泪笑]](https://pic4.zhimg.com/v2-3bb879be3497db9051c1953cdf98def6.png) ​赞​回复​踩​ 举报

1 条评论被折叠

（

[为什么？](https://www.zhihu.com/question/52029856/answer/128623557)

）
