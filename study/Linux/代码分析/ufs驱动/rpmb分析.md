# rpmb分析

## UFS 驱动 RPMB 命令处理流程分析

内核中有**两条路径**：传统 RPMB（SCSI Security Protocol）和 UFS 4.0+ Advanced RPMB（BSG）。

---

### 一、初始化阶段

`ufshcd.c:9252-9281` 中的探测顺序：

```
ufshcd_scsi_add_wlus()   → 创建 RPMB WLUN SCSI 设备 (LUN=0xC4)
ufs_bsg_probe()          → 创建 /dev/ufs-bsgN 节点
scsi_scan_host()
ufs_rpmb_probe()         → 向 RPMB 子系统注册每个 region
```

- **RPMB WLUN 创建**：`ufshcd.c:8524-8534`，`__scsi_add_device()` 添加 `UFS_UPIU_RPMB_WLUN (0xC4)`，保存在 `hba->ufs_rpmb_wlun`。
- **描述符解析**：`ufshcd.c:5531-5557`，读取 RPMB Unit Descriptor，获得：
  - `b_advanced_rpmb_en`（`REGION_EN` bit4）
  - `rpmb_region_size[0..3]`（4 个 region 的容量，单位 128KB）
  - `rpmb_io_size`（Geometry Descriptor 的 `RPMB_RW_SIZE`，`ufshcd.c:9106`）
- **RPMB 子系统注册**：`ufs-rpmb.c:139-233`（`ufs_rpmb_probe`），对每个非零 region：
  - 创建 `ufs_rpmbN` 设备（bus=`ufs_rpmb`，parent=RPMB WLUN）
  - 调用 `rpmb_dev_register()` 注册到 RPMB class，`route_frames` 回调指向 `ufs_rpmb_route_frames`
  - 若设备已启用 Advanced RPMB（`b_advanced_rpmb_en`），则**跳过**此注册（`ufs-rpmb.c:148`）

---

### 二、传统 RPMB 路径（OP-TEE → SCSI Security Protocol）

典型调用方：OP-TEE（`drivers/tee/optee/rpc.c:396`）。

```
OP-TEE TA 需访问 RPMB
  │
  ▼
optee handle_rpc_func_rpmb_frames()        rpc.c:367
  │  rpmb_route_frames(rdev, req, ..., rsp, ...)
  ▼
rpmb_route_frames()                         rpmb-core.c:50
  │  rdev->descr.route_frames(parent_dev, ...)
  ▼
ufs_rpmb_route_frames()                     ufs-rpmb.c:55
  │
  ├─ 解析 req_resp（帧尾部 be16）：
  │    RPMB_PROGRAM_KEY / GET_WRITE_COUNTER / WRITE_DATA / READ_DATA
  │
  ├─ 组装 SPSP：region_id<<8 | 0x01        ufs-rpmb.c:102
  │
  ├─ ① ufs_sec_submit(send=true)            发送请求帧
  │     CDB[0]=SECURITY_PROTOCOL_OUT (0xB5)
  │     CDB[1]=0xEC (UFS application)
  │     CDB[2:3]=SPSP, CDB[6:9]=len
  │     scsi_execute_cmd(RPMB WLUN, cdb, REQ_OP_DRV_OUT, ...)
  │
  ├─ ② [若需结果读] 构造 RESULT_READ(0x5) 帧
  │     ufs_sec_submit(send=true) 再发一次
  │
  └─ ③ ufs_sec_submit(send=false)           读响应
        CDB[0]=SECURITY_PROTOCOL_IN (0xA2)
```

要点：
- **WRITE/PROGRAM_KEY 需要 Result Read**（`need_result_read=true`，`ufs-rpmb.c:110-120`）：写操作后设备将结果放入内部缓冲，需再发 `RESULT_READ` 请求；**READ/GET_COUNTER 不需要**。
- 最终经 SCSI midlayer → `ufshcd_queuecommand` → UPIU（CDB 方式）→ 设备。

---

### 三、Advanced RPMB 路径（UFS 4.0+，BSG 直通）

用户态通过 `/dev/ufs-bsgN` 以 `sg_io_v4` 发送 `UPIU_TRANSACTION_ARPMB_CMD`。

