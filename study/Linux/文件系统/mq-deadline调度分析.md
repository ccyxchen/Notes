# linux 5.14版本后的mq-deadline调度算法分析

## 5.14后的区别

在V5.14版本中，在mq-deadline中加入了对ioprio的支持，使deadline算法能支持IO优先级队列。

## 主要的数据结构

```C
//对每个CPU上的读写请求的状态进行统计
/* I/O statistics per I/O priority. */
struct io_stats_per_prio {
 local_t inserted;
 local_t merged;
 local_t dispatched;
 local_t completed;
};

/* I/O statistics for all I/O priorities (enum dd_prio). */
struct io_stats {
 struct io_stats_per_prio stats[DD_PRIO_COUNT];
};

/*
 * Deadline scheduler data per I/O priority (enum dd_prio). Requests are
 * present on both sort_list[] and fifo_list[].
 */
/*
 * deadline算法会维护一个rbtree和一个FIFO队列存放下发到调度层的request
 * 后面可以看到insert，merge，dispatch等操作都是围绕这2个队列进行
 */
struct dd_per_prio {
 struct list_head dispatch;                  //dispatch链表保存可以直接下发到块设备驱动处理的request
 struct rb_root sort_list[DD_DIR_COUNT];     //deadline 的 红黑树，使用红黑树主要是为了能根据hash值快速插入和索取到request
 struct list_head fifo_list[DD_DIR_COUNT]; //deadline的FIFO
 /* Next request in FIFO order. Read, write or both are NULL. */
 struct request *next_rq[DD_DIR_COUNT]; //deadline要取出的下一个request
};

/*
 * deadline算法的核心结构体，在注册调度器后会创建，作为该调度器的私有数据
 * 保存调度器相关的所有数据。
 */
struct deadline_data {
 /*
  * run time data
  */

 struct dd_per_prio per_prio[DD_PRIO_COUNT]; //每个优先级的request队列

 /* Data direction of latest dispatched request. */
 enum dd_data_dir last_dir;              //上一次处理的读写类型
 unsigned int batching;  /* number of sequential requests made */    //在dispatch时使用
 unsigned int starved;  /* times reads have starved writes */       //在dispatch时使用

 struct io_stats __percpu *stats;            //统计每个CPU处理的各状态的request数

 /*
  * settings that change how the i/o scheduler behaves
  */
 int fifo_expire[DD_DIR_COUNT];              //读写的死亡时间
 int fifo_batch;                             //最大的batch值，在dispatch时使用
 int writes_starved;                         //在dispatch时使用
 int front_merges;                           //front_merge的request数
 u32 async_depth;                            

 spinlock_t lock;
 spinlock_t zone_lock;                       //写锁
};
```

## IO调度器的初始化

`int elv_register(struct elevator_type *e)`
注册调度器的接口 接受`struct elevator_type` 类型的参数，该参数需包含调度器的所有信息。

### elevator_type 类型分析

