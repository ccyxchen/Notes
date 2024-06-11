# 设备unlock的方法

## 步骤

1、开发者模式中打开OEM unlock
2、执行 adb reboot bootloader 进入fastboot
3、执行 fastboot flashing unlock
长按音量上键
fastboot reboot
adb root
adb disable-verity
adb remount
