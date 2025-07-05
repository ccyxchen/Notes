# lastkmsg 实现保存上次开机log
`vendor\bsp\kernel5.15\kernel5.15\drivers\unisoc_platform\sysdump\last_kmsg.c`
```c
static const char *devicename = "/dev/block/by-name/common_rs1_a";
static const char *sdklog_path = "/dev/block/by-name/sd_klog";

static void save_log_to_partition(void *buf)
{
	int ret;
	static struct file *plog_file;

	if (shutdown_save_log_flag == 1)
		return;

	plog_file = filp_open_block(sdklog_path, O_RDWR | O_DSYNC | O_NOATIME | O_EXCL, 0);
	if (IS_ERR(plog_file)) {
		ret = PTR_ERR(plog_file);
		pr_err("failed to open '%s':%d!\n", sdklog_path, ret);
		plog_file = filp_open_block(devicename, O_RDWR | O_DSYNC | O_NOATIME | O_EXCL, 0);
		if (IS_ERR(plog_file)) {
			ret = PTR_ERR(plog_file);
			pr_err("failed to open '%s':%d!\n", devicename, ret);
			return;
		}
	}

	/* handle last kmsg */
	get_last_kmsg(kmsg_buf, KMSG_BUF_SIZE, buf);

	if (kmsg_buf == NULL) {
		pr_err("kmsg_buf is null, return!\n");
		goto end;
	}
	sysdump_set_property(plog_file, UBI_VOL_PROP_DIRECT_WRITE, 1);
	//将kernel log和ylog 保存到log分区
	ret = write_data_to_ubi_partition(plog_file, kmsg_buf, KMSG_BUF_SIZE, LAST_KMSG_OFFSET);
	if (ret != KMSG_BUF_SIZE)
		pr_err("write kmsg to partition error! :%d!\n", ret);

	/* handle last android log */
	if (ylog_buffer == NULL) {
		pr_err("ylog_buffer is null, return!\n");
		goto end;
	}

	ret = write_data_to_ubi_partition(plog_file, ylog_buffer, YLOG_BUF_SIZE,
		LAST_ANDROID_LOG_OFFSET);
	if (ret != YLOG_BUF_SIZE)
		pr_err("write kmsg to partition error! :%d!\n", ret);

end:
	filp_close(plog_file, NULL);

}
```
## ylog 保存的机制
### 底层会将ylog buffer映射到上层写入：
```c
static int ylog_buffer_map(struct file *filp, struct vm_area_struct *vma)
{
	unsigned long ylog_buffer_paddr;

	if (vma->vm_end - vma->vm_start > YLOG_BUF_SIZE)
		return -EINVAL;

	ylog_buffer_paddr = virt_to_phys(ylog_buffer);
	if (remap_pfn_range(vma,
			vma->vm_start,
			ylog_buffer_paddr >> PAGE_SHIFT, /*	get pfn */
			vma->vm_end - vma->vm_start,
			vma->vm_page_prot))
		return -ENOMEM;

//	pr_info("mmap ylog_buffer ok !\n");
	return 0;
}

static const struct file_operations ylog_buffer_fops = {
	.owner = THIS_MODULE,
	.open = ylog_buffer_open,
	.mmap = ylog_buffer_map,
};

static struct miscdevice misc_dev_ylog = {
	.minor = MISC_DYNAMIC_MINOR,
	.name = DEVICE_NAME_YLOG,
	.fops = &ylog_buffer_fops,
};
static int ylog_buffer_init(void)
{
	int ret;

	ylog_buffer = kzalloc(YLOG_BUF_SIZE, GFP_KERNEL);
	if (ylog_buffer == NULL) {
		return -ENOMEM;
	}
//	pr_info("%s: ylog_buffer vaddr is %p\n", __func__, ylog_buffer);
	snprintf(ylog_buffer, YLOG_BUF_SIZE, "%s", "This is ylog buffer. Now , it is nothing . ");
	/*here, we can add something to head to check if data is ok */
	SetPageReserved(virt_to_page(ylog_buffer));
	ret = misc_register(&misc_dev_ylog);
	return ret;
}
```

