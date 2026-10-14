# Graphify - RAGcode设置

## 在 Ubuntu 上安装 Graphify

### 1. 环境准备

Graphify 的 PyPI 包名是 **`graphifyy`**（双 y），需要 **Python 3.10+**。Ubuntu 自带的是 `python3` 而非 `python`。

```bash
# 安装 Python 相关工具
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 python3-pip python3-venv python-is-python3 curl
```

### 2. 安装 Graphify

推荐使用 `uv` 进行工具隔离安装，也支持 `pip`。

```bash
# 使用 uv（推荐）,安装命令加入了graphifyy导出svg图片时依赖的库
curl -LsSf https://astral.sh/uv/install.sh | sh
uv tool install "graphifyy[openai] --with scipy --with matplotlib --force"
```

> **注意**：`[openai]` 额外依赖是必需的，因为 Graphify 与 LocalAI 通信时使用 OpenAI 兼容客户端库。

### 3. 注册 Graphify Skill

安装完成后，将其注册到你的 AI 编程助手（如 Claude Code、Codex、Cursor 等）：

```bash
graphify install
# 或指定平台
graphify install --platform codex
```

---

## 将 Graphify 连接到 LocalAI

Graphify 的 `--backend openai` 支持通过环境变量覆盖端点，直接指向 LocalAI 的 OpenAI 兼容 API，无需额外配置 `providers.json`。

### 1. 设置环境变量

```bash
export OPENAI_BASE_URL="http://localhost:8081/v1"
export OPENAI_MODEL="qwen3-4b"          # 替换为你 LocalAI 中实际加载的模型名
export OPENAI_API_KEY="none"             # 本地服务器接受任意非空值
```

> 可通过 `curl http://localhost:8080/v1/models` 确认 LocalAI 实际暴露的模型名称。

### 2. 验证连接

```bash
graphify extract ./docs --backend openai
```

如果配置正确，Graphify 将使用 LocalAI 中的模型进行语义提取。

---

## 连接到deepseek

把 Graphify 连接到 DeepSeek 并使用 V4.1 模型，核心是通过环境变量配置它的 --backend deepseek 后端。Graphify 已经原生支持 DeepSeek，配置起来很直接。

1. 首先，你需要一个 DeepSeek 平台的 API Key。然后，将其设置为环境变量，这是 Graphify 识别 DeepSeek 后端的基础。
>`export DEEPSEEK_API_KEY="你的DeepSeek-API-Key"`

2. 指定 V4.1 模型名称
DeepSeek V4.1 Flash 的官方模型 ID 是 deepseek-flash，旧的 deepseek-v4-flash 等名称虽仍可能被路由，但建议使用新 ID 以确保准确性。
Graphify 通过 GRAPHIFY_DEEPSEEK_MODEL 环境变量来覆盖默认模型。因此，你需要这样设置：
>`export GRAPHIFY_DEEPSEEK_MODEL="deepseek-flash"`

如果不设置此变量，Graphify 可能会使用其内部默认的 DeepSeek 模型（例如 deepseek-chat 或 deepseek-v4-flash）。

3. 运行 Graphify 提取命令
在运行 graphify extract 时，显式指定使用 DeepSeek 后端：
>`graphify extract . --backend deepseek`

通过 --backend deepseek 参数，Graphify 会读取你设置的 DEEPSEEK_API_KEY，并按照 GRAPHIFY_DEEPSEEK_MODEL 的指定调用模型。

---

## 生成代码库的 RAG（知识图谱）

### 1. 运行 Graphify 提取管道

Graphify 通过 **AST 解析 + 语义提取**构建知识图谱，替代传统向量检索 RAG，对代码库尤其有效。在代码库根目录执行：

```bash
# 在当前代码库目录运行完整提取管道
graphify .

# 或指定路径
graphify /path/to/your/codebase

# 深度模式（更丰富的推断边）
graphify . --mode deep

# 仅代码结构分析（跳过 LLM 语义提取）
graphify extract . --code-only

# 生成图谱网页
graphify cluster-only .
```

