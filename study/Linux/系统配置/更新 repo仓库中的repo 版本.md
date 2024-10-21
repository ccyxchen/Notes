# 更新repo仓的repo版本

先下载最新repo源码，这个工具是python脚本，repo 命令就在源码仓中。
`git clone https://gerrit.googlesource.com/git-repo`

然后将repo加入PATH环境变量，这时到repo仓下执行 `repo --version`可能会报错，需要确认python版本是否匹配。
另外 执行repo会调用 仓库下的.repo/repo/ 中的python脚本，如果repo 工具的python和该目录下需要的python不匹配，会报错。
这时需要将上面下载的repo源码替换.repo/repo下的。
