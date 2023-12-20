# dump 获取行号

## linux 的一个实例

下面是一段使用dump_stack();函数打印的堆栈信息：

```txt
11-25 03:44:51.363550  1305  1305 E .(6)[1305:android.hardwar]blkcg_ioprio_track ccccccccccc: pid: 1305, ioprio: 0, tgid = 1305
11-25 03:44:51.364774  1305  1305 W -(6)[1305:android.hardwar]CPU: 6 PID: 1305 Comm: android.hardwar Tainted: P S      W  O      4.19.191-g44c68f9df25f-dirty #4
11-25 03:44:51.366343  1305  1305 W -(6)[1305:android.hardwar]Hardware name: MT8786V/N (DT)
11-25 03:44:51.367162  1305  1305 W -(6)[1305:android.hardwar]Call trace: 
11-25 03:44:51.367793  1305  1305 W         : -(6)[1305:android.hardwar] dump_backtrace+0x0/0x18c
11-25 03:44:51.367799  1305  1305 W         : -(6)[1305:android.hardwar] show_stack+0x14/0x1c
11-25 03:44:51.369307  1305  1305 W         : -(6)[1305:android.hardwar] dump_stack+0xb8/0xf0
11-25 03:44:51.370041  1305  1305 W         : -(6)[1305:android.hardwar] blkcg_ioprio_track+0xa4/0xd0
11-25 03:44:51.370862  1305  1305 W         : -(6)[1305:android.hardwar] rq_qos_track+0x48/0x5c
11-25 03:44:51.371618  1305  1305 W         : -(6)[1305:android.hardwar] blk_mq_make_request+0x1b8/0x614
11-25 03:44:51.372471  1305  1305 W         : -(6)[1305:android.hardwar] generic_make_request+0x22c/0x38c
11-25 03:44:51.373333  1305  1305 W         : -(6)[1305:android.hardwar] submit_bio+0x60/0x224
11-25 03:44:51.373730   233   233 D .(1)[233:disp_idlemgr][DISP]dl_to_dc capture: Flush wait wdma sof
11-25 03:44:51.374079  1305  1305 W         : -(6)[1305:android.hardwar] ext4_submit_bio_read+0x14c/0x1c4
11-25 03:44:51.374083  1305  1305 W         : -(6)[1305:android.hardwar] ext4_mpage_readpages+0x7b4/0x7f4
11-25 03:44:51.375806  1305  1305 W         : -(6)[1305:android.hardwar] ext4_readpages+0x3c/0x44
11-25 03:44:51.376582  1305  1305 W         : -(6)[1305:android.hardwar] read_pages+0x64/0x148
11-25 03:44:51.377326  1305  1305 W         : -(6)[1305:android.hardwar] __do_page_cache_readahead+0x164/0x1c4
11-25 03:44:51.378242  1305  1305 W         : -(6)[1305:android.hardwar] filemap_fault+0x2f0/0x694
11-25 03:44:51.379030  1305  1305 W         : -(6)[1305:android.hardwar] ext4_filemap_fault+0x30/0x4c
11-25 03:44:51.379850  1305  1305 W         : -(6)[1305:android.hardwar] __do_fault+0x7c/0xe8
11-25 03:44:51.380583  1305  1305 W         : -(6)[1305:android.hardwar] handle_pte_fault+0x8b4/0xc10
11-25 03:44:51.381402  1305  1305 W         : -(6)[1305:android.hardwar] handle_mm_fault+0x1d8/0x2bc
11-25 03:44:51.382211  1305  1305 W         : -(6)[1305:android.hardwar] do_page_fault+0x2c8/0x4e0
11-25 03:44:51.382998  1305  1305 W         : -(6)[1305:android.hardwar] do_translation_fault+0x2c/0x40
11-25 03:44:51.383839  1305  1305 W         : -(6)[1305:android.hardwar] do_mem_abort+0x4c/0xf8
11-25 03:44:51.384594  1305  1305 W         : -(6)[1305:android.hardwar] el0_da+0x1c/0x20
```

可以看到每个函数名后都会跟着2个十六进制值
以submit_bio为例：
submit_bio+0x60/0x224

第一个十六进制0x60表示下一个要调用的函数（generic_make_request+0x22c/0x38c）相对当前函数在内存起始地址的偏移值。

在编译linux时，编译器加上-g参数可以生成vmlinux符号表文件，使用 objdump 工具可以对其反汇编，加上-l参数会打印出对应的代码行号

`prebuilts/clang/host/linux-x86/clang-r416183b1/bin/llvm-objdump -d -l out/target/product/t402aa/obj/KERNEL_OBJ/vmlinux > out`

比如解析出来的submit_bio定义如下：

```asm
ffffff8008493034 <submit_bio>:
; submit_bio():
; /home/android/disk1/yuxian.chen/workspace/T402_U/vendor/vendor/kernel-4.19/block/blk-core.c:2551
ffffff8008493034: ff 03 02 d1   sub sp, sp, #128
...
; /home/android/disk1/yuxian.chen/workspace/T402_U/vendor/vendor/kernel-4.19/block/blk-core.c:2596
ffffff800849308c: e0 03 13 aa   mov x0, x19
ffffff8008493090: 95 fd ff 97   bl 0xffffff80084926e4 <generic_make_request>
ffffff8008493094: f3 03 00 2a   mov w19, w0
ffffff8008493098: 49 8f 00 d0   adrp x9, 0xffffff800967d000 <queue_wb_lat_store+0xe0>
ffffff800849309c: a8 83 5f f8   ldur x8, [x29, #-8]
ffffff80084930a0: 29 85 45 f9   ldr x9, [x9, #2824]
ffffff80084930a4: 3f 01 08 eb   cmp x9, x8
ffffff80084930a8: 61 0d 00 54   b.ne 0xffffff8008493254 <submit_bio+0x220>
; /home/android/disk1/yuxian.chen/workspace/T402_U/vendor/vendor/kernel-4.19/block/blk-core.c:2601
ffffff80084930ac: e0 03 13 2a   mov w0, w19
ffffff80084930b0: f4 4f 47 a9   ldp x20, x19, [sp, #112]
ffffff80084930b4: f6 57 46 a9   ldp x22, x21, [sp, #96]
ffffff80084930b8: f8 5f 45 a9   ldp x24, x23, [sp, #80]
ffffff80084930bc: f9 23 40 f9   ldr x25, [sp, #64]
ffffff80084930c0: fd 7b 43 a9   ldp x29, x30, [sp, #48]
ffffff80084930c4: ff 03 02 91   add sp, sp, #128
ffffff80084930c8: c0 03 5f d6   ret
...

ffffff8008493258 <blk_poll>:
; blk_poll():
; /home/android/disk1/yuxian.chen/workspace/T402_U/vendor/vendor/kernel-4.19/block/blk-core.c:2606
ffffff8008493258: fd 7b be a9   stp x29, x30, [sp, #-32]!
ffffff800849325c: f4 4f 01 a9   stp x20, x19, [sp, #16]

...
ffffff80084926e4 <generic_make_request>:
; generic_make_request():
; /home/android/disk1/yuxian.chen/workspace/T402_U/vendor/vendor/kernel-4.19/block/blk-core.c:2389
ffffff80084926e4: ff c3 01 d1   sub     sp, sp, #112

...
```

submit_bio 的地址为0xffffff8008493034,加0x60后为0xffffff8008493094，该值的前一个地址正好是调用generic_make_request的语句，从这里可以快速定位函数调用关系。
0xffffff8008493034,加0x224为0xffffff8008493258，该值是在内存中submit_bio
的下一个存放的函数的起始地址。
