# 通过读取分区确认

下载是否完整可以通过回读flashinfo分区中的dl_info信息判断。这个昨晚波哥@何建波(James He)  提出来的，这边验证可行，如果后面有dm-verity问题，第一时间可以回读该分区内容判断下载是否完整。
回读的分区地址如下：【flashinfo分区中dl_info保存了下载状态的信息】
Start address:0x747ff8000
Length:0x2000
Region：EMMC_USER
回读的内容有DL_CK_DONE则说明下载完成，并下载正确，如下图是下载完整的，如果下载不完整不会有DL_CK_DONE。

![1](/tmpimage/MTK%20判断下载是否完成2024-03-02-10-59-31.png)
