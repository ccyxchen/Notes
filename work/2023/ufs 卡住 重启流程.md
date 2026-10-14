# Ufs 重启

**`drivers/scsi/ufs/ufshcd.c:8087-8109`**  `ufshcd_driver_template`（SCSI 主机模板，注册 eh 回调）

```c
static struct scsi_host_template ufshcd_driver_template = {
	.module			= THIS_MODULE,
	.name			= UFSHCD,
	.proc_name		= UFSHCD,
	.queuecommand		= ufshcd_queuecommand,
	.slave_alloc		= ufshcd_slave_alloc,
	.slave_configure	= ufshcd_slave_configure,
	.slave_destroy		= ufshcd_slave_destroy,
	.change_queue_depth	= ufshcd_change_queue_depth,
	.eh_abort_handler	= ufshcd_abort,
	.eh_device_reset_handler = ufshcd_eh_device_reset_handler,
	.eh_host_reset_handler   = ufshcd_eh_host_reset_handler,
	.this_id		= -1,
	.sg_tablesize		= SG_ALL,
	.cmd_per_lun		= UFSHCD_CMD_PER_LUN,
	.can_queue		= UFSHCD_CAN_QUEUE,
	.max_segment_size	= PRDT_DATA_BYTE_COUNT_MAX,
	.max_host_blocked	= 1,
	.track_queue_depth	= 1,
	.sdev_groups		= ufshcd_driver_groups,
	.dma_boundary		= PAGE_SIZE - 1,
	.rpm_autosuspend_delay	= RPM_AUTOSUSPEND_DELAY_MS,
};
```

> 请求超时统一由 SCSI 层 `scsi_timeout` → `scsi_times_out` 处理（见下文“请求队列初始化以及超时监控”一节）。

**`drivers/scsi/ufs/ufshcd.c:6966-7024`**  `ufshcd_abort`（`.eh_abort_handler`）

```c
/**
 * ufshcd_abort - scsi host template eh_abort_handler callback
 * @cmd: SCSI command pointer
 *
 * Returns SUCCESS/FAILED
 */
static int ufshcd_abort(struct scsi_cmnd *cmd)
{
	struct Scsi_Host *host;
	struct ufs_hba *hba;
	unsigned long flags;
	unsigned int tag;
	int err = FAILED, res;
	bool outstanding;
	struct ufshcd_lrb *lrbp;
	u32 reg;

	host = cmd->device->host;
	hba = shost_priv(host);
	tag = cmd->request->tag;
	lrbp = &hba->lrb[tag];
	if (!ufshcd_valid_tag(hba, tag)) {
		dev_err(hba->dev,
			"%s: invalid command tag %d: cmd=0x%p, cmd->request=0x%p",
			__func__, tag, cmd, cmd->request);
		BUG();
	}

	ufshcd_hold(hba, false);
	reg = ufshcd_readl(hba, REG_UTP_TRANSFER_REQ_DOOR_BELL);
	/* If command is already aborted/completed, return FAILED. */
	if (!(test_bit(tag, &hba->outstanding_reqs))) {
		dev_err(hba->dev,
			"%s: cmd at tag %d already completed, outstanding=0x%lx, doorbell=0x%x\n",
			__func__, tag, hba->outstanding_reqs, reg);
		goto release;
	}

	/* Print Transfer Request of aborted task */
	dev_info(hba->dev, "%s: Device abort task at tag %d\n", __func__, tag);

	/*
	 * Print detailed info about aborted request.
	 * As more than one request might get aborted at the same time,
	 * print full information only for the first aborted request in order
	 * to reduce repeated printouts. For other aborted requests only print
	 * basic details.
	 */
	scsi_print_command(cmd);
	if (!hba->req_abort_count) {
		ufshcd_update_evt_hist(hba, UFS_EVT_ABORT, tag);
		ufshcd_print_evt_hist(hba);
		ufshcd_print_host_state(hba);
		ufshcd_print_pwr_info(hba);
		ufshcd_print_trs(hba, 1 << tag, true);
	} else {
		ufshcd_print_trs(hba, 1 << tag, false);
	}
	hba->req_abort_count++;
```

**`drivers/scsi/ufs/ufshcd.c:6041-6068`**  `ufshcd_err_handler`（UFS 错误处理 work，开头）

```c
static void ufshcd_err_handler(struct work_struct *work)
{
	struct ufs_hba *hba;
	unsigned long flags;
	bool err_xfer = false;
	bool err_tm = false;
	int err = 0, pmc_err;
	int tag;
	bool err_handled = false;
	bool needs_reset = false, needs_restore = false;

	hba = container_of(work, struct ufs_hba, eh_work);

	trace_android_vh_ufs_err_handler(hba, &err_handled);

	if (err_handled)
		return;

	down(&hba->host_sem);
	spin_lock_irqsave(hba->host->host_lock, flags);
	if (ufshcd_err_handling_should_stop(hba)) {
		if (hba->ufshcd_state != UFSHCD_STATE_ERROR)
			hba->ufshcd_state = UFSHCD_STATE_OPERATIONAL;
		spin_unlock_irqrestore(hba->host->host_lock, flags);
		up(&hba->host_sem);
		return;
	}
	ufshcd_set_eh_in_progress(hba);
```

**`drivers/scsi/ufs/ufshcd.c:7135-7175`**  `ufshcd_reset_and_restore`（错误恢复：设备 reset + 主机 reset/restore，:7158 调用 `ufshcd_host_reset_and_restore`）

```c
static int ufshcd_reset_and_restore(struct ufs_hba *hba)
{
	u32 saved_err;
	u32 saved_uic_err;
	int err = 0;
	unsigned long flags;
	int retries = MAX_HOST_RESET_RETRIES;

	/*
	 * This is a fresh start, cache and clear saved error first,
	 * in case new error generated during reset and restore.
	 */
	spin_lock_irqsave(hba->host->host_lock, flags);
	saved_err = hba->saved_err;
	saved_uic_err = hba->saved_uic_err;
	hba->saved_err = 0;
	hba->saved_uic_err = 0;
	spin_unlock_irqrestore(hba->host->host_lock, flags);

	do {
		/* Reset the attached device */
		ufshcd_vops_device_reset(hba);

		err = ufshcd_host_reset_and_restore(hba);
	} while (err && --retries);

	spin_lock_irqsave(hba->host->host_lock, flags);
	/*
	 * Inform scsi mid-layer that we did reset and allow to handle
	 * Unit Attention properly.
	 */
	scsi_report_bus_reset(hba->host, 0);
	if (err) {
		hba->ufshcd_state = UFSHCD_STATE_ERROR;
		hba->saved_err |= saved_err;
		hba->saved_uic_err |= saved_uic_err;
	}
	spin_unlock_irqrestore(hba->host->host_lock, flags);

	return err;
}
```

**`drivers/scsi/ufs/ufshcd.h:1376-1391`**  `ufshcd_vops_device_reset`（vops 回调包装，5.10 中定义在 ufshcd.h）

```c
static inline void ufshcd_vops_device_reset(struct ufs_hba *hba)
{
	if (hba->vops && hba->vops->device_reset) {
		int err = hba->vops->device_reset(hba);

		if (!err) {
			ufshcd_set_ufs_dev_active(hba);
			if (ufshcd_is_wb_allowed(hba)) {
				hba->wb_enabled = false;
				hba->wb_buf_flush_enabled = false;
			}
		}
		if (err != -EOPNOTSUPP)
			ufshcd_update_evt_hist(hba, UFS_EVT_DEV_RESET, err);
	}
}
```

**`drivers/scsi/ufs/ufs-mediatek.c:2880-2898`**  `ufs_hba_mtk_vops`（`.device_reset = ufs_mtk_device_reset`）

