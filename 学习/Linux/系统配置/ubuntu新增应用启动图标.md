# 应用图标设置

接下来将以FileZille3作为例子

## 编写启动文件

vim ~/桌面/filezilla3.desktop
新增如下内容

```shell
[Desktop Entry]
# 版本，名字，功能等，只是说明信息
Version=3.58.0
Name=FileZilla3
GenericName=FTP client
GenericName[da]=FTP-klient
GenericName[de]=FTP-Client
GenericName[fr]=Client FTP
Comment=Download and upload files via FTP, FTPS and SFTP
Comment[da]=Download og upload filer via FTP, FTPS og SFTP
Comment[de]=Dateien über FTP, FTPS und SFTP übertragen
Comment[fr]=Transférer des fichiers via FTP, FTPS et SFTP
# 启动的命令，其实就是在终端执行该命令启动应用的
Exec=/home/ts/bin/FileZilla3/bin/filezilla
# 是否显示终端
Terminal=false
# 显示的图标名，需要把多个分辨率的图标文件放入/usr/share/icons/hicolor/目录下，如果只有一个图标，则放入/usr/share/pixmaps/目录下。
Icon=filezilla
# 启动类型
Type=Application
# 应用的功能分类
Categories=Network;FileTransfer;

# 新开窗口的执行项
[Desktop Action new-window]
Name=FileZilla3
Exec=/home/ts/bin/FileZilla3/bin/filezilla
```

## 设置为启动文件

1、右键该文件，选择允许启动。
2、添加到/usr/share/applications/目录下，执行
`sudo cp ~/桌面/filezilla3.desktop /usr/share/applications/`
这样以后可以双击桌面图标或在启动菜单执行。
