# 内核trace 使用
@杨霁(Ji Yang)  帮忙开下Lamu Kernel下面的宏，帮我编个userdebug的Kernel
CONFIG_BLK_DEV_IO_TRACE=y
CONFIG_HAVE_FUNCTION_GRAPH_TRACER=y
CONFIG_HAVE_FUNCTION_GRAPH_RETVAL=y
CONFIG_FUNCTION_TRACER=Y
CONFIG_FUNCTION_GRAPH_TRACER=y
CONFIG_FUNCTION_GRAPH_RETVAL=y
CONFIG_STACK_TRACER=y

adb root
adb shell
#验证相关的trace选项打开
gunzip -c /proc/config.gz|grep --color -iE "CONFIG_BLK_DEV_IO_TRACE|CONFIG_HAVE_FUNCTION_GRAPH_TRACER|CONFIG_HAVE_FUNCTION_GRAPH_RETVAL|CONFIG_FUNCTION_TRACER|CONFIG_FUNCTION_GRAPH_TRACER|CONFIG_FUNCTION_GRAPH_RETVAL|CONFIG_STACK_TRACER"

拿submit_bio ，bio_set_ioprio，blkcg_set_ioprio的记录
echo 0 > /sys/kernel/tracing/tracing_on;echo 1 > /sys/kernel/tracing/options/funcgraph-retval;echo function_graph > /sys/kernel/tracing/current_tracer;echo submit_bio > /sys/kernel/tracing/set_graph_function;echo bio_set_ioprio >> /sys/kernel/tracing/set_graph_function;echo blkcg_set_ioprio >> /sys/kernel/tracing/set_graph_function;echo 1 > /sys/kernel/tracing/tracing_on;cat /sys/kernel/tracing/trace >/sdcard/submit_io_ftrace.txt

adb pull /sdcard/submit_io_ftrace.txt


 @陈育贤(Yuxian Chen)  @杨霁(Ji Yang) 这个CONFIG_BLK_DEV_IO_TRACE开了之后可以用
 blktrace -d /dev/block/mmcblk0p52 -o -|blkparse -i -
来跟踪存储，ioprio相关的我还在查怎么看

