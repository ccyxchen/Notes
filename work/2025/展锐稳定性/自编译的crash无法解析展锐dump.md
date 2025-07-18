# 自编译的crash无法解析展锐dump
## ubuntu编译ARM64的crash

make target=ARM64 -j32
会下载最新的gdb-16.2.tar.gz源码，并编译生成crash。

## 展锐dump解析报错
使用的解析命令：  
` ~/workspace/crash/crash -m vabits_actual=39 -m phys_offset=0x80000000 -m kimage_voffset=0xffffffbf88000000 vmcore@0x80000000 vmlinux --kaslr 0x80000`

会报下面的错误：

```txt
crash: invalid structure size: note_buf
       FILE: arm64.c  LINE: 4863  FUNCTION: arm64_get_crash_notes()

[/home/cyx/workspace/crash/crash] error trace: 55cb14a31723 => 55cb14af3c41 => 55cb14b1817b => 55cb14b180ed
```

可以看到报错的具体代码行

```C
4789 /*
4790  * Retrieve task registers for the time of the crash.
4791  */
4792 static void
4793 arm64_get_crash_notes(void)
4794 {
4863         buf = GETBUF(SIZE(note_buf));

#define SIZE(X)            (SIZE_verify(size_table.X, (char *)__FUNCTION__, __FILE__, __LINE__, #X))

long
SIZE_verify(long size, char *func, char *file, int line, char *item)
{
	char errmsg[BUFSIZE];

        if (!(pc->flags & DATADEBUG))
                return size;

        if (size < 0) {
		void *retaddr[NUMBER_STACKFRAMES] = { 0 };
		SAVE_RETURN_ADDRESS(retaddr);
		sprintf(errmsg, "invalid structure size: %s", item);
                datatype_error(retaddr, errmsg, func, file, line);
        }
        return size;
}

//从这里可以看到是size_table.note_buf的值小于0

//size_table.note_buf的初始化
/*
 *  Gather and verify all of the backtrace requirements.
 */
static void
arm64_stackframe_init(void)
{
        	STRUCT_SIZE_INIT(note_buf, "note_buf_t");
}

#define STRUCT_SIZE_INIT(X, Y) (ASSIGN_SIZE(X) = STRUCT_SIZE(Y))

#define STRUCT_SIZE(X)      datatype_info((X), NULL, STRUCT_SIZE_REQUEST)
#define ASSIGN_SIZE(X)     (size_table.X)

/*
 *  This function is called through the following macros:
 *
 *   #define STRUCT_SIZE(X)      datatype_info((X), NULL, NULL)
 *   #define UNION_SIZE(X)       datatype_info((X), NULL, NULL)
 *   #define DATATYPE_SIZE(X)    datatype_info((X)->name, NULL, (X))
 *   #define MEMBER_OFFSET(X,Y)  datatype_info((X), (Y), NULL)
 *   #define STRUCT_EXISTS(X)    (datatype_info((X), NULL, NULL) >= 0)
 *   #define MEMBER_EXISTS(X,Y)  (datatype_info((X), (Y), NULL) >= 0)
 *   #define MEMBER_SIZE(X,Y)    datatype_info((X), (Y), MEMBER_SIZE_REQUEST)
 *   #define MEMBER_TYPE(X,Y)    datatype_info((X), (Y), MEMBER_TYPE_REQUEST)
 *   #define MEMBER_TYPE_NAME(X,Y)      datatype_info((X), (Y), MEMBER_TYPE_NAME_REQUEST)
 *   #define ANON_MEMBER_OFFSET(X,Y)    datatype_info((X), (Y), ANON_MEMBER_OFFSET_REQUEST)
 *
 *  to determine structure or union sizes, or member offsets.
 */
long
datatype_info(char *name, char *member, struct datatype_member *dm)
```
从代码中可以看到是获取note_buf_t类型的值返回了小于0的值，推测是工具无法从dump中解析
到note_buf_t类型，下面需要看下展锐代码note_buf_t是在哪里定义的。

在默认的kernel代码中，note_buf_t是在kexec_core驱动中定义的，kexec_core是kernel原生的
生成kdump的驱动，展锐没有使用该驱动。
展锐使用的是unisoc_sysdump.c驱动，该驱动被编译成模块，所以在只加载VMLINUX时是找不
到这个符号的，需要同时加载sysdump.ko。或者修改crash源码，使其不会解析note_buf_t。

当我们不使用kexec_core时，dump中应该不会有note_buf_t的符号，而该类型定义了crash_notes
note_buf_t __percpu *crash_notes;

在crash 代码上会先判断crash_notes符号存在，才会执行到
`buf = GETBUF(SIZE(note_buf));`
问题是crash_notes是全局变量，在dump上能被找到，但是它是在KO中定义的，只加载
VMLINXU无法得到note_buf_t的类型定义。

### 解决办法
1、修改crash 源码。使其判断crash_notes 不存在。

```diff
diff --git a/arm64.c b/arm64.c
index 608b19d..6dc2e0d 100644
--- a/arm64.c
+++ b/arm64.c
@@ -4800,7 +4800,7 @@ arm64_get_crash_notes(void)
        ulong *notes_ptrs;
        ulong i, found;

-       if (!symbol_exists("crash_notes")) {
+       if (symbol_exists("crash_notes")) {
                if (DISKDUMP_DUMPFILE() || KDUMP_DUMPFILE()) {
                        if (!(ms->panic_task_regs = calloc((size_t)kt->cpus, sizeof(struct arm64_pt_regs))))
                                error(FATAL, "cannot calloc panic_task_regs space\n");
```

通过修改crash_notes存在时走不存在的代码，规避问题。

2、crash同时加载VMLINUX和ko
crash 工具目前没有这个功能