```C
static struct elevator_type mq_deadline = {
 .ops = {   // 调度器支持的函数定义
  .depth_updated  = dd_depth_updated,
  .limit_depth  = dd_limit_depth,   //更新data->shallow_depth 
  .insert_requests = dd_insert_requests,    //插入request
  .dispatch_request = dd_dispatch_request,  //dispatch request
  .prepare_request = dd_prepare_request, 
  //初始化request的elv.priv参数，用于保存request中关于调度器的私有数据
  .finish_request  = dd_finish_request,     //request 完成后的回调函数
  .next_request  = elv_rb_latter_request,   //从rbtree中得到当前request的下一个rq
  .former_request  = elv_rb_former_request, //从rbtree获得前一个rq
  .bio_merge  = dd_bio_merge,       //将bio和已有的request对比并merge
  .request_merge  = dd_request_merge,   //判断request是否能进行front_merge
  .requests_merged = dd_merged_requests, //request merge后的回调函数
  .request_merged  = dd_request_merged, //request front_merge后的回调函数
  .has_work  = dd_has_work,             
  //判断调度器队列中是否有未处理的request
  .init_sched  = dd_init_sched,         //初始化调度器
  .exit_sched  = dd_exit_sched,         //释放调度器
  .init_hctx  = dd_init_hctx,           //初始化dd的async_depth和hctx的min_shallow_depth
 },

#ifdef CONFIG_BLK_DEBUG_FS
 .queue_debugfs_attrs = deadline_queue_debugfs_attrs,
#endif
 .elevator_attrs = deadline_attrs,      
 /*
  * 调度器的调试节点，可以在开机后调整调度器参数（read_expire，
  * write_expire，writes_starved，front_merges，async_depth，fifo_batch）
  */
 .elevator_name = "mq-deadline",   
 .elevator_alias = "deadline",
 .elevator_features = ELEVATOR_F_ZBD_SEQ_WRITE,
 //调度器支持的特性
 .elevator_owner = THIS_MODULE,
};
```

### dd_init_sched 

dd_init_sched 分配并初始化struct elevator_queue，然后分配struct deadline_data，初始化每个IO优先级的调度队列（rbtree, fifo,dispatch）,最后初始化spinlock.

#### elevator_queue的初始化

```C
/*
 * each queue has an elevator_queue associated with it
 */
struct elevator_queue
{
 struct elevator_type *type;    //调度器结构
 void *elevator_data;           //调度器私有数据类型
 struct kobject kobj;
 struct mutex sysfs_lock; 
 unsigned int registered:1;     //位域变量，标识是否注册成功
 DECLARE_HASHTABLE(hash, ELV_HASH_BITS);    //定义哈希链表
};

struct elevator_queue *elevator_alloc(struct request_queue *q,
      struct elevator_type *e)
{
 struct elevator_queue *eq;

 //分配空间
 eq = kzalloc_node(sizeof(*eq), GFP_KERNEL, q->node); 
 if (unlikely(!eq))
  return NULL;

 eq->type = e; //链接调度器结构
 kobject_init(&eq->kobj, &elv_ktype);
 mutex_init(&eq->sysfs_lock);
 hash_init(eq->hash);

 return eq;
}
EXPORT_SYMBOL(elevator_alloc);
```

## mq_deadline 主要的功能函数解析

dealine 中处理rq的基本顺序是merge->insert->dispatch->finish,文件系统下发的bio和rq会尝试合并到调度器已有的rq上，如果无法merge，就会插入到调度器的调度队列，然后调度器跟据一定的规则发送调度队列的rq到块设备驱动处理，当rq被处理完成后就会调用finish执行完成后操作。

### mq_deadline的merge

#### 合并的3种类型说明

front :  blk_rq_pos(rq) - bio_sectors(bio) == bio->bi_iter.bi_sector
即在磁盘位置中bio后紧接着rq

back : blk_rq_pos(rq) + blk_rq_sectors(rq) == bio->bi_iter.bi_sector
即在磁盘位置中rq后紧接着bio

discard : req_op(req) == REQ_OP_DISCARD && req->q->limits.max_segments > 1
req的op设置了REQ_OP_DISCARD标志并且请求队列的limits.max_segments值大于1