执行完成后，会在当前目录生成 **`graphify-out/`** 文件夹，包含：交互式 HTML 可视化、GraphRAG 就绪的 JSON（`graph.json`）、以及人类可读的 `GRAPH_REPORT.md`。

#### 使用本地AI报错问题

##### 1、上下文过小
```txt
[graphify] chunk of 51 exceeded context at depth 0 (InternalServerError); splitting in half and retrying
[graphify] openai returned a hollow response (content=no nodes/edges, 
```
根源都是 LocalAI 的上下文窗口（Context Window）设置过小，导致 Graphify 在发送提取请求时触发了模型的限制。我们可以从调整 LocalAI 和 Graphify 两侧的配置入手来解决。

**🔍 问题诊断**
- exceeded context：你使用的本地模型上下文窗口可能只有 4K-32K，而 Graphify 默认会打包一个约 60K token 的大块（chunk）去调用模型，导致请求因超出上下文限制而被服务器拒绝。
- hollow response：这通常不是分块大小的问题，而是模型在接收到提示后，虽然返回了内容，但内容中不包含任何有效的节点（nodes）或边（edges），导致 Graphify 无法从响应中提取出任何知识图谱信息。

**🛠️ 解决方案**
1. 调整 Graphify 的分块大小（最直接）
通过 --token-budget 参数，强制 Graphify 在打包文件时使用更小的 token 预算，从而生成更小的块发送给 LocalAI，避免超出模型限制。
```bash
# 将 token 预算设置为 4000，这会给 8K 上下文窗口的模型留出足够空间
graphify extract . --token-budget 4000
```
这个参数在官方文档中被推荐用于本地或小型模型，可以有效减少输入大小。

2. 调整 LocalAI 的上下文窗口（可选）
如果希望从源头增大限制，可以修改 LocalAI 的模型配置文件来增加 context_size。
```yaml
# 在 LocalAI 的模型配置 YAML 文件中
name: your-model-name
context_size: 8192  # 将默认的 512 或 4096 增大
```
**注意**：context_size 的值应根据你模型本身支持的最大上下文窗口以及你的 GPU 显存来设定，过大会导致显存溢出。

3. 处理 Hollow Response 问题
- 调整输出上限：通过环境变量 GRAPHIFY_MAX_OUTPUT_TOKENS 提高模型输出 token 的上限，给模型更多空间来生成完整的 JSON 响应。
```bash
export GRAPHIFY_MAX_OUTPUT_TOKENS=16384
graphify extract . --token-budget 4000
```

##### 2、大规模并发请求下崩溃

```txt
[graphify] chunk of 3 truncated at depth 0, splitting into halves of 1 and 2
[graphify extract] chunk 2/1020 done
[graphify] chunk 1/1020 failed: Error code: 500 - {'error': {'code': 500, 'message': 'rpc error: code = Unavailable desc = closing transport due to: connection error: desc = "error reading from server: EOF", received prior goaway: code: NO_ERROR', 'type': ''}}
[graphify] chunk 4/1020 failed: Error code: 500 - {'error': {'code': 500, 'message': 'rpc error: code = Unavailable desc = connection error: desc = "transport: Error while dialing: dial tcp 127.0.0.1:36391: connect: connection refused"', 'type': ''}}
```
你遇到的这两个新错误，表明问题已经从单纯的上下文超限，演变成了 LocalAI 后端进程在大规模并发请求下崩溃。

EOF 错误意味着后端进程在处理请求时意外崩溃，而 connection refused 则是后端进程崩溃后，Graphify 尝试重连一个已经不存在的 gRPC 端口。在 10886 个文件、1020 个分块的高并发场景下，这通常是显存/内存耗尽（OOM） 或 gRPC 端口资源耗尽导致的。

