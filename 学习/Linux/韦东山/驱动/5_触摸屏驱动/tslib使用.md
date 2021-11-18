注：tslib的最新版本编译不通过，这里没有进行深究，直接使用韦老师提供的1.4版本。

## 编译和安装
安装需要的库和程序
```shell
sudo apt-get install autoconf
sudo apt-get install automake
sudo apt-get install libtool
```

编译
```shell
mkdir tmp
./autogen.sh
echo "ac_cv_func_malloc_0_nonnull=yes" >arm-linux.cache
./configure --host=arm-linux --cache-file=arm-linux.cache --prefix=$(pwd)/tmp
make
make install
```

安装
```shell
cd tmp
cp * -rf $(嵌入式系统根目录)
```

### 使用
1、首先安装ts驱动和lcd驱动
2、设置tslib
    修改 /etc/ts.conf第1行(去掉#号和第一个空格)：
    # module_raw input
    改为：
    module_raw input

3、设置环境变量
```shell
export TSLIB_TSDEVICE=/dev/event1
export TSLIB_CALIBFILE=/etc/pointercal
export TSLIB_CONFFILE=/etc/ts.conf
export TSLIB_PLUGINDIR=/lib/ts
export TSLIB_CONSOLEDEVICE=none
export TSLIB_FBDEVICE=/dev/fb0
```

4、校准
ts_calibrate

5、运行测试程序，可以画图，点击等
ts_test