```c
static const struct ufs_hba_variant_ops ufs_hba_mtk_vops = {
	.name                = "mediatek.ufshci",
	.init                = ufs_mtk_init,
	.get_ufs_hci_version = ufs_mtk_get_ufs_hci_version,
	.setup_clocks        = ufs_mtk_setup_clocks,
	.setup_regulators    = ufs_mtk_setup_regulators,
	.hce_enable_notify   = ufs_mtk_hce_enable_notify,
	.link_startup_notify = ufs_mtk_link_startup_notify,
	.pwr_change_notify   = ufs_mtk_pwr_change_notify,
	.hibern8_notify      = ufs_mtk_hibern8_notify,
	.apply_dev_quirks    = ufs_mtk_apply_dev_quirks,
	.fixup_dev_quirks    = ufs_mtk_fixup_dev_quirks,
	.suspend             = ufs_mtk_suspend,
	.resume              = ufs_mtk_resume,
	.dbg_register_dump   = ufs_mtk_dbg_register_dump,
	.device_reset        = ufs_mtk_device_reset,
	.event_notify        = ufs_mtk_event_notify,
	.setup_task_mgmt     = ufs_mtk_setup_task_mgmt,
};
```

**`drivers/scsi/ufs/ufs-mediatek.c:2464-2497`**  `ufs_mtk_device_reset`（MTK 平台设备 reset 时序）

```c
static int ufs_mtk_device_reset(struct ufs_hba *hba)
{
	struct arm_smccc_res res;

#if defined(CONFIG_UFSFEATURE)
	struct ufsf_feature *ufsf = ufs_mtk_get_ufsf(hba);

	if (ufsf->hba)
		ufsf_reset_host(ufs_mtk_get_ufsf(hba));
#endif

	/* disable hba before device reset */
	ufshcd_hba_stop(hba);

	ufs_mtk_device_reset_ctrl(0, res);

	/*
	 * The reset signal is active low. UFS devices shall detect
	 * more than or equal to 1us of positive or negative RST_n
	 * pulse width.
	 *
	 * To be on safe side, keep the reset low for at least 10us.
	 */
	usleep_range(10, 15);

	ufs_mtk_device_reset_ctrl(1, res);

	/* Some devices may need time to respond to rst_n */
	usleep_range(10000, 15000);

	dev_info(hba->dev, "device reset done\n");

	return 0;
}
```

Rpmb 读流程：

> 入口调用链（补充，`drivers/char/rpmb/rpmb-mtk.c` 中 `__RPMB_KERNEL_NL_SUPPORT` 未开启，见 :58）：
> `rpmb_ioctl_ufs`(:2485) → `rpmb_req_ioctl_read_data_ufs`(:1063) → `rpmb_req_read_data_ufs`(:649) → `rpmb_cmd_req`(`drivers/char/rpmb/core.c:218`) → `rpmb_cmd_seq`(`core.c:156`) → `rdev->ops->cmd_seq` = `ufs_mtk_rpmb_cmd_seq`(`ufs-mediatek.c:1666`) → `ufs_mtk_rpmb_security_in`(:1625) → `scsi_execute_req`。

**`drivers/scsi/ufs/ufs-mediatek.c:1666-1711`**  `ufs_mtk_rpmb_cmd_seq`（rpmb `cmd_seq` 实现）

```c
static int ufs_mtk_rpmb_cmd_seq(struct device *dev,
			       struct rpmb_cmd *cmds, u32 ncmds)
{
	unsigned long flags;
	struct ufs_hba *hba = dev_get_drvdata(dev);
	struct ufs_mtk_host *host;
	struct scsi_device *sdev;
	struct rpmb_cmd *cmd;
	int i;
	int ret;

	host = ufshcd_get_variant(hba);

	spin_lock_irqsave(hba->host->host_lock, flags);
	sdev = hba->sdev_rpmb;
	if (sdev) {
		ret = scsi_device_get(sdev);
		if (!ret && !scsi_device_online(sdev)) {
			ret = -ENODEV;
			scsi_device_put(sdev);
		}
	} else {
		ret = -ENODEV;
	}
	spin_unlock_irqrestore(hba->host->host_lock, flags);
	if (ret)
		return ret;

	/*
	 * Send all command one by one.
	 * Use rpmb lock to prevent other rpmb read/write threads cut in line.
	 * Use mutex not spin lock because in/out function might sleep.
	 */
	down(&host->rpmb_sem);
	/* Ensure device is resumed before RPMB operation */
	scsi_autopm_get_device(sdev);

	for (ret = 0, i = 0; i < ncmds && !ret; i++) {
		cmd = &cmds[i];
		if (cmd->flags & RPMB_F_WRITE)
			ret = ufs_mtk_rpmb_security_out(sdev, cmd->frames,
						       cmd->nframes);
		else
			ret = ufs_mtk_rpmb_security_in(sdev, cmd->frames,
						      cmd->nframes);
	}
```

**`drivers/scsi/ufs/ufs-mediatek.c:1713-1724`**  `ufs_mtk_rpmb_cmd_seq` 结尾 + `ufs_mtk_rpmb_ops`

```c
	/* Allow device to be runtime suspended */
	scsi_autopm_put_device(sdev);
	up(&host->rpmb_sem);

	scsi_device_put(sdev);
	return ret;
}

static struct rpmb_ops ufs_mtk_rpmb_dev_ops = {
	.cmd_seq = ufs_mtk_rpmb_cmd_seq,
	.type = RPMB_TYPE_UFS,
};
```

**`drivers/scsi/ufs/ufs-mediatek.c:1625-1664`**  `ufs_mtk_rpmb_security_in`（读：SECURITY_PROTOCOL_IN，超时 30s）

```c
int ufs_mtk_rpmb_security_in(struct scsi_device *sdev,
			struct rpmb_frame *frames, u32 cnt)
{
	struct scsi_sense_hdr sshdr = {0};
	u32 alloc_len = cnt * sizeof(struct rpmb_frame);
	int reset_retries = SEC_PROTOCOL_RETRIES_ON_RESET;
	int ret;
	u8 cmd[SEC_PROTOCOL_CMD_SIZE];

	memset(cmd, 0, SEC_PROTOCOL_CMD_SIZE);
	cmd[0] = SECURITY_PROTOCOL_IN;
	cmd[1] = SEC_PROTOCOL_UFS;
	put_unaligned_be16(SEC_SPECIFIC_UFS_RPMB, cmd + 2);
	cmd[4] = 0;                             /* inc_512 bit 7 set to 0 */
	put_unaligned_be32(alloc_len, cmd + 6); /* allocation length */

retry:
	ret = scsi_execute_req(sdev, cmd, DMA_FROM_DEVICE,
				     frames, alloc_len, &sshdr,
				     SEC_PROTOCOL_TIMEOUT, SEC_PROTOCOL_RETRIES,
				     NULL);

	if (ret && scsi_sense_valid(&sshdr) &&
	    sshdr.sense_key == UNIT_ATTENTION)
		/*
		 * Device reset might occur several times,
		 * give it one more chance
		 */
		if (--reset_retries > 0)
			goto retry;

	if (ret)
		dev_err(&sdev->sdev_gendev, "%s: failed with err %0x\n",
			__func__, ret);

	if (driver_byte(ret) & DRIVER_SENSE)
		scsi_print_sense_hdr(sdev, "rpmb: security in", &sshdr);

	return ret;
}
```

> 更正：原节标题是“Rpmb 读流程”，但原截图展示的是 `ufs_mtk_rpmb_security_out`（写方向）。读写分流在 `ufs_mtk_rpmb_cmd_seq`：`cmd->flags & RPMB_F_WRITE` 走 `security_out`(:1705)，否则走 `security_in`(:1709)。

**`drivers/scsi/ufs/ufs-mediatek.c:1584-1624`**  `ufs_mtk_rpmb_security_out`（写：SECURITY_PROTOCOL_OUT）