🛠️ 解决方案
1. 根治 LocalAI 后端崩溃
首先需要确保 LocalAI 后端在高负载下不会崩溃。
- 增加 gRPC 端口范围：Graphify 的并发请求会为每个后端实例分配 gRPC 端口，端口耗尽会导致连接失败。通过设置环境变量扩大端口范围：
```bash
export LOCALAI_GRPC_MIN_PORT=50051
export LOCALAI_GRPC_MAX_PORT=50100
local-ai run your-model-name
```
范围大小应基于峰值并发后端数量来设定，并留出一定余量。
- 启用显存/内存回收：在 LocalAI 配置中启用` LOCALAI_MEMORY_RECLAIMER=true`，让 LocalAI 在内存压力大时自动卸载不常用的模型，防止 OOM 崩溃。
- 大活跃后端数：通过 LRU（最近最少使用）策略限制同时加载的模型数量：
```bash
export LOCALAI_MAX_ACTIVE_BACKENDS=2
local-ai run your-model-name
```
这能有效控制资源占用，避免过多后端同时运行耗尽显存。

2. 调整 Graphify 的并发与超时
其次，需要降低 Graphify 对 LocalAI 的瞬时压力。
- 降低并发数：将并发数设为 1 或 2，避免同时发起大量请求压垮本地后端。
`graphify extract . --max-concurrency 1`
- 提高 API 超时时间：大规模提取时单次调用可能耗时较长，增加超时时间可以避免因超时而中断重试：
```bash
export GRAPHIFY_API_TIMEOUT=1800
graphify extract . --max-concurrency 1
```
有用户反馈将超时设为 1800 秒后，原本无法完成的提取任务可以顺利完成。

3. 优化 Graphify 的分块策略
- 进一步缩小分块大小：将 --token-budget 设置得更小（如 2048 或 4000），确保每个分块远小于模型上下文窗口。
>`graphify extract . --token-budget 4000 --max-concurrency 1`
- 使用 --code-only 模式：如果代码库中非代码文件（如文档、图片）不多，可以仅提取代码结构，跳过 LLM 语义提取，大幅减少请求量。
>`graphify extract . --code-only`

该模式仅使用 AST 解析，不调用 LLM，速度极快。
- 排除不必要的目录：检查代码库中是否有 node_modules、.git、构建产物等大型目录被意外扫描。可通过 .gitignore 或手动指定路径来排除。
>`graphify extract ./src --max-concurrency 1 --token-budget 4000`

### 2. 增量更新

当代码变更后，无需全量重建：

```bash
graphify . --update
```

### 3. 查询知识图谱（RAG 检索）

Graphify 的核心是 **用图遍历替代向量相似度检索**，直接通过 CLI 查询：

```bash
# 自然语言查询
graphify query "show the auth flow"

# 查找两个概念之间的最短路径
graphify path "AuthModule" "Database"

# 解释某个节点的作用
graphify explain "Response"
```

查询输出包含节点标签、边类型、置信度标签、源文件及位置信息，可直接作为 LLM 的上下文输入。

---

## 常用命令参数

1. graphify cluster-only 命令用于在已有知识图谱的基础上，重新进行社区发现和命名，而不会重新提取代码或调用 LLM，能帮你节省大量 token 和时间。
**该命令会生成`graphify-out/GRAPH_REPORT.md`和`graphify-out/graph.html`这2个节点可视化文件。**

🎯 这步命令具体做什么？
当代码库发生变化后，图谱的“社区结构”（即代码模块的聚类方式）可能已经过时。cluster-only 会执行以下操作：
- 跳过提取阶段：它不会重新扫描文件或调用语义模型去提取节点和边。
- 仅对现有 graph.json 重跑聚类：使用 Leiden 算法等对已有的图数据重新进行社区发现。
- 重新命名社区：根据新的聚类结果，为社区生成人类可读的标签（如“Attention Mechanism”），并更新 .graphify_labels.json 文件。
- 重新生成报告与可视化：最终会刷新 GRAPH_REPORT.md、graph.json 和 graph.html 这三个核心输出文件。

适用场景：当你调整了代码结构，或者想尝试不同的聚类粒度（比如用 --resolution 参数获得更细的社区划分）时，这个命令非常有用。

