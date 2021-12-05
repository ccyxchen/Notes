## freetype简介
freetype是用来显示矢量字体的图形库，它有字体缩放，旋转， 调整字体边距，居中显示，自动换行等常用功能，很适合嵌入式UI中的字体显示，具体的使用说明可以下载 freetype-doc-2.11.0.tar.gz并查看里面的`FreeType Tutorial`章节，里面有freetype的基本应用和控制字距，居中显示等高级功能。

## freetype的交叉编译
### 1、将freetype安装到交叉编译工具链
参考`docs/INSTALL.CROSS`
```Shell
# 配置交叉编译器，安装路径等，因为arm-gcc的库文件路径和头文件路径不规范，这里选择先安装到临时目录再手动复制
# 配置交叉编译器为arm-linux-gcc，build的选项只是说明编译系统的信息，不重要
./configure \
          --build=x86_64-unknown-linux \
          --host=arm-linux
# 编译
make -j4

# 安装到tmp临时目录
mkdir tmp
make DESTDIR=/home/cyx/workspace/open/freetype/freetype/tmp/ install

# 拷贝库和头文件到交叉编译器
cd tmp
cp -r usr/local/include/freetype2/* /home/cyx/workspace/Tools/arm-linux-gcc-4.3.2/arm-none-linux-gnueabi/libc/usr/include/
cp -r usr/local/lib/* /home/cyx/workspace/Tools/arm-linux-gcc-4.3.2/arm-none-linux-gnueabi/libc/armv4t/lib/
cp -r usr/local/share/* /home/cyx/workspace/Tools/arm-linux-gcc-4.3.2/arm-none-linux-gnueabi/libc/armv4t/usr/share
```
### 2、将库文件复制到跟文件系统
```Shell
# 拷贝库文件到根文件系统
cp -r ~/workspace/open/freetype/freetype/tmp/usr/local/lib/* ~/workspace/nfs_root/busybox_1.21/lib/
```

### 3、交叉编译应用程序
```Shell
cd ~/workspace/third/camerabook/2_freetype/4th_center
arm-linux-gcc showtype_4.c -lm -lfreetype -o showtype_4
```
注意：freetype的文档中需要指定头文件路径是因为其安装的头文件放在freetype2目录里，而这个路径不是系统默认的头文件目录。

## 其他使用参考freetype-doc-2.11.0.tar.gz，里面有非常详细的说明和实例代码
