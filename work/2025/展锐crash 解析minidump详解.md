# crash 中解析 minidump 字段

## sysdump 驱动详解

## crash 解析sysdump

* 加载KO
  mod -s sysdump /mnt/e/banben/AE808A_15.0_MINI_userdebug_202505271719_ODM_SYMBOLS/home/android/work/code/AE808A_V_Drv_FTM/vendor/bsp/out/androidt/m2518_native/dist/modules/symbols/sysdump.ko

* 加载脚本自动执行
  本地编写脚本crash_sh,执行crash时加上 -i crash_sh参数，就会自动执行里面的命令，可以方便的进行批处理和解析

* 打印全局变量地址
