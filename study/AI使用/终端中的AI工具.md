# 终端中的AI工具

## Aichat 本地终端对话助手
### 安装：
先从 [aichat release](https://github.com/sigoden/aichat/releases) 中下载 安装包，解压后将aichat路径
加入PATH。
  
### 配置
#### 设置API key
1.创建并打开配置文件：
`mkdir -p ~/.config/aichat && nano ~/.config/aichat/config.yaml`

2.将以下内容复制到文件中，并将 你的_GEMINI_API_KEY 替换为你从 Google AI Studio 获取的免费密钥：

```yaml
# 默认使用的模型（推荐速度极快且聪明的 2.5-flash，也可换成 2.5-pro）
model: gemini:gemini-2.5-flash

clients:
  - type: gemini
    api_key: "你的_GEMINI_API_KEY"
```

如果要配置deepseek，增加type，并修改 默认模型。
```yaml
# 默认使用的模型（推荐速度极快且聪明的 2.5-flash，也可换成 2.5-pro）
model: ds:deepseek-flash

clients:
  - type: gemini
    # 模型类型：gemini-2.5-flash、gemini-2.5-pro
    api_key: "xxx"
  # ⬇️ 换用通用兼容客户端，彻底解决未知模型报错 ⬇️
  - type: openai-compatible
    name: ds
    api_base: "https://api.deepseek.com"
    api_key: "xxx"
    # 模型类型：deepseek-flash、deepseek-v4-pro
```

#### 设置快速补全终端命令功能
1、打开配置文件：
`nano ~/.bashrc`
2、在文件的最末尾，直接粘贴以下官方标准的 Bash 补全函数与快捷键绑定代码：
```bash
# AIChat 最新版 Bash 代码补全集成
_aichat_bash() {
    if [[ -n "$READLINE_LINE" ]]; then
        local _old="$READLINE_LINE"
        READLINE_LINE+=" ⌛"
        # 调用 aichat 的 -e (execute) 参数将自然语言转换为命令
        READLINE_LINE=$(aichat -e "$_old")
        READLINE_POINT=${#READLINE_LINE}
    fi
}
# 将快捷键 Alt + e (在终端映射为 \ee) 绑定到该函数
bind -x '"\ee": _aichat_bash'
```
### 基本使用
1. 单次快速提问（写完即退）
`aichat "用 Python 写一个快速排序"`

2. 交互式对话模式（类 Web 体验）
直接输入 aichat 不带任何参数，进入类似 ChatGPT 网页端的连续对话环境，它会拥有上下文记忆。
* 在交互模式下，输入 .help 可以查看内置菜单。
* 输入 .exit 或按 Ctrl + D 退出对话。
* 输入 .clear 清理当前的会话记忆，开始新话题。
* .read 命令 读入你的代码，并直接提问
 `> .read main.py 请问在下面这段代码中，我的 redis 连接池为什么没有释放？`

3. 管道符连用（终端运维神器 🛠️）
你可以把 Ubuntu 系统命令的输出直接通过管道 | 喂给 AIChat 帮你分析：
```bash
# 让 AI 帮你分析排查最后 20 行系统报错日志
tail -n 20 /var/log/syslog | aichat "分析这些日志里是否有错误，并给出修复建议"

# 让 AI 解释一段复杂的 nginx 配置文件
cat /etc/nginx/nginx.conf | aichat "用中文简要解释这个配置文件的结构"
```

4、角色/特定任务切换（Roles）
你可以利用 AIChat 强大的角色机制，让它随时切换为“Linux专家”、“翻译官”或“代码审查员”。在 ~/.config/aichat/config.yaml 中追加以下内容：
```yaml
roles:
  - name: linux-expert
    prompt: "你是一位精通 Ubuntu 运维的专家。请用最精简、最准确的 Linux 命令回答用户，并解释核心参数。"
  - name: translator
    prompt: "你是一个翻译助手，将用户输入的任何语言都翻译成优雅的英文，不要有多余的解释。"
```
使用时，用 --role 或 -r 指定角色：
```bash
aichat -r linux-expert "如何限制某个用户的 CPU 使用率？"
aichat -r translator "这堆编译报错信息看起来太头疼了"
```

5、快速切换模型
如果你平时用 gemini-2.5-flash（追求速度和省 Token），但在遇到极复杂的算法和逻辑题时想换成
更强力的 gemini-2.5-pro，无需修改配置文件，直接加参数：
`aichat -m gemini:gemini-2.5-pro "帮我重构这段具有复杂多线程死锁风险的代码..."`

6、纯代码输出模式 (-c)：
如果你在写代码或脚本，不希望 AI 说废话（比如“好的，为您编写如下：”），只想拿到纯代码：
`aichat -c "用 bash 写一个死循环，每隔5秒打印一次当前时间"`

7、创建一个固定的命名会话
如果你不想进入 AIChat 那个单独的交互界面，依然想在常规的 Ubuntu 终端里一行行敲命令，你可
以通过 --session（或 -s）参数创建一个固定的命名会话。
只要 -s 后面的名字（如 redis_bug）保持一致，AIChat 就会在后台自动同步和追溯该话题的全部历史。

## Aider git工程代码Agent
### 安装
aider 是一个python插件， 推荐使用pipx 安装，它能自动生成python 的隔离环境。
`sudo apt install pipx ;pipx install aider-install; aider-install`

### 配置API Key
Aider 强烈依赖环境变量来识别你的 API Key。为了不用每次启动都重新输入，建议将密钥永久写入到你的系统配置文件（如 ~/.bashrc）中。
```bash
# Aider 密钥配置
export GEMINI_API_KEY="你的_GOOGLE_GEMINI_API_KEY"
export DEEPSEEK_API_KEY="你的_DEEPSEEK_API_KEY"
# 指定一个“默认模型”
export AIDER_MODEL="deepseek/deepseek-chat"
```

### 基本使用
#### 指定默认模型
```bash
# 验证 Gemini 连接
aider --model gemini/gemini-2.5-flash

# 验证 DeepSeek 连接
aider --model deepseek/deepseek-chat
```
#### 解决大工程每次提问都重新init scan耗时
1. 通过命令行参数改变 Repo Map 的刷新逻辑，不再让“提问中提到的名字”成为强制重扫的理由。
尝试使用 --map-refresh files 参数启动
`aider --map-refresh files`
原理：设置为 files 后，Aider 只有在仓库文件本身发生变更（比如你添加或删除了文件）时，才会重新扫描。单纯改变提问内容（提及不同的文件或函数）不会触发重扫，从而复用缓存

2. 缩小工作范围（治本之策）
最根本的办法就是让它不要扫描整个仓库。对于大型项目，强烈建议配合使用以下参数：
* 使用 --subtree-only：先 cd 到你正在工作的子目录，再启动 Aider。这会告诉 Aider 只处理当前目录及子目录，忽略仓库其余部分。
* 配置 .aiderignore：在项目根目录创建该文件，用类似于 .gitignore 的语法排除掉构建产物、依赖缓存、测试数据等不需要 Aider 理解的目录。
一个针对大型 Monorepo 的 .aiderignore 示例写法是“先忽略所有，再放行需要的目录”：
```gitignore
# 忽略根目录下所有内容
/*

# 放行你实际工作的子目录
!apps/my-feature/
!libs/shared-utils/
```
#### Aider终端中高频命令
1. 基础代码修改（最核心用法）
你只需要用自然语言描述你的需求，Aider 会自己找到对应的文件并直接修改。
Aider 的动作： 它会分析 main.py，写好代码，直接修改该文件，并在修改成功后，自动执行
一次 git commit，把修改记录进你的 Git 历史中。

2. 把文件加入/移出会话上下文（/add 和 /drop）
虽然 Aider 认识你的全部项目，但如果你希望它重点修改或盯着某几个文件，可以手动锁死它们：
```text
> /add src/auth.py src/models.py
# 此时这两个文件会被完整加载。接下来提问：
> 请帮我在这两个文件之间建立用户密码加密的逻辑调用
```
如果改完了，不再需要它们占用多余的 API Token，可以将其释放：
`> /drop src/auth.py`

3. 后悔药：一键回滚（/undo）
如果 AI 刚刚改的代码完全不对，或者把你的逻辑改崩了，不要慌，不需要去敲繁琐的 git 命令，直接输入：
`> /undo`
Aider 会立刻利用 Git 撤销上一次 AI 所做的所有修改，将代码完美恢复到几秒钟前的状态。

4. 在 AI 环境下直接运行编译/测试命令（/run）
如果代码改完后你想编译或者跑一下单元测试，直接在 Aider 里输入：
```text
> /run go build
# 或者
> /run pytest test_main.py
```
如果编译或测试报错了，Aider 会自动抓取屏幕上的报错日志，并主动问你：“我看到编译失败了，需要我帮你修复这个错误吗？”。你只需回答 yes，它就会开始自动 debug。

5. 纯聊天不改代码（/chat）
如果你只是想问问它某个算法的原理，或者讨论一下技术架构，不希望它去动你的任何文件：
```text
> /chat 解释一下什么是 Redis 的雪崩和穿透，以及通常怎么防御？
```

6. 退出 Aider
`> /exit` 

## opencode - 终端上的agent IDE
### 安装opencode
`curl -fsSL https://opencode.ai/install | bash`

### 命令行启动与管理 (CLI)
```bash
opencode                  # 在当前目录启动交互式 TUI
opencode /path/to/project # 指定工程目录启动
opencode -c               # 继续上一次会话 (--continue)
opencode -m <provider/id> # 指定模型启动 (如 opencode -m anthropic/claude-sonnet-4-5)
opencode run "<prompt>"   # 非交互式单次运行并输出结果
opencode auth login       # 登录并配置模型供应商 API Key
opencode models           # 列出所有可用的模型
opencode stats            # 查看 Token 消耗与费用统计
```
### 交互式界面斜杠命令 (TUI Slash Commands)

在输入框以 `/` 开头输入：

| 命令 | 说明 | 对应快捷键 (默认 Leader: `Ctrl+x`) |
| :--- | :--- | :--- |
| `/models` | 切换/选择大模型 | `Ctrl+x m` |
| `/new` (或 `/clear`) | 开启新会话 | `Ctrl+x n` |
| `/sessions` (或 `/resume`) | 查看并切换历史会话 | `Ctrl+x l` |
| `/compact` (或 `/summarize`) | 压缩当前会话上下文（节省 token） | `Ctrl+x c` |
| `/undo` | 撤销上一步操作及对应的文件修改 | `Ctrl+x u` |
| `/redo` | 重做被撤销的操作及文件修改 | `Ctrl+x r` |
| `/thinking` | 显示/隐藏模型的思考/推理过程 | - |
| `/editor` | 打开外部文本编辑器编辑输入 | `Ctrl+x e` |
| `/export` | 将会话导出为 Markdown 打开 | `Ctrl+x x` |
| `/connect` | 添加并配置 Provider 凭据 | - |
| `/help` | 打开帮助对话框 | - |
| `/exit` (或 `/q`) | 退出 OpenCode | `Ctrl+x q` / `Ctrl+c` |
| `/mcps` | 使能或禁用MCP | - |
| `/skills` | 引用某个skill | - |

---

### 输入提示词常用技巧

- **引入文件上下文 (`@`)**：输入 `@文件名`（支持模糊补全，如 `@src/index.ts`），会将该文件内容自动载入上下文。
- **执行本地命令 (`!`)**：输入 `!<命令>`（如 `!git status` 或 `!pytest`），会先执行该终端命令并将结果作为输入发送给模型。

---

### 常用快捷键

- `Ctrl+x`：默认 **Leader Key**，按下后两秒内按下后缀按键（如 `Ctrl+x m` 选模型）。
- `Ctrl+t`：循环切换当前模型的推理档位/变体 (Variant)。
- `Ctrl+p`：打开全局命令面板 (Command List)。
- `Esc`：中断正在生成的回答或取消弹窗。
- `Shift+Enter` / `Ctrl+Enter`/`Ctrl+j`：输入框内换行。

---

### /init 命令

🧠 /init 如何工作？
根据 OpenCode 官方文档，/init 的工作流程如下：
1. 扫描项目：它会自动扫描你仓库中的重要文件，以理解项目的结构、技术栈和用途。
2. 智能提问：如果仅凭代码无法推断出某些关键信息（例如特定的构建步骤或团队约定），它可能会向你提出几个有针对性的问题来补全上下文。
3. 生成或更新：基于扫描结果和你的回答，它会创建或更新 AGENTS.md 文件。如果你已经有一个 AGENTS.md，/init 会在原文件基础上进行改进，而不是直接覆盖。

---

### 使用本地localAI模型

本地localAI 的URL是`http://localhost:8081/v1`，在`~/.config/opencode/opencode.jsonc`文件中添加如下配置信息，
```json
  "provider": {
    "localai": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "LocalAI (local)",
      "options": {
        "baseURL": "http://localhost:8081/v1",
        "apiKey": "1"
      },
      "models": {
        "ornith-1.5-9b-uncensored": {
          "name": "Ornith 1.5 9B",
          "limit": { "context": 100000, "output": 8192 }
        }
      }
    }
  }
```
重启 OpenCode 后，就能使用新加的本地模型。
>注意： 需要设置 `"context": 100000`指定上下文大小，否则opencode 的上下文压缩功能不生效。

---

### 添加联网MCP

1. deepseek 模型
可以使用 websearch-deepseek 这个 MCP 服务器，它直接调用 DeepSeek 原生的联网搜索 API。配置后，OpenCode 在需要时会自动调用 web_search 工具。
在`~/.config/opencode/opencode.jsonc`中添加：
```json
{
  "mcpServers": {
    "websearch-deepseek": {
      "command": "npx",
      "args": ["websearch-deepseek"],
      "env": {
        "DEEPSEEK_API_KEY": "sk-xxxxxxxxxxxxxxxx",
        "WEBSEARCH_MODEL": "deepseek-v4-flash"
      }
    }
  }
}
```
配置完成后重启 OpenCode，模型在遇到需要实时信息的问题时会自动触发搜索。

2. @zhafron/mcp-web-search - 免费web工具
在`~/.config/opencode/opencode.jsonc`中添加：
```json
  "mcp": {
    "web-search": {
      "type": "local",
      //"enabled": false,
      "command": ["npx", "-y", "@zhafron/mcp-web-search"],
      "timeout": 60000,
    }
  }
```

---

### FAQ

#### 1. 怎么快速停止当前任务

- Esc (首选)：这是停止当前 AI 操作或生成最常用的快捷键。当模型正在思考、生成回复或执行工具时，按下 Esc 即可中断当前会话。
- Ctrl+X：在聊天界面中，Ctrl+X 也可以用于取消当前的 AI 操作或生成。
- Ctrl+G：如果你打开了某个弹窗（如权限请求对话框），Ctrl+G 可以取消弹窗并中止正在运行的响应。

#### 2. 怎么复制里面的内容

- 基本操作：`按住鼠标左键，拖动选择你想要复制的文本`，然后松开鼠标。OpenCode 通常会自动将选中内容复制到系统剪贴板，并提示“Copied to clipboard”。
- 如果自动复制失效：在一些环境（如 WSL、远程 SSH 或部分 Linux 终端）中，自动复制可能不工作。这时，你需要`按住 Shift 键再用鼠标拖动选择`，这会跳过 OpenCode 的自动复制功能，改用终端原生的选择机制。选中后，根据你的终端类型，使用` Ctrl+Shift+C `或鼠标中键来复制。
- 默认快捷键：Ctrl+X 是 OpenCode 的 Leader 键。按下 `Ctrl+X，松开，再按 Y（即“Yank”）`，即可复制最后一条 AI 回复。

#### 3. 禁用或启用MCP

- /mcps 命令的设计初衷，就是让你能在当前这个对话会话中，临时启用或禁用已配置的 MCP 服务器，方便按需切换。
- 项目级持久化：在项目根目录的 opencode.json 中，为对应的 MCP 服务器添加 "enabled": false。这样，在该项目下启动 OpenCode 时，这个 MCP 就不会被加载。
- 全局持久化：在全局配置文件 ~/.config/opencode/opencode.json 中做同样的修改，即可对所有项目生效。

#### 4. 禁用或启用skill

- ##### 方法一：使用 opencode-disabler 插件（推荐，项目级）

这是最灵活、对项目影响最小的方法。opencode-disabler 插件允许你在特定项目中禁用全局安装的 Skill，而不影响其他项目。

1. 安装插件
在你的全局配置文件 ~/.config/opencode/opencode.jsonc 的 plugin 数组中，添加 opencode-disabler。注意，它必须列在你想要禁用的其他插件之前。
```json
{
  "plugin": [
    "opencode-disabler@1.1.1",
    "oh-my-opencode@3.11.2"
  ]
}
```
2. 在项目中创建禁用配置
在你想禁用 Skill 的项目根目录下，创建 .opencode/disabler.jsonc 文件，并列出要禁用的 Skill 名称：
```json
{
  "$schema": "https://raw.githubusercontent.com/devxoul/opencode-disabler/main/schema.json",
  "skills": ["your-skill-name"]
}
```
保存后重启 OpenCode，该 Skill 在此项目中将立即失效。

- ##### 方法二：利用 Skill 权限控制（最精细）

OpenCode 原生支持通过 opencode.json 中的 permission 字段对 Skill 进行基于模式的精细控制。这并非“删除”，而是让 Agent 无法看到或访问该 Skill。
在 ~/.config/opencode/opencode.jsonc 中添加：
```json
{
  "permission": {
    "skill": {
      "your-skill-name": "deny"
    }
  }
}
```
 - deny：该 Skill 对 Agent 隐藏，访问请求会被拒绝。
 - ask：每次尝试加载该 Skill 时，OpenCode 都会询问你是否允许。
 
你还可以使用通配符，例如 "internal-*": "deny" 来匹配多个 Skill。

### 开启LSP

每种编程语言都有其 对应的语言服务,c/c++ 是clangd。
在 opencode 中配置 Java 和 Python 的 LSP，核心思路与配置 clangd 一致：在 opencode.json 的 lsp 字段中，为对应的语言服务器指定正确的 command 和 extensions。
- Java 的内置 LSP 是 jdtls，它依赖 Java SDK 21 或更高版本 才能运行。
- opencode 内置的 Python LSP 是 pyright，它要求你的项目中安装了 pyright 依赖。

#### opencode 配置 clangd 使用 c/c++的 LSP

在`~/.config/opencode/opencode.jsonc`中配置：
```yaml
  "lsp": {
    "clangd": {
      "command": [
        "clangd",
        "--background-index",
   //     "--compile-commands-dir=/home/chenyx/workspace/code_study/tinycore_6_18_rpi"
      ],
      "disabled": false
    }
  }
```

配置说明：
- command：这是一个字符串数组，第一个元素是可执行文件（clangd），后续元素是传递给它的参数。
- --compile-commands-dir：最关键的参数，需要指向包含 compile_commands.json 文件的目录。
由于你是在项目根目录 /home/chenyx/workspace/code_study/tinycore_6_18_rpi 下执行编译命令，compile_commands.json 通常就在这个目录下。
- disabled：设置为 false 表示启用该 LSP 服务器。

在项目中，需要根据 [配置vs code代码开发环境.md](../Linux/系统配置/配置vs%20code代码开发环境.md) 中的clangd 配置章节生成 compile_commands.json,才能正确使用clangd 服务。

上面的配置完成后，可以在项目根目录执行以下命令验证生效：
` opencode debug lsp diagnostics --print-logs "某个原文件"`
