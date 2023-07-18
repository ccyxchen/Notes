# repo 常用操作

## repo 切换分支

查看可切换的分支

```Shell
cd .repo/manifests
git branch -a | cut -d / -f 3
```

以 imx-4.1.15-1.0.0_ga 分支为例

```Shell
repo init -b imx-4.1.15-1.0.0_ga
repo sync   # 如果不需要与服务器数据一致，可以不运行该步
repo start imx-4.1.15-1.0.0_ga --all 
```

查看切换结果
`repo branches`
