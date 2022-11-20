## 合并某个分支上的单个commit
首先，用git log或GitX工具查看一下你想选择哪些commits进行合并，例如：
```
dd2e86 - 946992 -9143a9 - a6fd86 - 5a6057 [master]

           \

            76cada - 62ecb3 - b886a0 [feature]
```

比如，feature 分支上的`commit 62ecb3 `非常重要，它含有一个bug的修改，或其他人想访问的内容。无论什么原因，你现在只需要将62ecb3 合并到master，而不合并feature上的其他commits，所以我们用`git cherry-pick`命令来做：

```
git checkout master
git cherry-pick 62ecb3
```

这样就好啦。现在62ecb3 就被合并到master分支，并在master中添加了commit（作为一个新的commit）。cherry-pick 和merge比较类似，如果git不能合并代码改动（比如遇到合并冲突），git需要你自己来解决冲突并手动添加commit。

## 合并某个分支上的一系列commits
在一些特性情况下，合并单个commit并不够，你需要合并一系列相连的commits。这种情况下就不要选择cherry-pick了，rebase 更适合。还以上例为例，假设你需要合并feature分支的commit76cada ~62ecb3 到master分支。

首先需要基于feature创建一个新的分支，并指明新分支的最后一个commit：

```
git checkout -b newbranch 62ecb3
```

然后，rebase这个新分支的commit到master（--ontomaster）。76cada^ 指明你想从哪个特定的commit开始。

```
git rebase --onto master 76cada^
```

得到的结果就是feature分支的commit 76cada   ~ 62ecb3  都被合并到了master分支。