>问题：没有生成  graphify-out/graph.html
>raphify 的交互式 HTML 可视化（graph.html）为了性能考虑，默认`设置了 5,000 个节点`的硬性上限。当你的知识图谱节点数超过这个限制时，Graphify 会跳过生成 graph.html，并在控制台输出提示信息，例如：`Graph has N nodes - too large for HTML viz (limit: 5000)`。
>解决方法：提高可视化节点上限（推荐）
>通过设置环境变量 GRAPHIFY_VIZ_NODE_LIMIT，可以覆盖默认的 5,000 节点限制。将其设置得足够大，以容纳你的图谱节点数。
>```bash
 ># 例如，将上限提高到 200,000 个节点
 >export GRAPHIFY_VIZ_NODE_LIMIT=200000
 >
 ># 然后重新运行 cluster-only
 >graphify cluster-only /workspace2/opensource/linux
 >```

组合参数：
- --no-viz ：如果你不需要交互式图表，使用 --no-viz 标志即可跳过生成，直接获得报告和 JSON 数据。
- --node-limit：仍想要力导向图，但想控制规模，导出时限制节点数

2. 导出不同类型的文件
```bash
export callflow-html    emit Mermaid-based architecture/call-flow HTML
                          [GRAPH|DIR] [--graph PATH] [--labels PATH] [--report PATH] [--sections PATH] [--output HTML]
                          [--lang auto|zh-CN|en] [--max-sections N] [--diagram-scale N]
  export obsidian         emit Obsidian vault notes + canvas [--graph PATH] [--labels PATH] [--dir PATH]
  export wiki             emit wiki markdown articles [--graph PATH] [--labels PATH]
  export svg              emit graph.svg [--graph PATH] [--labels PATH]
  export graphml          emit GraphML [--graph PATH]
  export neo4j            emit Cypher or push to Neo4j [--graph PATH] [--push URI] [--user U] [--password P]
                          (or set NEO4J_PASSWORD instead of --password to keep it off argv)
  export falkordb         emit Cypher or push to FalkorDB [--graph PATH] [--push URI] [--user U] [--password P]
```

3. 查询节点
```bash
# 通过关键字 查询节点和边  
  query "<question>"       BFS traversal of graph.json for a question
    --dfs                   use depth-first instead of breadth-first
    --context C             explicit edge-context filter (repeatable)
    --budget N              cap output at N tokens (default 2000)
    --graph <path>          path to graph.json (default graphify-out/graph.json)
# 查询2个符号的最短路径  
  path "A" "B"            shortest path between two nodes in graph.json
    --graph <path>          path to graph.json (default graphify-out/graph.json)
# 查询符号的所有信息
  explain "X"             plain-language explanation of a node and its neighbors
    --graph <path>          path to graph.json (default graphify-out/graph.json)
``` 

4. 输出树状HTML页面文件，以树状显示所有子文件夹和文件内的符号
```bash
  tree                    emit a D3 v7 collapsible-tree HTML for graph.json
    --graph PATH            path to graph.json (default graphify-out/graph.json)
    --output HTML           output path (default graphify-out/GRAPH_TREE.html)
    --root PATH             filesystem root for the hierarchy
    --max-children N        cap children per node (default 200)
    --top-k-edges N         per-symbol outbound edges in inspector (default 12)
    --label NAME            project label in header
  extract <path>          headless full extraction (AST + semantic LLM) for CI/scripts
```

5. 安装到AI 终端，实际是为CLI加入一个使用graphify的skill。
```bash
  install [--platform P]  copy skill to platform config dir (claude|windows|codebuddy|codex|opencode|aider|amp|agents|claw|droid|trae|trae-cn|gemini|cursor|antigravity|hermes|kiro|pi|devin)
  uninstall               remove graphify from all detected platforms in one shot
```

6. 为当前项目的AGENT.md加入使用graphify的指引。
AGENTS.md 是一个正在形成的行业标准。它最初由 OpenAI 为 Codex 设计，随后被贡献给 Linux 基金会下的 Agentic AI Foundation (AAIF) 进行管理。其目标是提供一个统一、开放的格式，让不同的 AI 编程工具都能读取同一份项目说明。
```bash
  codex install           write graphify section to AGENTS.md (Codex)
  codex uninstall         remove graphify section from AGENTS.md
  opencode install        write graphify section to AGENTS.md + tool.execute.before plugin (OpenCode)
  opencode uninstall      remove graphify section from AGENTS.md + plugin
```

