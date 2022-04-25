# git常用命令合集

## 合代码相关

```Shell
# 重写最近的提交消息
git commit --amend
```

## 杂项

```Shell
# 把第一次commit 提交以后的（不包括第一次提交）都生成patch 
git format-patche795fefabc

# 应用patch
先检查patch文件：git apply --stat newpatch.patch
检查能否应用成功：git apply --check newpatch.patch
打补丁：git am --signoff < newpatch.patch

```
