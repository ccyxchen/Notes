# (125条消息) 使用CMake交叉编译Arm Linux程序_whahu1989的专栏-CSDN博客_cmake 交叉编译

我们平常使用CMake时，主要是在x86或x86_64平台上，其实CMake在2.6版本后就已经支持交叉编译了，下面就来看下如何使用CMake进行Arm [Linux](https://so.csdn.net/so/search?from=pc_blog_highlight&q=Linux)程序的交叉编译。

## 一 建立工程

按照如下结构体建立一个简单工程

![在这里插入图片描述](img/(125%E6%9D%A1%E6%B6%88%E6%81%AF)%20%E4%BD%BF%E7%94%A8CMake%E4%BA%A4%E5%8F%89%E7%BC%96%E8%AF%91Arm%20Linux%E7%A8%8B%E5%BA%8F_whahu1989%E7%9A%84%E4%B8%93%E6%A0%8F-CSDN%E5%8D%9A%E5%AE%A2_cmake%20%E4%BA%A4%E5%8F%89%E7%BC%96%E8%AF%91-01.jpg)

main.c内容如下，

```c
#include <stdio.h>

int main(void)
{
    printf("hello world\n");

    return 0;
}
```

CMakeLists.txt内容如下，

```c
cmake_minimum_required(VERSION 3.5)

project(demo)

add_executable(main main.c)
```

这是常规的工程，编译的话只要cd到build目录下执行`cmake .. && make`就可以了。

## 二 交叉编译

现在希望最终编译的程序是运行在arm linux系统上的，这就需要交叉编译。

#### 1. 设置系统和工具链

对于交叉编译，CMake并不知道目标系统是什么，所以需要设置一些CMake变量来告知CMake，

- CMAKE_SYSTEM_NAME：即目标系统名，这里是Linux
- CMAKE_SYSTEM_PROCESSOR ：目标系统的处理器名，这里是arm

对于工具链，则是通过下面2个变量来定位，

- CMAKE_C_COMPILER：C编译器的可执行文件名称
- CMAKE_CXX_COMPILER：C++编译器的可执行文件名称

这些变量可以在调用CMake时通过命令行传递，但是这种做法容易出错，而且用起来不方便，所以CMake提供了工具链文件的方式来传递这些变量信息。

#### 2. 工具链文件

我们在工程里新建一个文件叫arm_linux_setup.cmake，放置位置如下（也可以放在别的地方），

![在这里插入图片描述](img/(125%E6%9D%A1%E6%B6%88%E6%81%AF)%20%E4%BD%BF%E7%94%A8CMake%E4%BA%A4%E5%8F%89%E7%BC%96%E8%AF%91Arm%20Linux%E7%A8%8B%E5%BA%8F_whahu1989%E7%9A%84%E4%B8%93%E6%A0%8F-CSDN%E5%8D%9A%E5%AE%A2_cmake%20%E4%BA%A4%E5%8F%89%E7%BC%96%E8%AF%91-02.jpg)

其内容如下，

```c
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(tools /home/wh/work/cross_compile/gcc-linaro-7.3.1-2018.05-x86_64_arm-linux-gnueabihf)
set(CMAKE_C_COMPILER ${tools}/bin/arm-linux-gnueabihf-gcc)
set(CMAKE_CXX_COMPILER ${tools}/bin/arm-linux-gnueabihf-g++)
```

tools是本人使用的交叉工具链路径，可以根据自己的实际文件来做修改。

#### 3. 编译

使用CMake的变量CMAKE_TOOLCHAIN_FILE来指定工具链文件，cd到build目录，然后执行下面的命令，

```c
// 注意，工具链文件的指定一定要紧跟cmake命令之后，不能放到 .. 后面
cmake -DCMAKE_TOOLCHAIN_FILE=../arm_linux_setup.cmake ..
```

ok后再执行make，就可以生成main的elf文件，

![在这里插入图片描述](img/(125%E6%9D%A1%E6%B6%88%E6%81%AF)%20%E4%BD%BF%E7%94%A8CMake%E4%BA%A4%E5%8F%89%E7%BC%96%E8%AF%91Arm%20Linux%E7%A8%8B%E5%BA%8F_whahu1989%E7%9A%84%E4%B8%93%E6%A0%8F-CSDN%E5%8D%9A%E5%AE%A2_cmake%20%E4%BA%A4%E5%8F%89%E7%BC%96%E8%AF%91-03.jpg)

使用file命令去查看这个文件，可以看到其运行平台是32位ARM处理器上的Linux系统，

![在这里插入图片描述](img/(125%E6%9D%A1%E6%B6%88%E6%81%AF)%20%E4%BD%BF%E7%94%A8CMake%E4%BA%A4%E5%8F%89%E7%BC%96%E8%AF%91Arm%20Linux%E7%A8%8B%E5%BA%8F_whahu1989%E7%9A%84%E4%B8%93%E6%A0%8F-CSDN%E5%8D%9A%E5%AE%A2_cmake%20%E4%BA%A4%E5%8F%89%E7%BC%96%E8%AF%91-04.jpg)

使用工具链文件的好处就是只要编写一遍，然后在任意地方只需要使用CMAKE_TOOLCHAIN_FILE去指定其位置就可以了，非常方便。

## 三 总结

本文主要讲述如何使用CMake交叉编译Arm Linux程序，使用的测试代码也是很简单的，与交叉编译有关的变量还有很多，具体可以参考以下2篇文章，

- [文章1](https://cmake.org/cmake/help/v3.6/manual/cmake-toolchains.7.html#cross-compiling-for-linux)
- [文章2](https://gitlab.kitware.com/cmake/community/-/wikis/doc/cmake/CrossCompiling)

如果有写的不对的地方，希望能留言指正，谢谢阅读。