```C
/*
 主要调用blk_mq_sched_try_merge函数将bio合并到请求队列
 如果合并了2个rq，还需要调用blk_mq_free_request去释放被合并的rq
 */
static bool dd_bio_merge(struct request_queue *q, struct bio *bio,
unsigned int nr_segs)

/* 
 * 合并请求有 front, back ，discard 3种
 * 该函数先调用elv_merge判断该bio能进行哪种合并
 * 并将找到的能合并的rq保存。
 */

bool blk_mq_sched_try_merge(struct request_queue *q, struct bio *bio,
  unsigned int nr_segs, struct request **merged_request)
{
 struct request *rq;

 switch (elv_merge(q, &rq, bio)) {
 case ELEVATOR_BACK_MERGE:
  if (!blk_mq_sched_allow_merge(q, rq, bio))
   return false;
  if (bio_attempt_back_merge(rq, bio, nr_segs) != BIO_MERGE_OK)
   return false;
/*
如果是back merge,bio和rq合并后，此时rq的结束位置已经改变，
需判断rq与其下一个rq是否能合并。attempt_back_merge函数中调用
elv_latter_request获取下一个rq(next), 然后调用attempt_merge
执行req和next的合并
*/
/*
attempt_merge的解析：
首先判断2个rq的op,data_dir,write_same_mergeable,write_hint,
ioprio等是否相同，然后调用blk_try_req_merge判断合并类型，如果可合并，
则将next的bio加入req的bio链表，如果是back merge，还会调用
调度器定义的requests_merged函数，最后函数返回next。
*/
/*
requests_merged函数：对于mq_deadline为dd_merged_requests
该函数判断next的fifo_time是否比req的早，如果是则需要将req移到fifo list中next的位置，并更新req的fifo_time为next的fifo_time
最后从mq_deadline的调度队列删除next
*/
  merged_request = attempt_back_merge(q, rq);
  if (!*merged_request)
/*
如果next无法被merge，则调用调度器定义的request_merged函数

*/
/*
request_merged函数：对于mq_deadline为dd_request_merged
在front merge中，如果rq已经更新，则需要从rb tree重新插入rq
*/
   elv_merged_request(q, rq, ELEVATOR_BACK_MERGE);
/*
如果返回值为NULL，说明rq和next无法进行合并
*/
  return true;
 case ELEVATOR_FRONT_MERGE:
 //front和back是一样的逻辑，只是front要与前一个rq判断是否能合并
  if (!blk_mq_sched_allow_merge(q, rq, bio))
   return false;
  if (bio_attempt_front_merge(rq, bio, nr_segs) != BIO_MERGE_OK)
   return false;
  *merged_request = attempt_front_merge(q, rq);
  if (!*merged_request)
   elv_merged_request(q, rq, ELEVATOR_FRONT_MERGE);
  return true;
 case ELEVATOR_DISCARD_MERGE:
/*
discard merge直接将bio插入rq的最后，由于discard方式中rq的bio
不连续，不需要进行rq间的merge
*/
  return bio_attempt_discard_merge(q, rq, bio) == BIO_MERGE_OK;
 default:
  return false;
 }
}

enum elv_merge elv_merge(struct request_queue *q, struct request **req,
struct bio *bio)
/*
该函数首先判断请求队列和bio 是否是mergeable的，然后调用elv_bio_merge_ok,
该函数中依次判断q->last_merge和bio的op,data_dir,disk,integrity,crypt contexts,
buffer,write_hint,ioprio是否都相同或兼容，如果调度器定义了allow_merge，还会调用
该函数作进一步的判断。如果该函数返回true，则调用blk_try_merge函数判断q->last_merge
和bio的合并类型。
如果判断可合并，则需合并的rq就是q->last_merge
如果无法和last_merge合并，则通过hash值从请求队列查找可以back merge的请求，
或者调用调度器定义的request_merge判断能否与调度器队列的rq进行front merge
*/
```

### mq_deadline的insert

insert函数将给定的rq list 插入请求队列

```C
//该函数从list链表逐个取出rq,然后调用dd_insert_request插入rq
/*
 * Called from blk_mq_sched_insert_request() or blk_mq_sched_insert_requests().
 */
static void dd_insert_requests(struct blk_mq_hw_ctx *hctx,
          struct list_head *list, bool at_head)

/*
该函数调用blk_mq_sched_try_insert_merge 尝试merge rq，如果
merge成功则释放free链表中的rq并返回
如果无法merge，则将rq 插入调度器的rb tree 和 fifo list
/*
 * add rq to rbtree and fifo
 */
static void dd_insert_request(struct blk_mq_hw_ctx *hctx, struct request *rq,
         bool at_head)

/*
调用elv_attempt_insert_merge，首先尝试last_merge和rq进行back merge
，如果无法合并则循环从hash队列中获取能与rq进行 back merge的req,
并将merge后的rq作为新的rq处理。
*/
bool blk_mq_sched_try_insert_merge(struct request_queue *q, struct request *rq,
       struct list_head *free)
```

