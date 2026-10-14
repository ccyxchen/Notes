# crash 加载/解析 vmcore 的核心代码与完整调用链

crash 本身是 gdb-based：它把 gdb 内嵌进来加载 vmlinux 符号表，而 vmcore 的物理内存读取则由 crash 自己的 dump 格式驱动完成。整个过程分三条线：**dump 格式识别 → ELF/note 解析 → 符号表 + 内核数据结构初始化**。

## 1. 入口 `main()` — `main.c:82`

```
main()
├─ setup_environment()
├─ getopt_long() 解析命令行选项
├─ display_version()
├─ while(argv[optind])            // main.c:437  内核/dumpfile 参数识别
│    ├─ is_ramdump() / is_netdump() / is_kdump() / is_kvmdump()
│    ├─ is_xendump() / is_diskdump() / is_lkcd_compressed_dump()
│    ├─ is_mclx_compressed_dump() / is_s390_dump() / is_sadump()
│    └─ is_vmware_vmss() / is_vmware_guestdump()
│        每个 is_*() 命中后设置 pc->flags 和 pc->readmem/writemem
│        （readmem 是此后读物理内存的真正函数指针）
├─ fd_init() buf_init() cmdline_init()
├─ mem_init()                     // memory.c:397  基本类型检查
├─ hq_init()
├─ machdep_init(PRE_SYMTAB)       // 架构相关初始化第 1 阶段
├─ symtab_init()                  // 符号表子系统初始化
├─ paravirt_init()
├─ machdep_init(PRE_GDB)
├─ datatype_init()
└─ gdb_main_loop(argc, argv)      // 进入 gdb，gdb 加载 vmlinux 后回调 main_loop()
```

## 2. 主循环 `main_loop()` — `main.c:745`

```
main_loop()
├─ 输出 dumpfile 损坏/不完整警告（ERASEINFO_DATA / INCOMPLETE_DUMP）
├─ if (!(pc->flags & GDB_INIT)):            // 首次进入
│    ├─ gdb_session_init()
│    ├─ machdep_init(POST_RELOC)
│    ├─ kdump_backup_region_init()
│    ├─ read_in_kernel_config(IKCFG_INIT)
│    ├─ kernel_init()          // kernel.c:171  读第一块内存，推导内核版本等
│    ├─ machdep_init(POST_GDB) // 此时解析 KASLR/地址布局（依赖 vmcoreinfo）
│    ├─ vm_init()              // memory.c:424  缓存常用结构体偏移
│    ├─ numa_init()
│    ├─ machdep_init(POST_VM)
│    ├─ module_init() task_init() vfs_init() net_init() dev_init()
│    └─ machdep_init(POST_INIT)
├─ display_sys_stats() / show_context()
└─ while(TRUE): process_command_line() + exec_command()
```

## 3. dump 格式识别（核心解析代码）

**ELF 系 (netdump/kdump/kvm/sadump…)** — `netdump.c`

- `is_netdump()` — `netdump.c:120`：读 ELF 头，校验 ELFMAG/class/endian/machine；靠 PT_LOAD 段的 `p_align` 是否为 0 和首段偏移区分 kdump 与 netdump。
- 识别后填充 `netdump_data nd`（`netdump.c:390-461`）：
  - `nd->num_pt_load_segments` = 物理内存段数
  - `dump_Elf64_Phdr(..., ELFSTORE+i)` 存每段 p_offset/p_paddr/p_memsz → `pt_load_segments[]`
  - `dump_Elf64_Nhdr()` (`netdump.c:2301`) / `dump_Elf32_Nhdr()` (`netdump.c:2065`) 遍历 PT_NOTE：NT_PRSTATUS（每 CPU 寄存器）、VMCOREINFO、QEMUCPUState、NT_VMCOREDD、XEN 各 note。
- `pc->read_vmcoreinfo = vmcoreinfo_read_string` (`netdump.c:466`)。
- `read_netdump()` — `netdump.c:761`：用 PT_LOAD 段做 paddr→文件 offset 映射读物理内存。`read_kdump()` — `netdump.c:4046` 是其 xen p2m 变体。

**makedumpfile 压缩系 (diskdump/compressed kdump)** — `diskdump.c`

- `is_diskdump()` — `diskdump.c:1061` → `open_dump_file()` (`diskdump.c:316`) → `read_dump_header()` (`diskdump.c:604`)：
  - 校验 `DISK_DUMP_SIGNATURE` 或 `KDUMP_SIGNATURE`
  - 读 `block_size`、`nr_cpus`、子头（kdump 子头含 `phys_base`/`size_note`）、内存页 bitmap（`dd->valid_pages`）
  - `dd->sub_header_kdump->size_note` 触发 `machdep->process_elf_notes()` (`diskdump.c:890-932`) 解析 ELF note
- 分配 page cache、初始化 lzo/snappy/zstd。
- `read_diskdump()` — `diskdump.c:1404`：bitmap + 页缓存 + 解压读内存。

**其他格式**：`is_kvmdump()`(`kvmdump.c:39`)、`is_xendump()`(`xendump.c:63`)、`is_sadump()`(`sadump.c:667`)、`is_vmware_vmss/guestdump()`、`is_ramdump()`(`ramdump.c:245`) 各自有对等的 read 函数。

## 4. ELF note 解析

`machdep->process_elf_notes` 在架构 `_init()` 里注册：
- `process_elf64_notes()` / `process_elf32_notes()` — `diskdump.c:334/395`（通用，逐 note 存 `dd->nt_prstatus_percpu[]`）
- `x86_process_elf_notes()` — `diskdump.c:463`（x86/x86_64 专用）
- `s390x_process_elf_notes()` — `s390x.c:441`（s390x 用 `machdep->dumpfile_init` 存 note）

## 5. vmcoreinfo 解析

`vmcoreinfo_read_string()` — `netdump.c:1926`：在 VMCOREINFO note 字符串里找 `OSRELEASE`/`BUILD-ID`/`NUMBER(x)`/`SYMBOL(x)`/`SIZE(x)` 等 key，填充 `kt->vmcoreinfo`。架构 init 里大量调用 `pc->read_vmcoreinfo("NUMBER(phys_base)")` 等（如 `x86_64.c:7291`、`arm64.c:843 arm64_get_vmcoreinfo()`）。

## 6. 架构相关初始化

`machdep_init(X)` 是宏（`defs.h:5551`），映射到 `x86_64_init()`/`arm64_init()`/…。各阶段（`defs.h:1152` 的 `PRE_SYMTAB/PRE_GDB/POST_GDB/POST_VM/POST_INIT/POST_RELOC`）逐步推导 KASLR 偏移、内核虚拟/物理地址布局、页大小等。

**关键文件**：`main.c`（入口/主循环）、`netdump.c`（ELF 解析+读内存）、`diskdump.c`（makedumpfile 头+bitmap+读内存）、`memory.c`（`mem_init`/`vm_init`）、`kernel.c`（`kernel_init`）、`symbols.c`/`symtab_init`（符号表）、各架构 `x86_64.c`/`arm64.c` 等。


16. Assistant

I now have a complete and accurate picture. Let me write a comprehensive answer. The user asked in Chinese, so I'll answer in Chinese.

Let me structure the answer:

1. 总体架构：crash 是 gdb-based。vmcore 加载解析分三大部分：dump 格式识别、ELF/note 解析、符号表(vmlinux)+内核数据结构初始化。
  
2. 核心入口 `main()` (main.c:82)
  
3. 完整调用链
  
4. 核心代码文件及函数
