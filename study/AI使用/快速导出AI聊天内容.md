# 快速导出AI聊天内容

## 安装 uv

在 Ubuntu 上安装 uv 最推荐用官方独立脚本，一条命令搞定，不需要先装 Python 或 Rust。
打开终端，直接执行：
```bash
wget -qO- https://astral.sh/uv/install.sh | sh
source ~/.bashrc
```
验证：
`uv --version`

## 安装agent-dump

如果你打算经常用它来导出会话，推荐安装到本地。官方推荐的 Python 工具链安装方式如下:
```bash
# 1. 克隆仓库
git clone https://github.com/xingkaixin/agent-dump.git
cd agent-dump

# 2. 用 uv 安装依赖（如果还没装 uv，可先参考官方文档安装）
uv sync

# 3. 安装到本地工具链
uv tool install . --force
```
装好后，就可以直接用 agent-dump 命令了。

### 安装后怎么用

针对你之前的需求（导出 OpenCode 会话），安装完成后可以这样用：
```bash
# 查看 OpenCode 某个会话的内容（把 <session-id> 替换成实际 ID）
agent-dump opencode://<session-id>

# 或者用交互模式，从列表里选要导出的会话
agent-dump --interactive
```

>导出为md
>1. 在 --interactive 模式下，你需要显式指定 --format markdown，才能将选中的会话导出为 Markdown 文件。
>`agent-dump --interactive --format markdown`
>2. 如果需要指定输出目录，可以加上 --output 参数：
>`agent-dump --interactive --format markdown --output ./my-sessions`
>执行后，工具会先列出可选的会话列表，你通过交互界面勾选目标会话，确认后就会生成对应的 .md 文件。
>
>**⚠️ 注意事项**
>- --interactive 模式不支持 print 格式，不要写成 --format print,markdown。
>- md 是 markdown 的别名，写 --format md 效果完全相同。
>- 如果不加 --output，文件默认会输出到当前工作目录下的 ./sessions 文件夹。