```c
int ufs_mtk_rpmb_security_out(struct scsi_device *sdev,
			 struct rpmb_frame *frames, u32 cnt)
{
	struct scsi_sense_hdr sshdr = {0};
	u32 trans_len = cnt * sizeof(struct rpmb_frame);
	int reset_retries = SEC_PROTOCOL_RETRIES_ON_RESET;
	int ret;
	u8 cmd[SEC_PROTOCOL_CMD_SIZE];

	memset(cmd, 0, SEC_PROTOCOL_CMD_SIZE);
	cmd[0] = SECURITY_PROTOCOL_OUT;
	cmd[1] = SEC_PROTOCOL_UFS;
	put_unaligned_be16(SEC_SPECIFIC_UFS_RPMB, cmd + 2);
	cmd[4] = 0;                              /* inc_512 bit 7 set to 0 */
	put_unaligned_be32(trans_len, cmd + 6);  /* transfer length */

retry:
	ret = scsi_execute_req(sdev, cmd, DMA_TO_DEVICE,
				     frames, trans_len, &sshdr,
				     SEC_PROTOCOL_TIMEOUT, SEC_PROTOCOL_RETRIES,
				     NULL);

	if (ret && scsi_sense_valid(&sshdr) &&
	    sshdr.sense_key == UNIT_ATTENTION)
		/*
		 * Device reset might occur several times,
		 * give it one more chance
		 */
		if (--reset_retries > 0)
			goto retry;

	if (ret)
		dev_err(&sdev->sdev_gendev, "%s: failed with err %0x\n",
			__func__, ret);

	if (driver_byte(ret) & DRIVER_SENSE)
		scsi_print_sense_hdr(sdev, "rpmb: security out", &sshdr);

	return ret;
}
```

**`drivers/scsi/ufs/ufs-mediatek.c:1574-1582`**  `SEC_PROTOCOL_*` 宏

```c
#if IS_ENABLED(CONFIG_RPMB)

#define SEC_PROTOCOL_UFS  0xEC
#define SEC_SPECIFIC_UFS_RPMB 0x0001

#define SEC_PROTOCOL_CMD_SIZE 12
#define SEC_PROTOCOL_RETRIES 3
#define SEC_PROTOCOL_RETRIES_ON_RESET 10
#define SEC_PROTOCOL_TIMEOUT msecs_to_jiffies(30000)
```

> 内核侧等价宏即上文 `ufs-mediatek.c:1574-1582`。

在scsi_execute_req 中具体处理下发的cmd

> `scsi_execute_req` 只是 `include/scsi/scsi_device.h` 里的 inline 包装（:463），真正实现是 `__scsi_execute`（`drivers/scsi/scsi_lib.c:240`）。

**`include/scsi/scsi_device.h:463-470`**  `scsi_execute_req`（inline 包装）

```c
static inline int scsi_execute_req(struct scsi_device *sdev,
	const unsigned char *cmd, int data_direction, void *buffer,
	unsigned bufflen, struct scsi_sense_hdr *sshdr, int timeout,
	int retries, int *resid)
{
	return scsi_execute(sdev, cmd, data_direction, buffer,
		bufflen, NULL, sshdr, timeout, retries,  0, 0, resid);
}
```

**`include/scsi/scsi_device.h:448-462`**  `__scsi_execute` 声明 + `scsi_execute` 宏

```c
extern int __scsi_execute(struct scsi_device *sdev, const unsigned char *cmd,
			int data_direction, void *buffer, unsigned bufflen,
			unsigned char *sense, struct scsi_sense_hdr *sshdr,
			int timeout, int retries, u64 flags,
			req_flags_t rq_flags, int *resid);
/* Make sure any sense buffer is the correct size. */
#define scsi_execute(sdev, cmd, data_direction, buffer, bufflen, sense,	\
		     sshdr, timeout, retries, flags, rq_flags, resid)	\
({									\
	BUILD_BUG_ON((sense) != NULL &&					\
		     sizeof(sense) != SCSI_SENSE_BUFFERSIZE);		\
	__scsi_execute(sdev, cmd, data_direction, buffer, bufflen,	\
		       sense, sshdr, timeout, retries, flags, rq_flags,	\
		       resid);						\
})
```

**`drivers/scsi/scsi_lib.c:222-260`**  `__scsi_execute`（申请 request、填命令）

```c
/**
 * __scsi_execute - insert request and wait for the result
 * @sdev:	scsi device
 * @cmd:	scsi command
 * @data_direction: data direction
 * @buffer:	data buffer
 * @bufflen:	len of buffer
 * @sense:	optional sense buffer
 * @sshdr:	optional decoded sense header
 * @timeout:	request timeout in seconds
 * @retries:	number of times to retry request
 * @flags:	flags for ->cmd_flags
 * @rq_flags:	flags for ->rq_flags
 * @resid:	optional residual length
 *
 * Returns the scsi_cmnd result field if a command was executed, or a negative
 * Linux error code if we didn't get that far.
 */
int __scsi_execute(struct scsi_device *sdev, const unsigned char *cmd,
		 int data_direction, void *buffer, unsigned bufflen,
		 unsigned char *sense, struct scsi_sense_hdr *sshdr,
		 int timeout, int retries, u64 flags, req_flags_t rq_flags,
		 int *resid)
{
	struct request *req;
	struct scsi_request *rq;
	int ret = DRIVER_ERROR << 24;

	req = blk_get_request(sdev->request_queue,
			data_direction == DMA_TO_DEVICE ?
			REQ_OP_SCSI_OUT : REQ_OP_SCSI_IN,
			rq_flags & RQF_PM ? BLK_MQ_REQ_PM : 0);
	if (IS_ERR(req))
		return ret;
	rq = scsi_req(req);

	if (bufflen &&	blk_rq_map_kern(sdev->request_queue, req,
					buffer, bufflen, GFP_NOIO))
		goto out;
```

**`drivers/scsi/scsi_lib.c:261-295`**  `__scsi_execute`（`blk_execute_rq` 等待结果）

```c
	rq->cmd_len = COMMAND_SIZE(cmd[0]);
	memcpy(rq->cmd, cmd, rq->cmd_len);
	rq->retries = retries;
	req->timeout = timeout;
	req->cmd_flags |= flags;
	req->rq_flags |= rq_flags | RQF_QUIET;

	/*
	 * head injection *required* here otherwise quiesce won't work
	 */
	blk_execute_rq(req->q, NULL, req, 1);

	/*
	 * Some devices (USB mass-storage in particular) may transfer
	 * garbage data together with a residue indicating that the data
	 * is invalid.  Prevent the garbage from being misinterpreted
	 * and prevent security leaks by zeroing out the excess data.
	 */
	if (unlikely(rq->resid_len > 0 && rq->resid_len <= bufflen))
		memset(buffer + (bufflen - rq->resid_len), 0, rq->resid_len);

	if (resid)
		*resid = rq->resid_len;
	if (sense && rq->sense_len)
		memcpy(sense, rq->sense, SCSI_SENSE_BUFFERSIZE);
	if (sshdr)
		scsi_normalize_sense(rq->sense, rq->sense_len, sshdr);
	ret = rq->result;
 out:
	blk_put_request(req);

	return ret;
}
EXPORT_SYMBOL(__scsi_execute);
```

**`include/scsi/scsi_request.h:20-23`**  `scsi_req`

```c
static inline struct scsi_request *scsi_req(struct request *rq)
{
	return blk_mq_rq_to_pdu(rq);
}
```

**`include/linux/blk-mq.h:560-572`**  `blk_mq_rq_to_pdu`

```c
/**
 * blk_mq_rq_to_pdu - cast a request to a PDU
 * @rq: the request to be casted
 *
 * Return: pointer to the PDU
 *
 * Driver command data is immediately after the request. So add request to get
 * the PDU.
 */
static inline void *blk_mq_rq_to_pdu(struct request *rq)
{
	return rq + 1;
}
```

