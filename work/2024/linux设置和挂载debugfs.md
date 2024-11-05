# 设置挂载debugfs

## 设置debugfs

在defconfig中打开 

```makefile
CONFIG_BLK_DEBUG_FS=y 
CONFIG_DEBUG_FS_ALLOW_ALL=y 
CONFIG_DEBUG_FS=y
```

## 挂载debugfs

`mount -t debugfs none /sys/kernel/debug/`

所有debug信息都在/sys/kernel/debug/路径中。