```
用户态 BSG 请求 (msgcode = UPIU_TRANSACTION_ARPMB_CMD = 0x20)
  │
  ▼
ufs_bsg_request()                           ufs_bsg.c:181
  │  ufshcd_rpm_get_sync()
  ▼
ufs_bsg_exec_advanced_rpmb_req()            ufs_bsg.c:61
  │
  ├─ 前置检查：UFS >= 4.0 && b_advanced_rpmb_en
  ├─ 校验 EHS：length==2, ehs_type==1
  ├─ 解析 req_resp_type（EHS meta 中）：
  │    WRITE_KEY/READ_CNT/PURGE_ENABLE → DMA_NONE
  │    WRITE/SEC_CONF_WRITE            → DMA_TO_DEVICE
  │    READ/SEC_CONF_READ/PURGE_STATUS → DMA_FROM_DEVICE
  ├─ dma_map_sg() 映射 payload
  │
  ▼
ufshcd_advanced_rpmb_req_handler()          ufshcd.c:7804
  │
  ├─ ufshcd_dev_man_lock()（持 dev_cmd.lock，串行化管理命令）
  ├─ ufshcd_get_dev_mgmt_cmd()：从 pseudo_sdev 取内部 scsi_cmnd
  ├─ ufshcd_setup_dev_cmd(DEV_CMD_TYPE_RPMB, UFS_UPIU_RPMB_WLUN, tag)
  ├─ ufshcd_prepare_req_desc_hdr(DMA_NONE, ehs=2)  // EHS 支持时 ehs=2
  ├─ 填充 UPIU：task_tag、拷贝用户 UPIU + EHS 到 UCD
  ├─ ufshcd_sgl_to_prdt()：SG → PRDT（有数据时）
  ├─ ufshcd_issue_dev_cmd() → blk_execute_rq() 同步等待
  │     超时 ADVANCED_RPMB_REQ_TIMEOUT = 3s
  │
  └─ 完成处理：
       ufshcd_dev_cmd_completion() 校验 UPIU_TRANSACTION_RESPONSE
       拷贝响应 UPIU + EHS（从 UCD byte32 起，EHS_OFFSET_IN_RESPONSE）
       返回 (response<<8)|status 作为 result
```

与传统路径的关键区别：
- 不走 SCSI CDB，而是**设备管理 UPIU + EHS** 携带 RPMB 元数据（nonce、write_counter、MAC 等，`scsi_bsg_ufs.h:171-186`）
- 数据 payload 通过 PRDT 直接传输，单次完成（无 Result Read 二次往返）
- 走 `dev_cmd` 管理命令通道，**全局互斥**

---

### 四、整体架构图

```
┌─────────────┐     ┌─────────────┐
│  OP-TEE TA  │     │ 用户态工具  │
│ (安全存储)  │     │ (sg_io_v4)  │
└──────┬──────┘     └──────┬──────┘
       │ RPC               │ BSG
       ▼                   ▼
┌──────────────┐   ┌───────────────────┐
│ rpmb-core    │   │ /dev/ufs-bsgN     │
│ (rpmb class) │   │ ufs_bsg_request   │
└──────┬───────┘   └─────────┬─────────┘
       │ route_frames        │ UPIU_TRANSACTION_ARPMB_CMD
       ▼                     ▼
┌─────────────────┐  ┌─────────────────────────────┐
│ ufs-rpmb.c      │  │ ufshcd_advanced_rpmb_req_   │
│ route_frames    │  │ handler (dev mgmt cmd)      │
│ → SECURITY_     │  │ → DEV_CMD_TYPE_RPMB UPIU    │
│   PROTOCOL IN/  │  │   + EHS + PRDT              │
│   OUT SCSI CDB  │  └──────────────┬──────────────┘
└────────┬────────┘                 │
         │ scsi_execute_cmd         │
         ▼                          ▼
┌────────────────────────────────────────────────┐
│           UFS HCD (ufshcd.c)                   │
│  queuecommand / send_command → UTP doorbell    │
└────────────────────┬───────────────────────────┘
                     ▼
              UFS 设备 RPMB LU (LUN 0xC4)
```

### 五、关键文件索引

| 文件 | 作用 |
|---|---|
| `drivers/ufs/core/ufs-rpmb.c` | 传统路径：RPMB 子系统注册 + frame 路由 |
| `drivers/ufs/core/ufs_bsg.c:61-127` | Advanced RPMB BSG 入口 |
| `drivers/ufs/core/ufshcd.c:7804-7881` | Advanced RPMB 底层 handler |
| `drivers/ufs/core/ufshcd.c:5531-5557` | RPMB 描述符解析 |
| `drivers/ufs/core/ufshcd.c:8510-8550` | RPMB WLUN SCSI 设备创建 |
| `include/uapi/scsi/scsi_bsg_ufs.h` | ARPMB 操作码、EHS/请求结构定义 |

---