首先从blk层申请到req, 再调用 scsi_req 得到scsi的rq,设置好req后调用blk_execute_rq
转入blk层具体处理 该rq
（对应 `__scsi_execute` 内 `req = blk_get_request()`（`block/blk-core.c:640`）→ `rq = scsi_req(req)` → `blk_execute_rq()`）

**`block/blk-exec.c:68-95`**  `blk_execute_rq`（同步等待完成）

```c
/**
 * blk_execute_rq - insert a request into queue for execution
 * @q:		queue to insert the request in
 * @bd_disk:	matching gendisk
 * @rq:		request to insert
 * @at_head:    insert request at head or tail of queue
 *
 * Description:
 *    Insert a fully prepared request at the back of the I/O scheduler queue
 *    for execution and wait for completion.
 */
void blk_execute_rq(struct request_queue *q, struct gendisk *bd_disk,
		   struct request *rq, int at_head)
{
	DECLARE_COMPLETION_ONSTACK(wait);
	unsigned long hang_check;

	rq->end_io_data = &wait;
	blk_execute_rq_nowait(q, bd_disk, rq, at_head, blk_end_sync_rq);

	/* Prevent hang_check timer from firing at us during very long I/O */
	hang_check = sysctl_hung_task_timeout_secs;
	if (hang_check)
		while (!wait_for_completion_io_timeout(&wait, hang_check * (HZ/2)));
	else
		wait_for_completion_io(&wait);
}
EXPORT_SYMBOL(blk_execute_rq);
```

**`kernel/hung_task.c:43-46`**  `sysctl_hung_task_timeout_secs`

```c
/*
 * Zero means infinite timeout - no checking done:
 */
unsigned long __read_mostly sysctl_hung_task_timeout_secs = CONFIG_DEFAULT_HUNG_TASK_TIMEOUT;
```

该值是hung_task 检测超时的秒数，`CONFIG_DEFAULT_HUNG_TASK_TIMEOUT` 默认 120s（`lib/Kconfig.debug:1032`，本工程 `gki_defconfig` 已开 `CONFIG_DETECT_HUNG_TASK=y`）；如果系统没有打开HUNG_TASK 功能则为0
【更正】原描述“调用 wait_for_completion_io 会在系统IO操作完成后才返回”不完整：
- `hang_check = sysctl_hung_task_timeout_secs`；`hang_check != 0`（本工程即 120s）时走 `while (!wait_for_completion_io_timeout(&wait, hang_check * (HZ/2)))` 循环，每 60s 醒一次检查，IO 完成即返回；
- 只有 `hang_check == 0`（未开 HUNG_TASK）才会调用 `wait_for_completion_io(&wait)` 无限阻塞等待。

**`block/blk-exec.c:33-66`**  `blk_execute_rq_nowait`（插入队列，不等待）

```c
/**
 * blk_execute_rq_nowait - insert a request into queue for execution
 * @q:		queue to insert the request in
 * @bd_disk:	matching gendisk
 * @rq:		request to insert
 * @at_head:    insert request at head or tail of queue
 * @done:	I/O completion handler
 *
 * Description:
 *    Insert a fully prepared request at the back of the I/O scheduler queue
 *    for execution.  Don't wait for completion.
 *
 * Note:
 *    This function will invoke @done directly if the queue is dead.
 */
void blk_execute_rq_nowait(struct request_queue *q, struct gendisk *bd_disk,
			   struct request *rq, int at_head,
			   rq_end_io_fn *done)
{
	WARN_ON(irqs_disabled());
	WARN_ON(!blk_rq_is_passthrough(rq));

	rq->rq_disk = bd_disk;
	rq->end_io = done;

	blk_account_io_start(rq);

	/*
	 * don't check dying flag for MQ because the request won't
	 * be reused after dying flag is set
	 */
	blk_mq_sched_insert_request(rq, at_head, true, false);
}
EXPORT_SYMBOL_GPL(blk_execute_rq_nowait);
```

**`block/blk-mq-sched.c:425-476`**  `blk_mq_sched_insert_request`（插入调度/dispatch）

```c
void blk_mq_sched_insert_request(struct request *rq, bool at_head,
				 bool run_queue, bool async)
{
	struct request_queue *q = rq->q;
	struct elevator_queue *e = q->elevator;
	struct blk_mq_ctx *ctx = rq->mq_ctx;
	struct blk_mq_hw_ctx *hctx = rq->mq_hctx;

	WARN_ON(e && (rq->tag != BLK_MQ_NO_TAG));

	if (blk_mq_sched_bypass_insert(hctx, !!e, rq)) {
		/*
		 * Firstly normal IO request is inserted to scheduler queue or
		 * sw queue, meantime we add flush request to dispatch queue(
		 * hctx->dispatch) directly and there is at most one in-flight
		 * flush request for each hw queue, so it doesn't matter to add
		 * flush request to tail or front of the dispatch queue.
		 *
		 * Secondly in case of NCQ, flush request belongs to non-NCQ
		 * command, and queueing it will fail when there is any
		 * in-flight normal IO request(NCQ command). When adding flush
		 * rq to the front of hctx->dispatch, it is easier to introduce
		 * extra time to flush rq's latency because of S_SCHED_RESTART
		 * compared with adding to the tail of dispatch queue, then
		 * chance of flush merge is increased, and less flush requests
		 * will be issued to controller. It is observed that ~10% time
		 * is saved in blktests block/004 on disk attached to AHCI/NCQ
		 * drive when adding flush rq to the front of hctx->dispatch.
		 *
		 * Simply queue flush rq to the front of hctx->dispatch so that
		 * intensive flush workloads can benefit in case of NCQ HW.
		 */
		at_head = (rq->rq_flags & RQF_FLUSH_SEQ) ? true : at_head;
		blk_mq_request_bypass_insert(rq, at_head, false);
		goto run;
	}

	if (e && e->type->ops.insert_requests) {
		LIST_HEAD(list);

		list_add(&rq->queuelist, &list);
		e->type->ops.insert_requests(hctx, &list, at_head);
	} else {
		spin_lock(&ctx->lock);
		__blk_mq_insert_request(hctx, rq, at_head);
		spin_unlock(&ctx->lock);
	}

run:
	if (run_queue)
		blk_mq_run_hw_queue(hctx, async);
}
```

**`block/blk-mq.c:1887-1910`**  `blk_mq_request_bypass_insert`（直插 dispatch）

```c
/**
 * blk_mq_request_bypass_insert - Insert a request at dispatch list.
 * @rq: Pointer to request to be inserted.
 * @at_head: true if the request should be inserted at the head of the list.
 * @run_queue: If we should run the hardware queue after inserting the request.
 *
 * Should only be used carefully, when the caller knows we want to
 * bypass a potential IO scheduler on the target device.
 */
void blk_mq_request_bypass_insert(struct request *rq, bool at_head,
				  bool run_queue)
{
	struct blk_mq_hw_ctx *hctx = rq->mq_hctx;

	spin_lock(&hctx->lock);
	if (at_head)
		list_add(&rq->queuelist, &hctx->dispatch);
	else
		list_add_tail(&rq->queuelist, &hctx->dispatch);
	spin_unlock(&hctx->lock);

	if (run_queue)
		blk_mq_run_hw_queue(hctx, false);
}
```

将请求插入调度队列，然后发送请求到硬件。

**`block/blk-mq.c:1636-1657`**  `blk_mq_run_hw_queue`

```c
void blk_mq_run_hw_queue(struct blk_mq_hw_ctx *hctx, bool async)
{
	int srcu_idx;
	bool need_run;

	/*
	 * When queue is quiesced, we may be switching io scheduler, or
	 * updating nr_hw_queues, or other things, and we can't run queue
	 * any more, even __blk_mq_hctx_has_pending() can't be called safely.
	 *
	 * And queue will be rerun in blk_mq_unquiesce_queue() if it is
	 * quiesced.
	 */
	hctx_lock(hctx, &srcu_idx);
	need_run = !blk_queue_quiesced(hctx->queue) &&
		blk_mq_hctx_has_pending(hctx);
	hctx_unlock(hctx, srcu_idx);

	if (need_run)
		__blk_mq_delay_run_hw_queue(hctx, async, 0);
}
EXPORT_SYMBOL(blk_mq_run_hw_queue);
```

