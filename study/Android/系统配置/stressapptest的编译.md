# Google DDR和IO稳定性测试工具stressapptest的使用

## 编译stressapptest

对于aarch64-linux-android34-clang工具的交叉编译，默认使用的是src/stressapptest_config_android.h 配置头文件，需要在里面加上`#define STRESSAPPTEST_CPU_AARCH64` 指定编译CPU类型为arm64

`./configure --with-cpu=aarch64 CC=aarch64-linux-android34-clang CXX=aarch64-linux-android34-clang++ --host=linux CFLAGS=-static CXXFLAGS=-static
make
make install`

## stressapptest 的使用
Usage
To execute, a typical command would be:

```Shell
./stressapptest -s 20 -M 256 -m 8 -W    # Test 256MB, running 8 "warm copy" threads. Exit after 20 seconds.
./stressapptest --help                  # list the available arguments.
```

Common arguments

-M mbytes : megabytes of ram to test (auto-detect all memory available)
-s seconds : number of seconds to run (20)
-m threads : number of memory copy threads to run (auto-detect to number of CPUs)
-W : Use more CPU-stressful memory copy (false)
-n ipaddr : add a network thread connecting to system at 'ipaddr'. (none)
--listen : run a thread to listen for and respond to network threads. (0)
-f filename : add a disk thread with tempfile 'filename' (none)
-F : don't result check each transaction, use libc memcpy instead. (false)
Error handling

-l logfile : log output to file 'logfile' (none)
-v level : verbosity (0-20) (default: 8)

```Shell
./stressapptest -s 20 -M 256 -m 8 -C 8 -W # Allocate 256MB of memory and run 8 "warm copy" threads, and 8 cpu load threads. Exit after 20 seconds.
./stressapptest -f /tmp/file1 -f /tmp/file2 # Run 2 file IO threads, and autodetect memory size and core count to select allocated memory and memory copy threads.
```
