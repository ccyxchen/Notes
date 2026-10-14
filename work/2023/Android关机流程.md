# 关机流程

- /system/core/init/main.cpp

<img src="vx_assets/e2c3477a-19a7-4435-af86-fa251921e24b/d420.png" width="900" />

Android的init 程序执行时不带参数，此时跑到FirstStageMain
在FirstStageMain最后会再次执行init，传入参数selinux_setup,这时会执行到SetupSelinux函数

<img src="vx_assets/e2c3477a-19a7-4435-af86-fa251921e24b/e248.png" width="900" />

SetupSelinux  函数最后就会执行SecondStageMain 函数

<img src="vx_assets/e2c3477a-19a7-4435-af86-fa251921e24b/db9d.png" width="900" />

SecondStageMain 函数有一个死循环会不停监控系统是否接收到shutdown命令，如果有就去执行关机流程。

<img src="vx_assets/e2c3477a-19a7-4435-af86-fa251921e24b/6958.png" width="900" />
