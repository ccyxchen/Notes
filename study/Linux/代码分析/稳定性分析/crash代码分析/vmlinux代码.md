# vmlinux代码

以下是 crash 加载和解析 vmcore 的核心代码及完整调用链：

## 核心调用链

```
main() [main.c:87]
  └─ setup_environment() [main.c:1110]
       └─ process_command_line() [cmdline.c]  ← 解析 vmcore 文件参数
  └─ get_osrelease() [main.c:1958]
       └─ memory_source_init() [filesys.c:164]  ← 确定 dump 格式并调用对应 init
            ├─ netdump_init() [netdump.c:744]
            ├─ kdump_init() [netdump.c:4034]
            ├─ xendump_init() [xendump.c:814]
            ├─ kvmdump_init() [kvmdump.c:84]
            ├─ diskdump_init() [diskdump.c:1119]
            ├─ lkcd_dump_init() [lkcd_*.c]
            ├─ s390_dump_init() [s390.c]
            └─ vmware_vmss_init() / vmware_guestdump_init() [vmware_*.c]
```

## 关键函数

| 函数 | 文件:行号 | 作用 |
|------|-----------|------|
| `memory_source_init()` | filesys.c:164 | 根据 `pc->flags` 判断 dump 格式，调用对应 `*_init()` |
| `diskdump_init()` | diskdump.c:1119 | 验证 diskdump/kdump 格式，设置 `pc->readmem = read_diskdump` |
| `netdump_init()` | netdump.c:744 | 解析 netdump 头部，设置 `pc->readmem` |
| `read_diskdump()` | diskdump.c:1404 | 实际读取页面的核心函数（page cache + pread） |
| `generic_read_dumpfile()` | memory.c:3181 | 所有 dump 格式读取的底层入口 |

## 核心机制

1. **格式识别**：`memory_source_init()` 通过 `pc->flags` 中的 `DISKDUMP`/`NETDUMP`/`KDUMP` 等标志判断格式
2. **函数指针绑定**：各 `*_init()` 函数设置 `pc->readmem` 指向具体读取函数（如 `read_diskdump`）
3. **页面读取**：`read_diskdump()` 使用 page cache 缓存机制，通过 `pread()` 从 dumpfile 读取物理页面
4. **vmcoreinfo 解析**：`pc->read_vmcoreinfo` 指向 `vmcoreinfo_read_string()`，解析 vmcore 中的 OSRELEASE、PAGESIZE 等信息
