# 展锐CPU&DDR调试方法
1、压测内存翻转
stressapptest_64bit -M 4000 -m 2 -i 2 -C 1 -W -s 43200 -l /data/test.log

 adb shell "nohup stressapptest_64bit -M 4000 -m 2 -i 2 -C 1 -W -s 43200 -l /data/test.log > /data/outlog &"

关闭DVFS
    adb reboot bootloader，进入fastboot模式
    fastboot oem dvfs_set dvfs disable       //注意观察是否有okay
    fastboot reboot，重启开机后生效
    测试结束后
    fastboot oem dvfs_set erase all

开6核
fastboot oem startup_core 6



