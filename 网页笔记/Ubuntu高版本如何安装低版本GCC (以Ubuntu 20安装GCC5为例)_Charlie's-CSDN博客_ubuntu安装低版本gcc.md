# (130条消息) Ubuntu高版本如何安装低版本GCC (以Ubuntu 20安装GCC5为例)_Charlie's-CSDN博客_ubuntu安装低版本gcc

安装了Ubuntu 20.04之后，通过命令行

- sudo apt-get install build-essential

安装gcc，再通过命令行

- gcc -v

可查看gcc版本为gcc9

如果想用低版本的gcc，比如gcc5，尝试输入命令

sudo apt-get install gcc-5

会提示找不到gcc5的安装包

那么就需要添加较低版本的源

网上搜索得到gcc5对应的Ubuntu版本为16，接下来就对Ubuntu20.04的源文件source.list进行编辑，增加Ubuntu16的源

通过命令用gedit编辑器（也选择其他编辑器，如vim，mousepad等）打开sources.list文件，

- sudo gedit /ect/apt/sources.list

在文件尾部增加Ubuntu16的源，我使用的是阿里云的源

```crystal
deb http://mirrors.aliyun.com/ubuntu/ xenial main
deb-src http://mirrors.aliyun.com/ubuntu/ xenial main

deb http://mirrors.aliyun.com/ubuntu/ xenial-updates main
deb-src http://mirrors.aliyun.com/ubuntu/ xenial-updates main

deb http://mirrors.aliyun.com/ubuntu/ xenial universe
deb-src http://mirrors.aliyun.com/ubuntu/ xenial universe
deb http://mirrors.aliyun.com/ubuntu/ xenial-updates universe
deb-src http://mirrors.aliyun.com/ubuntu/ xenial-updates universe

deb http://mirrors.aliyun.com/ubuntu/ xenial-security main
deb-src http://mirrors.aliyun.com/ubuntu/ xenial-security main
deb http://mirrors.aliyun.com/ubuntu/ xenial-security universe
deb-src http://mirrors.aliyun.com/ubuntu/ xenial-security universe
```

保存文件后，输入命令,更新源

- sudo apt-get update

然后输入命令，查看gcc5可选的版本

- apt-cache policy gcc-5

选择其中一个版本进行安装

- sudo apt-get install gcc-5=5.4.0-6ubuntu1~16.04.12

<span style="color:#f33b45">g++5的安装是类似的步骤</span>

然后查看gcc版本

- gcc -v

发现版本还是gcc9

通过命令查询本机gcc已安装的版本

- ls /usr/bin/gcc\*

可以看到有gcc9和gcc5

这个时候需要管理多版本的gcc，使我们想要的gcc5成为默认版本

输入命令

- sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-5 40
- sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 50
- sudo update-alternatives --config gcc

![(130条消息) Ubuntu高版本如何安装低版本GCC (以Ubuntu 20安装GCC5为例)_Charlie's-CSDN博客_ubuntu安装低版本gcc-01](img/(130%E6%9D%A1%E6%B6%88%E6%81%AF)%20Ubuntu%E9%AB%98%E7%89%88%E6%9C%AC%E5%A6%82%E4%BD%95%E5%AE%89%E8%A3%85%E4%BD%8E%E7%89%88%E6%9C%ACGCC%20(%E4%BB%A5Ubuntu%2020%E5%AE%89%E8%A3%85GCC5%E4%B8%BA%E4%BE%8B)_Charlie%27s-CSDN%E5%8D%9A%E5%AE%A2_ubuntu%E5%AE%89%E8%A3%85%E4%BD%8E%E7%89%88%E6%9C%ACgcc-01.jpg)

根据提示，选择gcc-5对应的编号1 回车即可

最后gcc -v查看默认gcc版本，应当已经切换为gcc5

<span style="color:#f33b45">如果要对g++的多版本进行管理，只需将上面命令行中的gcc替换为g++</span>
