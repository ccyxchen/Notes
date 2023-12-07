# WSL构建erofs 文件系统

## 编译erofs_tools和LZ4

这里下载相应源码并根据README编译安装即可。

## 生成erofs文件系统镜像并挂载

WSL 内核默认打开EROFS文件系统，可直接挂载，无需修改内核。

```Shell
# 将filesystem制作成erofs镜像，使用lz4算法压缩
mkfs.erofs -zlz4 erofs_test.img /home/chenyx/workspace/opensource/filesystem
# 挂载erofs镜像
sudo mount -t erofs erofs_test.img /home/chenyx/erofs_mount/
```

可以看到已经成功挂载镜像到erofs_mount，并且该分区是只读的。

![测试erofs系统](/tmpimage/20221120223943.png)