> 以下两段为补充，说明请求如何从 blk 层真正发到硬件（原截图未展示）：

**`drivers/scsi/scsi_lib.c:1642-1696`**  `scsi_queue_rq`（blk-mq `queue_rq` 回调）

```c
static blk_status_t scsi_queue_rq(struct blk_mq_hw_ctx *hctx,
			 const struct blk_mq_queue_data *bd)
{
	struct request *req = bd->rq;
	struct request_queue *q = req->q;
	struct scsi_device *sdev = q->queuedata;
	struct Scsi_Host *shost = sdev->host;
	struct scsi_cmnd *cmd = blk_mq_rq_to_pdu(req);
	blk_status_t ret;
	int reason;

	/*
	 * If the device is not in running state we will reject some or all
	 * commands.
	 */
	if (unlikely(sdev->sdev_state != SDEV_RUNNING)) {
		ret = scsi_device_state_check(sdev, req);
		if (ret != BLK_STS_OK)
			goto out_put_budget;
	}

	ret = BLK_STS_RESOURCE;
	if (!scsi_target_queue_ready(shost, sdev))
		goto out_put_budget;
	if (!scsi_host_queue_ready(q, shost, sdev, cmd))
		goto out_dec_target_busy;

	if (!(req->rq_flags & RQF_DONTPREP)) {
		ret = scsi_prepare_cmd(req);
		if (ret != BLK_STS_OK)
			goto out_dec_host_busy;
		req->rq_flags |= RQF_DONTPREP;
	} else {
		clear_bit(SCMD_STATE_COMPLETE, &cmd->state);
	}

	cmd->flags &= SCMD_PRESERVED_FLAGS;
	if (sdev->simple_tags)
		cmd->flags |= SCMD_TAGGED;
	if (bd->last)
		cmd->flags |= SCMD_LAST;

	scsi_set_resid(cmd, 0);
	memset(cmd->sense_buffer, 0, SCSI_SENSE_BUFFERSIZE);
	cmd->scsi_done = scsi_mq_done;

	blk_mq_start_request(req);
	reason = scsi_dispatch_cmd(cmd);
	if (reason) {
		scsi_set_blocked(cmd, reason);
		ret = BLK_STS_RESOURCE;
		goto out_dec_host_busy;
	}

	return BLK_STS_OK;
```

**`drivers/scsi/scsi_lib.c:1523-1536`**  `scsi_dispatch_cmd` 尾部 → `hostt->queuecommand`（即 `ufshcd_queuecommand`）

```c
	trace_scsi_dispatch_cmd_start(cmd);
	rtn = host->hostt->queuecommand(host, cmd);
	if (rtn) {
		atomic_dec(&cmd->device->iorequest_cnt);
		trace_scsi_dispatch_cmd_error(cmd, rtn);
		if (rtn != SCSI_MLQUEUE_DEVICE_BUSY &&
		    rtn != SCSI_MLQUEUE_TARGET_BUSY)
			rtn = SCSI_MLQUEUE_HOST_BUSY;

		SCSI_LOG_MLQUEUE(3, scmd_printk(KERN_INFO, cmd,
			"queuecommand : request rejected\n"));
	}

	return rtn;
```

当请求超时后没有执行，会调用blk_mq_rq_timed_out 函数做超时后的处理
看下请求队列的初始化以及超时是如何监控的。

> 超时链（更正/补全）：`blk_mq_start_request`→`blk_add_timer` 起 `q->timeout` 定时器 → `blk_rq_timed_out_timer`(`block/blk-core.c:519`) → `kblockd_schedule_work(&q->timeout_work)` → `blk_mq_timeout_work`(`block/blk-mq.c:961`) → `blk_mq_queue_tag_busy_iter`+`blk_mq_check_expired` → `blk_mq_rq_timed_out`(:901) → `q->mq_ops->timeout` = `scsi_timeout` → `scsi_times_out` → abort/错误恢复。

**`drivers/scsi/ufs/ufshcd.c:9437-9462`**  `ufshcd_init` 中 `scsi_add_host` → `blk_mq_init_queue` / `blk_mq_alloc_tag_set`

```c
	err = scsi_add_host(host, hba->dev);
	if (err) {
		dev_err(hba->dev, "scsi_add_host failed\n");
		goto out_disable;
	}

	hba->cmd_queue = blk_mq_init_queue(&hba->host->tag_set);
	if (IS_ERR(hba->cmd_queue)) {
		err = PTR_ERR(hba->cmd_queue);
		goto out_remove_scsi_host;
	}

	hba->tmf_tag_set = (struct blk_mq_tag_set) {
		.nr_hw_queues	= 1,
		.queue_depth	= hba->nutmrs,
		.ops		= &ufshcd_tmf_ops,
		.flags		= BLK_MQ_F_NO_SCHED,
	};
	err = blk_mq_alloc_tag_set(&hba->tmf_tag_set);
	if (err < 0)
		goto free_cmd_queue;
	hba->tmf_queue = blk_mq_init_queue(&hba->tmf_tag_set);
	if (IS_ERR(hba->tmf_queue)) {
		err = PTR_ERR(hba->tmf_queue);
		goto free_tmf_tag_set;
	}
```

**`block/blk-mq.c:3161-3164`**  `blk_mq_init_queue`

```c
struct request_queue *blk_mq_init_queue(struct blk_mq_tag_set *set)
{
	return blk_mq_init_queue_data(set, NULL);
}
```

**`block/blk-mq.c:3139-3158`**  `blk_mq_init_queue_data`（`blk_alloc_queue` + `blk_mq_init_allocated_queue`）

```c
struct request_queue *blk_mq_init_queue_data(struct blk_mq_tag_set *set,
		void *queuedata)
{
	struct request_queue *uninit_q, *q;

	uninit_q = blk_alloc_queue(set->numa_node);
	if (!uninit_q)
		return ERR_PTR(-ENOMEM);
	uninit_q->queuedata = queuedata;

	/*
	 * Initialize the queue without an elevator. device_add_disk() will do
	 * the initialization.
	 */
	q = blk_mq_init_allocated_queue(set, uninit_q, false);
	if (IS_ERR(q))
		blk_cleanup_queue(uninit_q);

	return q;
}
```

**`block/blk-mq.c:3312-3381`**  `blk_mq_init_allocated_queue`（:3338 `INIT_WORK(timeout_work, blk_mq_timeout_work)`；:3339 默认 `rq_timeout = 30*HZ`）

