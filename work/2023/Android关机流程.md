# 关机流程

![Alt text](../../tmpimage/image-1.png)
Android的init 程序执行时不带参数，此时跑到FirstStageMain
在FirstStageMain最后会再次执行init，传入参数selinux_setup,这时会执行到SetupSelinux函数
![Alt text](../../tmpimage/image-2.png)
SetupSelinux  函数最后就会执行SecondStageMain 函数
![Alt text](../../tmpimage/image-3.png)
SecondStageMain 函数有一个死循环会不停监控系统是否接收到shutdown命令，如果有就去执行关机流程。
![Alt text](../../tmpimage/image-4.png)
![Alt text](../../tmpimage/image-5.png)