## graphify 的局限性

**1. deepseek调用graphify 后未实际使用**
我其实用了 graphify，但只用了一次就放弃了**

我跑了 `graphify query "how vmcore is loaded and parsed"`，返回的 62 个节点里绝大多数是：

- `load_module` 结构体的 ~40 条 `--defines-->` 字段边（mod_name、mod_symtable…）
- `vmcore.h`/`netdump.h` 的 `--imports-->`（#include 关系）

这些是「结构体字段 / 头文件包含」关系，**没有一条是 main→is_netdump→read_netdump 的函数调用边**。查询结果自己也提示了 "Narrow with context_filter=['call']"，但我没有跟进，直接跳去 grep/read 源码了——这一步是偷懒，不是正确做法。

**2. graph 里的「调用链」本身对函数指针无法正确解析**

刚才补做了验证：
```
$ graphify path "main()" "read_netdump()" --undirected
main() --calls [INFERRED]--> is_netdump() --calls [INFERRED]--> read_flattened_format() <--calls [INFERRED]-- read_netdump()
```
可以看到两个问题：
- 调用边是 `[INFERRED]`（启发式推断），不是从真实 CFG/符号解析出来的。
- crash 里真正的调用链是 **通过函数指针间接调用**：`main()` 里 `pc->readmem = read_netdump`（main.c:569），之后所有读内存都走 `readmem()` 这个钩子。AST/静态推断的调用图**捕获不到这种 `pc->readmem(...)` 的间接分发**，所以 `path` 只能绕经 `read_flattened_format` 找到一条 3 跳的旁路，而不是真实的 `main → 参数循环 → 设置 readmem → readmem() 间接调用 read_netdump`。

**3. 结论**

不是看不懂它的输出，而是：

1. 第一次 `query` 返回的是结构体字段/include 关系，没给出调用链，我该接着用 `--context_filter call` / `path` / `explain`，却跳过了；
2. 而 graph 的调用边是推断的，且对「函数指针分发」这类 crash 大量使用的模式（`readmem`/`writemem`/`machdep->process_elf_notes`/`machdep->dumpfile_init`）存在盲区，真正的完整调用链仍需要源码级核对。

所以正确的做法是 graphify 先做骨架（找到 `is_netdump`/`read_diskdump`/`vmcoreinfo_read_string` 等关键节点和所属社区），再用 grep/read 补齐函数指针分发那一段。

## graphify 原始skill 的改进

**对生效 skill 的改进**（`~/.config/opencode/skills/graphify/SKILL.md`，738 行）

- 新增 **Use graphify ONLY for**：未知符号导航 / 架构模块概览 / 跨文件跨仓关系 / wiki 定位。
- 新增 **Do NOT use graphify for**：调用链、已知符号定义引用、函数指针 ops 分发、rg 能几条命中的问题 → 全部交给 `code-nav`。
- 一句话规则：**知道符号 → code-nav；不知道符号 → graphify 定位后用 code-nav 核实**。
- 重写 Fast path：排除已知符号/调用链问题，不再无脑 query。
- 6 条强制 guard：
>1. 先 `reflect` 读 LESSONS.md
>2. 禁止把原始自然语言直接喂 `query`（先做 vocab 展开）
>3. 调用链优先 `path`/`--dfs`
>4. 噪音>50% 立即收窄
>5. **硬规则**：`calls` 边是 `INFERRED`，函数指针分发（`pc->readmem` 等）对图不可见，最终必须 grep/read 核实
>6. `save-result --outcome` 回写

演示闭环** — 用 `save-result --outcome dead_end` 把本次「vmcore 加载」查询标记为死路，再 `reflect` 后 LESSONS.md 已记下这条教训，下次会话会先读到并跳过这个错误路径。

效果验证：现在 `LESSONS.md` 里已有一条 `Known dead ends — "how vmcore is loaded and parsed"`，下次任何 agent 处理同类问题时，guard 第 1 条会先读到它，不会再重蹈覆辙。