```c
struct request_queue *blk_mq_init_allocated_queue(struct blk_mq_tag_set *set,
						  struct request_queue *q,
						  bool elevator_init)
{
	/* mark the queue as mq asap */
	q->mq_ops = set->ops;

	q->poll_cb = blk_stat_alloc_callback(blk_mq_poll_stats_fn,
					     blk_mq_poll_stats_bkt,
					     BLK_MQ_POLL_STATS_BKTS, q);
	if (!q->poll_cb)
		goto err_exit;

	if (blk_mq_alloc_ctxs(q))
		goto err_poll;

	/* init q->mq_kobj and sw queues' kobjects */
	blk_mq_sysfs_init(q);

	INIT_LIST_HEAD(&q->unused_hctx_list);
	spin_lock_init(&q->unused_hctx_lock);

	blk_mq_realloc_hw_ctxs(set, q);
	if (!q->nr_hw_queues)
		goto err_hctxs;

	INIT_WORK(&q->timeout_work, blk_mq_timeout_work);
	blk_queue_rq_timeout(q, set->timeout ? set->timeout : 30 * HZ);

	q->tag_set = set;

	q->queue_flags |= QUEUE_FLAG_MQ_DEFAULT;
	if (set->nr_maps > HCTX_TYPE_POLL &&
	    set->map[HCTX_TYPE_POLL].nr_queues)
		blk_queue_flag_set(QUEUE_FLAG_POLL, q);

	q->sg_reserved_size = INT_MAX;

	INIT_DELAYED_WORK(&q->requeue_work, blk_mq_requeue_work);
	INIT_LIST_HEAD(&q->requeue_list);
	spin_lock_init(&q->requeue_lock);

	q->nr_requests = set->queue_depth;

	/*
	 * Default to classic polling
	 */
	q->poll_nsec = BLK_MQ_POLL_CLASSIC;

	blk_mq_init_cpu_queues(q, set->nr_hw_queues);
	blk_mq_add_queue_tag_set(set, q);
	blk_mq_map_swqueue(q);

	if (elevator_init)
		elevator_init_mq(q);

	return q;

err_hctxs:
	kfree(q->queue_hw_ctx);
	q->nr_hw_queues = 0;
	blk_mq_sysfs_deinit(q);
err_poll:
	blk_stat_free_callback(q->poll_cb);
	q->poll_cb = NULL;
err_exit:
	q->mq_ops = NULL;
	return ERR_PTR(-ENOMEM);
}
EXPORT_SYMBOL(blk_mq_init_allocated_queue);
```

**`block/blk-core.c:530-565`**  `blk_alloc_queue`（:564 `timer_setup(&q->timeout, blk_rq_timed_out_timer, 0)`）

```c
struct request_queue *blk_alloc_queue(int node_id)
{
	struct request_queue *q;
	int ret;

	q = kmem_cache_alloc_node(blk_requestq_cachep,
				GFP_KERNEL | __GFP_ZERO, node_id);
	if (!q)
		return NULL;

	q->last_merge = NULL;

	q->id = ida_simple_get(&blk_queue_ida, 0, 0, GFP_KERNEL);
	if (q->id < 0)
		goto fail_q;

	ret = bioset_init(&q->bio_split, BIO_POOL_SIZE, 0, BIOSET_NEED_BVECS);
	if (ret)
		goto fail_id;

	q->backing_dev_info = bdi_alloc(node_id);
	if (!q->backing_dev_info)
		goto fail_split;

	q->stats = blk_alloc_queue_stats();
	if (!q->stats)
		goto fail_stats;

	q->node = node_id;

	atomic_set(&q->nr_active_requests_shared_sbitmap, 0);

	timer_setup(&q->backing_dev_info->laptop_mode_wb_timer,
		    laptop_mode_timer_fn, 0);
	timer_setup(&q->timeout, blk_rq_timed_out_timer, 0);
	INIT_WORK(&q->timeout_work, blk_timeout_work);
```

**`block/blk-core.c:519-528`**  `blk_rq_timed_out_timer`（触发 timeout_work；`blk_timeout_work` 为空，MQ 队列由 :3338 覆盖为 `blk_mq_timeout_work`）

```c
static void blk_rq_timed_out_timer(struct timer_list *t)
{
	struct request_queue *q = from_timer(q, t, timeout);

	kblockd_schedule_work(&q->timeout_work);
}

static void blk_timeout_work(struct work_struct *work)
{
}
```

**`block/blk-timeout.c:120-167`**  `blk_add_timer`（请求启动时登记超时定时器）

```c
/**
 * blk_add_timer - Start timeout timer for a single request
 * @req:	request that is about to start running.
 *
 * Notes:
 *    Each request has its own timer, and as it is added to the queue, we
 *    set up the timer. When the request completes, we cancel the timer.
 */
void blk_add_timer(struct request *req)
{
	struct request_queue *q = req->q;
	unsigned long expiry;

	/*
	 * Some LLDs, like scsi, peek at the timeout to prevent a
	 * command from being retried forever.
	 */
	if (!req->timeout)
		req->timeout = q->rq_timeout;

	req->rq_flags &= ~RQF_TIMED_OUT;

	expiry = jiffies + req->timeout;
	WRITE_ONCE(req->deadline, expiry);

	/*
	 * If the timer isn't already pending or this timeout is earlier
	 * than an existing one, modify the timer. Round up to next nearest
	 * second.
	 */
	expiry = blk_rq_timeout(blk_round_jiffies(expiry));

	if (!timer_pending(&q->timeout) ||
	    time_before(expiry, q->timeout.expires)) {
		unsigned long diff = q->timeout.expires - expiry;

		/*
		 * Due to added timer slack to group timers, the timer
		 * will often be a little in front of what we asked for.
		 * So apply some tolerance here too, otherwise we keep
		 * modifying the timer because expires for value X
		 * will be X + something.
		 */
		if (!timer_pending(&q->timeout) || (diff >= HZ / 2))
			mod_timer(&q->timeout, expiry);
	}

}
```

**`block/blk-mq-tag.c:422-465`**  `blk_mq_queue_tag_busy_iter`

```c
/**
 * blk_mq_queue_tag_busy_iter - iterate over all requests with a driver tag
 * @q:		Request queue to examine.
 * @fn:		Pointer to the function that will be called for each request
 *		on @q. @fn will be called as follows: @fn(hctx, rq, @priv,
 *		reserved) where rq is a pointer to a request and hctx points
 *		to the hardware queue associated with the request. 'reserved'
 *		indicates whether or not @rq is a reserved request.
 * @priv:	Will be passed as third argument to @fn.
 *
 * Note: if @q->tag_set is shared with other request queues then @fn will be
 * called for all requests on all queues that share that tag set and not only
 * for requests associated with @q.
 */
void blk_mq_queue_tag_busy_iter(struct request_queue *q, busy_iter_fn *fn,
		void *priv)
{
	struct blk_mq_hw_ctx *hctx;
	int i;

	/*
	 * __blk_mq_update_nr_hw_queues() updates nr_hw_queues and queue_hw_ctx
	 * while the queue is frozen. So we can use q_usage_counter to avoid
	 * racing with it.
	 */
	if (!percpu_ref_tryget(&q->q_usage_counter))
		return;

	queue_for_each_hw_ctx(q, hctx, i) {
		struct blk_mq_tags *tags = hctx->tags;

		/*
		 * If no software queues are currently mapped to this
		 * hardware queue, there's nothing to check
		 */
		if (!blk_mq_hw_queue_mapped(hctx))
			continue;

		if (tags->nr_reserved_tags)
			bt_for_each(hctx, tags->breserved_tags, fn, priv, true);
		bt_for_each(hctx, tags->bitmap_tags, fn, priv, false);
	}
	blk_queue_exit(q);
}
```

**`block/blk-mq.c:961-1003`**  `blk_mq_timeout_work`

```c
static void blk_mq_timeout_work(struct work_struct *work)
{
	struct request_queue *q =
		container_of(work, struct request_queue, timeout_work);
	unsigned long next = 0;
	struct blk_mq_hw_ctx *hctx;
	int i;

	/* A deadlock might occur if a request is stuck requiring a
	 * timeout at the same time a queue freeze is waiting
	 * completion, since the timeout code would not be able to
	 * acquire the queue reference here.
	 *
	 * That's why we don't use blk_queue_enter here; instead, we use
	 * percpu_ref_tryget directly, because we need to be able to
	 * obtain a reference even in the short window between the queue
	 * starting to freeze, by dropping the first reference in
	 * blk_freeze_queue_start, and the moment the last request is
	 * consumed, marked by the instant q_usage_counter reaches
	 * zero.
	 */
	if (!percpu_ref_tryget(&q->q_usage_counter))
		return;

	blk_mq_queue_tag_busy_iter(q, blk_mq_check_expired, &next);

	if (next != 0) {
		mod_timer(&q->timeout, next);
	} else {
		/*
		 * Request timeouts are handled as a forward rolling timer. If
		 * we end up here it means that no requests are pending and
		 * also that no request has been pending for a while. Mark
		 * each hctx as idle.
		 */
		queue_for_each_hw_ctx(q, hctx, i) {
			/* the hctx may be unmapped, so check it here */
			if (blk_mq_hw_queue_mapped(hctx))
				blk_mq_tag_idle(hctx);
		}
	}
	blk_queue_exit(q);
}
```

