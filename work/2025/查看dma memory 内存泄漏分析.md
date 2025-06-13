# 查看dma memory 内存泄漏分析
 之前x6531c上的egl track内存泄漏的原因找到了么，
今天在lamu go上看到一个应用起不来的，bugreport里有dma buffer相关的统计
------ Dmabuf dump (dmabuf_dump) 
这里看surfaceflinger里有比较多的4M大小的
 surfaceflinger:828  
                  Name              Rss              Pss         nr_procs            Inode
    FramebufferSurface          4512 kB          2256 kB                2                1
    FramebufferSurface          4512 kB          2256 kB                2                2
    FramebufferSurface          4512 kB          2256 kB                2                3
               Gralloc          1604 kB           802 kB                2            94221
               Gralloc          4512 kB          4512 kB                1            97683
               Gralloc          4512 kB          4512 kB                1           130642
               Gralloc          4512 kB          4512 kB                1           136996
         PROCESS TOTAL        508116 kB        497347 kB      


@李帅(Shuai1 Li)    找到了，systemui内存泄漏导致的，优化了就正常了

@李帅(Shuai1 Li)  
adb shell cat /proc/dma_heap/all_heaps   
看下整体进程 inode占用异常 


@李帅(Shuai1 Li)    有，每个进程占用多少都能大概看出来。类似这样
![](vx_images/221105806123039.png =1145x)



@周强(Qiang Zhou)  oomkill触发不一定会直接导致异常，oom kill有没有触发，可以在跑过测试的机器上抓bugreport看，或者直接
cat /proc/vmstat |grep --color -iE "oom_kill"
oom_kill 0

@李帅(Shuai1 Li)  
知道哪个进程内存异常时，adb shell am dumpheap pid 看内存快照，检查GCroot链，同时使用的看正常情况是不是这样，如果正常情况就是这样大小，那么就没有问题