### mq_deadline的dispatch

dispatch操作用于从调度器的调度队列取得下一个要处理的rq下发给块设备驱动。

```C
该函数尝试从不同优先级的调度队列获取可下发的rq,  rq通过__dd_dispatch_request
获得。
/*
 * Called from blk_mq_run_hw_queue() -> __blk_mq_sched_dispatch_requests().
 *
 * One confusing aspect here is that we get called for a specific
 * hardware queue, but we may return a request that is for a
 * different hardware queue. This is because mq-deadline has shared
 * state for all hardware queues, in terms of sorting, FIFOs, etc.
 */
static struct request *dd_dispatch_request(struct blk_mq_hw_ctx *hctx)

/*
 * deadline_dispatch_requests selects the best request according to
 * read/write expire, fifo_batch, etc
 */
static struct request *__dd_dispatch_request(struct deadline_data *dd,
          struct dd_per_prio *per_prio)
{
 struct request *rq, *next_rq;
 enum dd_data_dir data_dir;
 enum dd_prio prio;
 u8 ioprio_class;

 lockdep_assert_held(&dd->lock);
//如果 dispatch 链表不空，则直接下发
 if (!list_empty(&per_prio->dispatch)) {
  rq = list_first_entry(&per_prio->dispatch, struct request,
          queuelist);
  list_del_init(&rq->queuelist);
  goto done;
 }

 /*
  * batches are currently reads XOR writes
  */
/*
在deadline算法中，next_rq保存了rb tree中下一个rq, 如果是写请求，还需要
rq 获取到写锁。batching值保存的是读或写请求已连续执行的次数，当超过fifo_batch（=16）值时，则不蹦直接下发该rq，需继续判断starved的值
*/
 rq = deadline_next_request(dd, per_prio, dd->last_dir);
 if (rq && dd->batching < dd->fifo_batch)
  /* we have a next request are still entitled to batch */
  goto dispatch_request;

 /*
  * at this point we are not running a batch. select the appropriate
  * data direction (read / write)
  */

 if (!list_empty(&per_prio->fifo_list[DD_READ])) {
  BUG_ON(RB_EMPTY_ROOT(&per_prio->sort_list[DD_READ]));
//deadline_fifo_request从fifo队列取出下一个rq, 在这里是为了判断有可写的rq
  if (deadline_fifo_request(dd, per_prio, DD_WRITE) &&
/*
在读请求中，每次batching值大于fifo_batch时会清零，然后递增starved值
并重复，当starved的值大于writes_starved时，就需要切换为写请求。
在执行写请求中，每次下发会递增batching值，batching值大于fifo_batch后，又会
切换为读请求
*/
      (dd->starved++ >= dd->writes_starved))
   goto dispatch_writes;

  data_dir = DD_READ;

  goto dispatch_find_request;
 }

 /*
  * there are either no reads or writes have been starved
  */

 if (!list_empty(&per_prio->fifo_list[DD_WRITE])) {
dispatch_writes:
  BUG_ON(RB_EMPTY_ROOT(&per_prio->sort_list[DD_WRITE]));
//执行到这里时，说明从读请求切换到写请求
  dd->starved = 0;

  data_dir = DD_WRITE;

  goto dispatch_find_request;
 }

 return NULL;

dispatch_find_request:
 /*
  * we are not running a batch, find best request for selected data_dir
  */
/*
首先调用deadline_next_request从rb tree 获取下一个rq，并调用deadline_check_fifo判断fifo队列中的rq的fifo_time是否超时了，如果有超时
则从fifo 队列中获取rq下发，如果未超时则下发从rb tree中取到的rq
*/
 next_rq = deadline_next_request(dd, per_prio, data_dir);
 if (deadline_check_fifo(per_prio, data_dir) || !next_rq) {
  /*
   * A deadline has expired, the last request was in the other
   * direction, or we have run out of higher-sectored requests.
   * Start again from the request with the earliest expiry time.
   */
  rq = deadline_fifo_request(dd, per_prio, data_dir);
 } else {
  /*
   * The last req was the same dir and we have a next request in
   * sort order. No expired requests so continue on from here.
   */
  rq = next_rq;
 }

 /*
  * For a zoned block device, if we only have writes queued and none of
  * them can be dispatched, rq will be NULL.
  */
 if (!rq)
  return NULL;
//走到这里说明batching的值超了，需重新计数
 dd->last_dir = data_dir;
 dd->batching = 0;

dispatch_request:
 /*
  * rq is the selected appropriate request.
  */
 dd->batching++;
//rq将要被下发，从队列中删除掉，并更新next_rq的值
 deadline_move_request(dd, per_prio, rq);
done:
 ioprio_class = dd_rq_ioclass(rq);
 prio = ioprio_class_to_prio[ioprio_class];
 dd_count(dd, dispatched, prio);
 /*
  * If the request needs its target zone locked, do it.
  */
//拿rq的写锁，成功下发
 blk_req_zone_write_lock(rq);
 rq->rq_flags |= RQF_STARTED;
 return rq;
}
```