**`block/blk-mq.c:944-959`**  `blk_mq_check_expired`

```c
static bool blk_mq_check_expired(struct blk_mq_hw_ctx *hctx,
		struct request *rq, void *priv, bool reserved)
{
	unsigned long *next = priv;

	/*
	 * blk_mq_queue_tag_busy_iter() has locked the request, so it cannot
	 * be reallocated underneath the timeout handler's processing, then
	 * the expire check is reliable. If the request is not expired, then
	 * it was completed and reallocated as a new request after returning
	 * from blk_mq_check_expired().
	 */
	if (blk_mq_req_expired(rq, next))
		blk_mq_rq_timed_out(rq, reserved);
	return true;
}
```

**`block/blk-mq.c:901-914`**  `blk_mq_rq_timed_out`（回调 `q->mq_ops->timeout`）

```c
static void blk_mq_rq_timed_out(struct request *req, bool reserved)
{
	req->rq_flags |= RQF_TIMED_OUT;
	if (req->q->mq_ops->timeout) {
		enum blk_eh_timer_return ret;

		ret = req->q->mq_ops->timeout(req, reserved);
		if (ret == BLK_EH_DONE)
			return;
		WARN_ON_ONCE(ret != BLK_EH_RESET_TIMER);
	}

	blk_add_timer(req);
}
```

**`drivers/scsi/scsi_lib.c:1863-1879`**  `scsi_mq_ops`（`.timeout = scsi_timeout`）

```c
static const struct blk_mq_ops scsi_mq_ops = {
	.get_budget	= scsi_mq_get_budget,
	.put_budget	= scsi_mq_put_budget,
	.queue_rq	= scsi_queue_rq,
	.commit_rqs	= scsi_commit_rqs,
	.complete	= scsi_softirq_done,
	.timeout	= scsi_timeout,
#ifdef CONFIG_BLK_DEBUG_FS
	.show_rq	= scsi_show_rq,
#endif
	.init_request	= scsi_mq_init_request,
	.exit_request	= scsi_mq_exit_request,
	.initialize_rq_fn = scsi_initialize_rq,
	.cleanup_rq	= scsi_cleanup_rq,
	.busy		= scsi_mq_lld_busy,
	.map_queues	= scsi_map_queues,
};
```

**`drivers/scsi/scsi_lib.c:1731-1737`**  `scsi_timeout`

```c
static enum blk_eh_timer_return scsi_timeout(struct request *req,
		bool reserved)
{
	if (reserved)
		return BLK_EH_RESET_TIMER;
	return scsi_times_out(req);
}
```

**`drivers/scsi/scsi_error.c:282-321`**  `scsi_times_out`（超时处理入口，:314 起 abort）

```c
/**
 * scsi_times_out - Timeout function for normal scsi commands.
 * @req:	request that is timing out.
 *
 * Notes:
 *     We do not need to lock this.  There is the potential for a race
 *     only in that the normal completion handling might run, but if the
 *     normal completion function determines that the timer has already
 *     fired, then it mustn't do anything.
 */
enum blk_eh_timer_return scsi_times_out(struct request *req)
{
	struct scsi_cmnd *scmd = blk_mq_rq_to_pdu(req);
	enum blk_eh_timer_return rtn = BLK_EH_DONE;
	struct Scsi_Host *host = scmd->device->host;

	trace_scsi_dispatch_cmd_timeout(scmd);
	scsi_log_completion(scmd, TIMEOUT_ERROR);

	if (host->eh_deadline != -1 && !host->last_reset)
		host->last_reset = jiffies;

	if (host->hostt->eh_timed_out)
		rtn = host->hostt->eh_timed_out(scmd);

	if (rtn == BLK_EH_DONE) {
		/*
		 * If scsi_done() has already set SCMD_STATE_COMPLETE, do not
		 * modify *scmd.
		 */
		if (test_and_set_bit(SCMD_STATE_COMPLETE, &scmd->state))
			return BLK_EH_DONE;
		if (scsi_abort_command(scmd) != SUCCESS) {
			set_host_byte(scmd, DID_TIME_OUT);
			scsi_eh_scmd_add(scmd);
		}
	}

	return rtn;
}
```

超时后的 abort/错误恢复链（按实际执行顺序，原截图顺序已调整）：
`scsi_times_out` → `scsi_abort_command`（10ms 后调度 `abort_work`）→ `scmd_eh_abort_handler` → `scsi_try_to_abort_cmd` → `hostt->eh_abort_handler` = `ufshcd_abort`；abort 失败/超期则 `scsi_eh_scmd_add` 进入 SCSI EH → `scsi_try_host_reset` → `ufshcd_eh_host_reset_handler`(`ufshcd.c:7183`) → `ufshcd_reset_and_restore`（见本节开头）。

**`drivers/scsi/scsi_error.c:187-221`**  `scsi_abort_command`（调度 abort_work，HZ/100）

```c
/**
 * scsi_abort_command - schedule a command abort
 * @scmd:	scmd to abort.
 *
 * We only need to abort commands after a command timeout
 */
static int
scsi_abort_command(struct scsi_cmnd *scmd)
{
	struct scsi_device *sdev = scmd->device;
	struct Scsi_Host *shost = sdev->host;
	unsigned long flags;

	if (scmd->eh_eflags & SCSI_EH_ABORT_SCHEDULED) {
		/*
		 * Retry after abort failed, escalate to next level.
		 */
		SCSI_LOG_ERROR_RECOVERY(3,
			scmd_printk(KERN_INFO, scmd,
				    "previous abort failed\n"));
		BUG_ON(delayed_work_pending(&scmd->abort_work));
		return FAILED;
	}

	spin_lock_irqsave(shost->host_lock, flags);
	if (shost->eh_deadline != -1 && !shost->last_reset)
		shost->last_reset = jiffies;
	spin_unlock_irqrestore(shost->host_lock, flags);

	scmd->eh_eflags |= SCSI_EH_ABORT_SCHEDULED;
	SCSI_LOG_ERROR_RECOVERY(3,
		scmd_printk(KERN_INFO, scmd, "abort scheduled\n"));
	queue_delayed_work(shost->tmf_work_q, &scmd->abort_work, HZ / 100);
	return SUCCESS;
}
```

**`drivers/scsi/scsi_lib.c:1133-1172`**  `scsi_init_command`（:1166 `INIT_DELAYED_WORK(&cmd->abort_work, scmd_eh_abort_handler)`）

```c
/* Called before a request is prepared. See also scsi_mq_prep_fn(). */
void scsi_init_command(struct scsi_device *dev, struct scsi_cmnd *cmd)
{
	void *buf = cmd->sense_buffer;
	void *prot = cmd->prot_sdb;
	struct request *rq = blk_mq_rq_from_pdu(cmd);
	unsigned int flags = cmd->flags & SCMD_PRESERVED_FLAGS;
	unsigned long jiffies_at_alloc;
	int retries, to_clear;
	bool in_flight;

	if (!blk_rq_is_scsi(rq) && !(flags & SCMD_INITIALIZED)) {
		flags |= SCMD_INITIALIZED;
		scsi_initialize_rq(rq);
	}

	jiffies_at_alloc = cmd->jiffies_at_alloc;
	retries = cmd->retries;
	in_flight = test_bit(SCMD_STATE_INFLIGHT, &cmd->state);
	/*
	 * Zero out the cmd, except for the embedded scsi_request. Only clear
	 * the driver-private command data if the LLD does not supply a
	 * function to initialize that data.
	 */
	to_clear = sizeof(*cmd) - sizeof(cmd->req);
	if (!dev->host->hostt->init_cmd_priv)
		to_clear += dev->host->hostt->cmd_size;
	memset((char *)cmd + sizeof(cmd->req), 0, to_clear);

	cmd->device = dev;
	cmd->sense_buffer = buf;
	cmd->prot_sdb = prot;
	cmd->flags = flags;
	INIT_DELAYED_WORK(&cmd->abort_work, scmd_eh_abort_handler);
	cmd->jiffies_at_alloc = jiffies_at_alloc;
	cmd->retries = retries;
	if (in_flight)
		__set_bit(SCMD_STATE_INFLIGHT, &cmd->state);

}
```