### 上层将log写入ylog buffer
```c++
//system/vendor/sprd/platform/system/logging/logd/YLogBuffer.cpp

unsigned char* YLogBuffer::getDeviceBuff(const char* path, long size) {
    int fd;
    unsigned char *pMap;

    fd = open(path, O_RDWR);
    int er = errno;
    static int fdError = 0;
    if (fd < 0) {
        if (fdError == 0) {
           fdError = 1;
            ALOGD("logd open %s  error:%s", path, strerror(er));
        }
        return NULL;
    }

    pMap = (unsigned char *) mmap(0, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (pMap == MAP_FAILED) {
        ALOGD("logd  mmap %s  error ", path);
        close(fd);
        return NULL;
    }
    close(fd);
    return pMap;
}

void YLogBuffer::write2RingBuffer(char* logmsg) {
    int len = strlen(logmsg);
    static unsigned char* pMem = NULL;
    static unsigned char* dst = NULL;
    if (NULL == pMem) {
        pMem = getDeviceBuff(LASTANDROID_DEVICE, LASTANDROID_BUF_SIZE);
        if (NULL != pMem) {
            memset(pMem, 0, LASTANDROID_BUF_SIZE);
        }
    }
    static int dataLength = 0;
    int *offset = (int*)pMem;

    if (pMem != NULL) {
        if ((4 + dataLength + len) < LASTANDROID_BUF_SIZE) {
            dst = pMem + 4 + dataLength;
            memcpy(dst, logmsg, len);
            dataLength += len;
        } else {
            memcpy(pMem + 4, logmsg, len);
            dataLength = len;
            dst = pMem + 4 + dataLength;
        }
        *offset = 4 + dataLength;
    }
}

void YLogBuffer::writeAndroidLog2Device(LogBufferElement* element) {
    static unsigned char logData[LOGGER_ENTRY_MAX_LEN];

    struct logger_entry* pLoggerEntry = (struct logger_entry*) logData;
    memset(pLoggerEntry, 0, sizeof (logData));

    pLoggerEntry->hdr_size = sizeof (struct logger_entry);
    pLoggerEntry->lid = element->log_id();
    pLoggerEntry->pid = element->pid();
    pLoggerEntry->tid = element->tid();
    pLoggerEntry->uid = element->uid();
    pLoggerEntry->sec = element->realtime().tv_sec;
    pLoggerEntry->nsec = element->realtime().tv_nsec;
    pLoggerEntry->len = element->msg_len();
    memcpy((char*) pLoggerEntry + pLoggerEntry->hdr_size, element->msg(), element->msg_len());

    AndroidLogEntry androidLogEntry;
    int ret = LogMsg2LogEntry((struct log_msg *) pLoggerEntry, &androidLogEntry);
    if (1 == ret) {
        outputLogEntry(&androidLogEntry);
    }
}

int YLogBuffer::log(log_id_t log_id, log_time realtime, pid_t pid, pid_t tid,
        const char *msg, unsigned short len) {
    LogBufferElement *element = new LogBufferElement(log_id, realtime, mLogUID++, pid, tid, 0, msg, len);

#if defined(DO_LOG_LASTANDROID)
    writeAndroidLog2Device(element);
#endif
    mLogcount++;
    delete element;
    return 0;
}

//调用Android的log服务写入到ylog
//system/system/logging/logd/LogListener.cpp 

void LogListener::HandleData() {
    ...
    logbuf_->Log(logId, header->realtime, cred->uid, cred->pid, header->tid, msg,
                 ((size_t)n <= UINT16_MAX) ? (uint16_t)n : UINT16_MAX);

    /**
     * Unisoc: Intrusive modification
     * write logs to ylog buffer
     * SR: SR.695.002431.007864
     * AR: AR.695.002431.007864.024911
     * method:hook interface
     * Unisoc Code @{
     */
    YLogBuffer::getInstance()->log(logId, header->realtime, cred->pid, header->tid, msg,
                ((size_t)n <= UINT16_MAX) ? (uint16_t)n : UINT16_MAX) ;
    /** @} */
}
```