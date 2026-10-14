# Ubuntu 18.04 如何添加或删除 SWAP 交换分区 - 系统极客

![Ubuntu](img/Ubuntu%2018.04%20%E5%A6%82%E4%BD%95%E6%B7%BB%E5%8A%A0%E6%88%96%E5%88%A0%E9%99%A4%20SWAP%20%E4%BA%A4%E6%8D%A2%E5%88%86%E5%8C%BA%20-%20%E7%B3%BB%E7%BB%9F%E6%9E%81%E5%AE%A2-01.jpg)

大家都知道，当 Linux 系统在消耗完物理内存时，非活动页面就会从物理内存移动到 SWAP 空间，而 SWAP 空间可以采用专用的 **SWAP 分区**或 **SWAP 文件**形式存在。而在大多数情况下，在虚拟机中运行 Ubuntu 系统时，都不会自动创建 SWAP 交换分区。

下面系统极客就为大家介绍，如何为 Ubuntu 18.04 手动创建 SWAP 交换文件。

## 开始之前

在开始创建之前，请先使用如下命令检查您的 Ubuntu 系统是否已经启用了 SWAP 分区：

```
sudo swapon --show
```

如果输出为空，则表示当前系统尚未启用 SWAP 空间；反之，您将看到相关反馈。

虽然可能，但在同一台 Linux 机器上有多个 SWAP 空间的情况并不常见。

## 创建SWAP分区文件

您可以执行以下步骤在 Ubuntu 18.04 系统中添加 SWAP 交换文件：

1 通过以下命令创建一个用于 swap 的文件：

```
sudo fallocate -l 1G /swapfile
```

如果未安装 fallocate 或者收到错误提示，也可以使用以下命令创建 swap 文件：

```
sudo dd if=/dev/zero of=/swapfile bs=1024 count=1048576
```

2 执行以下命令为 swapfile 文件设置正确的权限：

```bash
sudo chmod 600 /swapfile
```

3 使用 mkswap 实用程序在文件上设置 Linux SWAP 区域：

```
sudo mkswap /swapfile
```

4 使用以下命令激活 swap 文件：

```
sudo swapon /swapfile
```

5 要让创建好的 swap 分区永久生效，可以将 swapfile 路径内容写入到 /etc/fstab 文件当中：

```
/swapfile swap swap defaults 0 0
```

6 使用 swapon 或 free 命令验证 SWAP 是否处于活动状态，如下所示：

```
sudo swapon --show
```

```
sudo free -h
```

![终端](img/Ubuntu%2018.04%20%E5%A6%82%E4%BD%95%E6%B7%BB%E5%8A%A0%E6%88%96%E5%88%A0%E9%99%A4%20SWAP%20%E4%BA%A4%E6%8D%A2%E5%88%86%E5%8C%BA%20-%20%E7%B3%BB%E7%BB%9F%E6%9E%81%E5%AE%A2-02.jpg)

## 调整Swappiness值

Swappiness 是一个 Linux 内核属性，用于定义 Linux 系统使用 SWAP 空间的频率。Swappiness 值可以从 0 至 100，较低的值会让内核尽可能少的使用 SWAP 空间，而较高的值将让 Linux Kernel 能够更加积极地使用 SWAP 分区。

Ubuntu 18.04 默认的 Swappiness 值为 60，您可以使用如下命令来查看：

```bash
cat /proc/sys/vm/swappiness
```

值为 60 对于 Ubuntu 18.04 桌面还算行，但对于 Ubuntu Server 来说，SWAP 的使用频率就比较高了，所以您可能需要设置较低的值。例如，要将 swappiness 值设置为 40，请执行：

```
sudo sysctl vm.swappiness=40
```

![终端](img/Ubuntu%2018.04%20%E5%A6%82%E4%BD%95%E6%B7%BB%E5%8A%A0%E6%88%96%E5%88%A0%E9%99%A4%20SWAP%20%E4%BA%A4%E6%8D%A2%E5%88%86%E5%8C%BA%20-%20%E7%B3%BB%E7%BB%9F%E6%9E%81%E5%AE%A2-03.jpg)

如果要让设置在系统重启后依然有效，则必要在 /etc/sysctl.conf 文件中添加以下内容：

```
vm.swappiness=40
```

最佳 swappiness 值取决于您系统的工作负载以及内存的使用方式，您应该以小增量的方式来调整此参数，以查到最佳值。

## 移除SWAP分区

Ubuntu 18.04 要停用并删除 SWAP 文件，请按照下列步骤操作：

1 首先输入以下命令停用 SWAP 空间：

```
sudo swapoff -v /swapfile
```

2 在 /etc/fstab 文件中删除有效 swap 的行。

3 最后执行以下命令删除 swapfile 文件：

```
sudo rm /swapfile
```

![终端](img/Ubuntu%2018.04%20%E5%A6%82%E4%BD%95%E6%B7%BB%E5%8A%A0%E6%88%96%E5%88%A0%E9%99%A4%20SWAP%20%E4%BA%A4%E6%8D%A2%E5%88%86%E5%8C%BA%20-%20%E7%B3%BB%E7%BB%9F%E6%9E%81%E5%AE%A2-04.jpg)
