# docker入门指南

这篇文章快速介绍docker使用最常用的命令和参数，以达到入门的目的。
这篇文章以官方docker hub上的Ubuntu:14.04镜像的操作为例。

## 不使用sudo运行docker

```Shell
# 将当前用户添加到 docker 组
sudo gpasswd -a ${USER} docker

# 重启服务
sudo service docker restart
```

## 基本命令

### 拉取下来的镜像的一些操作命令

```Shell
# 拉取官方14.04镜像
docker pull ubuntu:14.04

# 列出已经下载下来的镜像
docker image ls

# 删除已经下载的镜像
docker image rm 9a3a9fd0ca2f(IMAGE ID)
```

### 本地容器(container)的一些操作命令

```Shell
# 查看所有本地创建的镜像
docker ps -a

# 基于下载镜像创建实例
docker run -itd -v /home/ts/:/home/ts -v /workspace:/workspace --name ubuntu1404 ubuntu:14.04 bash
# run参数说明
# -it：这是两个参数，一个是 -i：交互式操作，一个是 -t 终端。我们这里打算进入 bash 执行一些命令并查看返回结果，因此我们需要交互式终端
# -d 创建后在后台运行
# -v dir:dir 挂载本地目录到docker实例
# --name 给实例取一个别名
# -p 表示端口映射，前者是宿主机端口，后者是容器内的映射端口。可以使用多个-p 做多个端口映射
# -e 为容器设置环境变量
# –network=host 表示将主机的网络环境映射到容器中，容器的网络与主机相同

# 运行需要网络端口的实例
docker run -it -d -p 9999:9999 --name battery-historian runcare/battery-historian --port 9999
# 映射实例9999端口到本地9999

# 进入已运行的容器
docker exec -it 容器名或容器id 进入后执行的第一个命令
# 如
docker exec -it ubuntu1404 /bin/bash

# 开始本地容器
docker start (docker name or docker ID)

# 停止本地容器 
docker stop (docker name or docker ID)

# 列出本机正在运行的容器
docker container ls

# 列出本机所有容器，包括已经终止运行的
docker container ls --all

# kill掉一个已经在运行的容器
docker container kill 容器名或容器id
```

## Docker启动与停止

```Shell
# 启动docker
sudo service docker start

# 停止docker
sudo service docker stop

# 重启docker
sudo service docker restart
```

## Docker镜像备份与迁移

```Shell
# 将容器保存为镜像
docker commit 容器名 镜像名

# 我们可以通过save命令将镜像打包成文件，拷贝给别人使用
docker save -o 保存的文件名 镜像名
# 如
docker save -o ./ubuntu.tar ubuntu

# 在拿到镜像文件后，可以通过load方法，将镜像加载到本地
docker load -i ./ubuntu.tar
```