**`drivers/scsi/scsi_error.c:127-186`**  `scmd_eh_abort_handler`（原截图中函数名为 `scsi_eh_abort_handler`，本工程为 `scmd_eh_abort_handler`）

```c
/**
 * scmd_eh_abort_handler - Handle command aborts
 * @work:	command to be aborted.
 *
 * Note: this function must be called only for a command that has timed out.
 * Because the block layer marks a request as complete before it calls
 * scsi_times_out(), a .scsi_done() call from the LLD for a command that has
 * timed out do not have any effect. Hence it is safe to call
 * scsi_finish_command() from this function.
 */
void
scmd_eh_abort_handler(struct work_struct *work)
{
	struct scsi_cmnd *scmd =
		container_of(work, struct scsi_cmnd, abort_work.work);
	struct scsi_device *sdev = scmd->device;
	int rtn;

	if (scsi_host_eh_past_deadline(sdev->host)) {
		SCSI_LOG_ERROR_RECOVERY(3,
			scmd_printk(KERN_INFO, scmd,
				    "eh timeout, not aborting\n"));
	} else {
		SCSI_LOG_ERROR_RECOVERY(3,
			scmd_printk(KERN_INFO, scmd,
				    "aborting command\n"));
		rtn = scsi_try_to_abort_cmd(sdev->host->hostt, scmd);
		if (rtn == SUCCESS) {
			set_host_byte(scmd, DID_TIME_OUT);
			if (scsi_host_eh_past_deadline(sdev->host)) {
				SCSI_LOG_ERROR_RECOVERY(3,
					scmd_printk(KERN_INFO, scmd,
						    "eh timeout, not retrying "
						    "aborted command\n"));
			} else if (!scsi_noretry_cmd(scmd) &&
				   scsi_cmd_retry_allowed(scmd)) {
				SCSI_LOG_ERROR_RECOVERY(3,
					scmd_printk(KERN_WARNING, scmd,
						    "retry aborted command\n"));
				scsi_queue_insert(scmd, SCSI_MLQUEUE_EH_RETRY);
				return;
			} else {
				SCSI_LOG_ERROR_RECOVERY(3,
					scmd_printk(KERN_WARNING, scmd,
						    "finish aborted command\n"));
				scsi_finish_command(scmd);
				return;
			}
		} else {
			SCSI_LOG_ERROR_RECOVERY(3,
				scmd_printk(KERN_INFO, scmd,
					    "cmd abort %s\n",
					    (rtn == FAST_IO_FAIL) ?
					    "not send" : "failed"));
		}
	}

	scsi_eh_scmd_add(scmd);
}
```

**`drivers/scsi/scsi_error.c:904-928`**  `scsi_try_to_abort_cmd` → `hostt->eh_abort_handler`

```c
/**
 * scsi_try_to_abort_cmd - Ask host to abort a SCSI command
 * @hostt:	SCSI driver host template
 * @scmd:	SCSI cmd used to send a target reset
 *
 * Return value:
 *	SUCCESS, FAILED, or FAST_IO_FAIL
 *
 * Notes:
 *    SUCCESS does not necessarily indicate that the command
 *    has been aborted; it only indicates that the LLDDs
 *    has cleared all references to that command.
 *    LLDDs should return FAILED only if an abort was required
 *    but could not be executed. LLDDs should return FAST_IO_FAIL
 *    if the device is temporarily unavailable (eg due to a
 *    link down on FibreChannel)
 */
static int scsi_try_to_abort_cmd(struct scsi_host_template *hostt,
				 struct scsi_cmnd *scmd)
{
	if (!hostt->eh_abort_handler)
		return FAILED;

	return hostt->eh_abort_handler(scmd);
}
```

→ `ufshcd_abort`（`drivers/scsi/ufs/ufshcd.c:6972`，见本节开头，原截图在此重复展示了该函数）

**`drivers/scsi/scsi_error.c:252-280`**  `scsi_eh_scmd_add`（abort 失败后把命令挂入 EH 队列）

```c
/**
 * scsi_eh_scmd_add - add scsi cmd to error handling.
 * @scmd:	scmd to run eh on.
 */
void scsi_eh_scmd_add(struct scsi_cmnd *scmd)
{
	struct Scsi_Host *shost = scmd->device->host;
	unsigned long flags;
	int ret;

	WARN_ON_ONCE(!shost->ehandler);

	spin_lock_irqsave(shost->host_lock, flags);
	if (scsi_host_set_state(shost, SHOST_RECOVERY)) {
		ret = scsi_host_set_state(shost, SHOST_CANCEL_RECOVERY);
		WARN_ON_ONCE(ret);
	}
	if (shost->eh_deadline != -1 && !shost->last_reset)
		shost->last_reset = jiffies;

	scsi_eh_reset(scmd);
	list_add_tail(&scmd->eh_entry, &shost->eh_cmd_q);
	spin_unlock_irqrestore(shost->host_lock, flags);
	/*
	 * Ensure that all tasks observe the host state change before the
	 * host_failed change.
	 */
	call_rcu(&scmd->rcu, scsi_eh_inc_host_failed);
}
```

**`drivers/scsi/scsi_error.c:783-811`**  `scsi_try_host_reset` → `hostt->eh_host_reset_handler`

```c
/**
 * scsi_try_host_reset - ask host adapter to reset itself
 * @scmd:	SCSI cmd to send host reset.
 */
static int scsi_try_host_reset(struct scsi_cmnd *scmd)
{
	unsigned long flags;
	int rtn;
	struct Scsi_Host *host = scmd->device->host;
	struct scsi_host_template *hostt = host->hostt;

	SCSI_LOG_ERROR_RECOVERY(3,
		shost_printk(KERN_INFO, host, "Snd Host RST\n"));

	if (!hostt->eh_host_reset_handler)
		return FAILED;

	rtn = hostt->eh_host_reset_handler(scmd);

	if (rtn == SUCCESS) {
		if (!hostt->skip_settle_delay)
			ssleep(HOST_RESET_SETTLE_TIME);
		spin_lock_irqsave(host->host_lock, flags);
		scsi_report_bus_reset(host, scmd_channel(scmd));
		spin_unlock_irqrestore(host->host_lock, flags);
	}

	return rtn;
}
```

> 整机“重启”链（补充，原文档未截图）：IO 卡死 → D 状态超 `sysctl_hung_task_timeout_secs`(120s) → `kernel/hung_task.c:219` `panic("hung_task: blocked tasks")` 仅在 `hung_task_call_panic` 为真时触发，而它由 `sysctl_hung_task_panic` 置位（`hung_task.c:118-121`，默认值 `CONFIG_BOOTPARAM_HUNG_TASK_PANIC_VALUE=0`，本工程未开 `CONFIG_BOOTPARAM_HUNG_TASK_PANIC`）；一旦 panic，`kernel/panic.c:404-412` 因 `CONFIG_PANIC_TIMEOUT=-1`（`gki_defconfig:693`，n<0 立即重启）调用 `emergency_restart()` → `kernel/reboot.c:66` → `arch/arm64/kernel/process.c:187 machine_restart` → `do_kernel_restart` → `drivers/firmware/psci/psci.c:298 psci_sys_reset`。`CONFIG_PANIC_ON_OOPS=y` 保证 oops 也会走 panic。

