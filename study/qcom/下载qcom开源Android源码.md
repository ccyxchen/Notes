
```Shell
$ repo init -u git://codeaurora.org/platform/manifest.git -b [branch] -m [manifest] --repo-url=git://codeaurora.org/tools/repo.git --repo-branch=caf-stable
$ repo sync

$ repo init -u git://codeaurora.org/platform/manifest.git -b release -m [manifest] --repo-url=git://codeaurora.org/tools/repo.git --repo-branch=caf-stable
$ repo sync
```

repo init -u git://codeaurora.org/platform/manifest.git -b carrot.cupcake -m M7201JSDCBALYA6380.xml --repo-url=git://codeaurora.org/tools/repo.git --repo-branch=caf-stable