### mq_deadline的finish

finish函数在rq处理完成后回调

```C
/*
 * Callback from inside blk_mq_free_request().
 *
 * For zoned block devices, write unlock the target zone of
 * completed write requests. Do this while holding the zone lock
 * spinlock so that the zone is never unlocked while deadline_fifo_request()
 * or deadline_next_request() are executing. This function is called for
 * all requests, whether or not these requests complete successfully.
 *
 * For a zoned block device, __dd_dispatch_request() may have stopped
 * dispatching requests if all the queued requests are write requests directed
 * at zones that are already locked due to on-going write requests. To ensure
 * write request dispatch progress in this case, mark the queue as needing a
 * restart to ensure that the queue is run again after completion of the
 * request and zones being unlocked.
 */
static void dd_finish_request(struct request *rq)
{
 struct request_queue *q = rq->q;
 struct deadline_data *dd = q->elevator->elevator_data;
 const u8 ioprio_class = dd_rq_ioclass(rq);
 const enum dd_prio prio = ioprio_class_to_prio[ioprio_class];
 struct dd_per_prio *per_prio = &dd->per_prio[prio];

 /*
  * The block layer core may call dd_finish_request() without having
  * called dd_insert_requests(). Hence only update statistics for
  * requests for which dd_insert_requests() has been called. See also
  * blk_mq_request_bypass_insert().
  */
//block层可能没有调用insert函数插入调度队列而是在sw queue处理rq,只有执行了
dd_insert_requests函数才会将elv.priv[0]赋值为1
 if (rq->elv.priv[0])
  dd_count(dd, completed, prio);
//如果块设备支持分区，并且写队列非空，则需要调用
blk_mq_sched_mark_restart_hctx函数设置BLK_MQ_S_SCHED_RESTART状态
 if (blk_queue_is_zoned(q)) {
  unsigned long flags;

  spin_lock_irqsave(&dd->zone_lock, flags);
  blk_req_zone_write_unlock(rq);
  if (!list_empty(&per_prio->fifo_list[DD_WRITE]))
   blk_mq_sched_mark_restart_hctx(rq->mq_hctx);
  spin_unlock_irqrestore(&dd->zone_lock, flags);
 }
}
```
