# 编程skill设计

**需要你在系统安装的工具（apt）：**

```bash
sudo apt-get install -y ripgrep global cscope
```

对应关系：
| 包名 | 提供 | 用途 |
|---|---|---|
| `ripgrep` | `rg` | 精确快速 grep（首选） |
| `global` | `gtags`/`global`/`htags` | C 交叉引用/调用引用 |
| `cscope` | `cscope` | C caller/callee 检索 |
| —（已装） | `universal-ctags` | 符号定义索引（你已有 6.2.1） |

---

## 设计框架

**工具排序（最便宜 → 最昂贵）**
1. clangd / LSP — 当存在 compile_commands.json 时，优先使用 opencode 的 LSP 工具进行定义 / 引用 / 调用层次查询。它具备配置感知和编译器级精度：是可用的最精确层。当没有编译数据库时，回退到下方的 shell 工具。
2. ripgrep (rg) — 对已知符号/模式进行精确的 file:line 命中。始终首先尝试。
3. GNU Global (gtags/global) — 交叉引用：global -x -r = 所有引用，global -d = 定义。
4. universal-ctags (readtags) — 精确的定义，包含种类/签名/行号（scripts/query.sh）。
5. cscope — 调用者/被调用者：-L3 调用者，-L2 被调用者，-L0 引用（scripts/callers.sh）。
6. graphify（path / explain / query，graphify-out/wiki/index.md）— 仅用于模块/社区/架构导航。

已装好 `rg 15.1.0`、`global/gtags/htags 6.6.14`、`cscope 15.9`（`ctags/readtags` 本就有），skill 已基于四件套重写。

**skill `code-nav`（`~/.config/opencode/skills/code-nav/`）**

```
SKILL.md            决策树 + 工具优先级 + 函数指针硬规则 + token 规则
scripts/index.sh    一份文件列表驱动三个索引（GTAGS/GRTAGS + .tags + cscope.out）
scripts/query.sh    定义查询（readtags 精确 kind/签名/行号）
scripts/refs.sh     全部引用（global -x -r）
scripts/callers.sh  调用者/被调者（cscope -L3/-L2）
```

**核心分工（比之前的 graphify-only 版本强在哪）**

| 问题类 | 工具  | 输出  |
| --- | --- | --- |
| 定义在哪 | `query.sh` | `read_netdump netdump.c:761 (签名)` |
| 谁调用它 | `callers.sh` | `read_kdump netdump.c:4074`、`handle_connection remote.c:324` |
| 全部引用 | `refs.sh` | 逐行 `file:line:context` |
| 函数指针分发 | `rg` 赋值模式 | `pc->readmem = read_netdump` |
| 陌生模块导航 | graphify | 社区/跨文件关系 |

**同步固化到项目：**

- `crash/.gitignore`：新增 `GTAGS GRTAGS GPATH gtags.files`（`cscope.*`、`.tags` 已有）
- `crash/AGENTS.md`：新增「Code navigation (precise symbol tools) vs graphify」一节，明确两类问题的分工，并加了一条 `calls` 边是 INFERRED、需回源码核实的规则
- 需重启 opencode 才能加载新 skill；索引在代码大改后跑 `bash scripts/index.sh .` 刷新即可。

## 对linux等大型项目的改进

**graphify 的 community/god-node 概览在大项目上退化成噪音**，6222 节点的 crash 图已经噪声大于信号，30M 行的 Linux 更不可能有「准确的概览」。但我要纠正一个方向：**「更强大精确的代码 RAG」对 Linux 不是更好的图，也不是更好的 embedding，而是下面这套（内核社区真在用的）**：

| 层   | 工具  | 为什么精确 |
| --- | --- | --- |
| 交叉引用 | **`make gtags` / `make cscope`**（kbuild 原生目标，`scripts/tags.sh`） | **config 感知**：只索引当前 `.config` 真正编译到的文件，天然排除无关架构/驱动，这是最关键的精度来源 |
| 语义级 | **clangd + `compile_commands.json`**（`make LLVM=1 compile_commands.json` 或 `scripts/clang-tools/gen_compile_commands.py`） | 编译器前端级 go-to-def / find-refs / call hierarchy，LSP 精确度天花板 |
| 词法兜底 | `rg` 的 `->ops` / `.open =` / `_initcall` 赋值模式 | 函数指针填表，连 clangd 都解不出，只有 grep 能命中 |
| 网页浏览 | **Elixir Bootlin**（elixir.bootlin.com/linux） | 本质就是 gtags+ctags+grep 的 xref 站点，内核社区事实标准 |
| 未知符号语义搜 | GitHub/Sourcegraph 代码搜索、embedding 检索 | 只用于「我不知道函数名」的模糊搜，精确调用链一律不靠它 |

**关键洞察**：Linux 的「准确概览」从来不是靠一个图得到的，而是靠「**config 感知的 xref 索引 + LSP 语义 + 词法 grep**」三条精确路径的组合。Elixir 就是这套东西的成品——它没有图，只有精确的 `file:line` 交叉引用。

### 结论与对 code-nav 的落地建议

- **graphify**：对 Linux 这类大仓，把它的「概览/社区」角色**换成 `make gtags` + clangd**。graphify 只适合中小型、你还不熟的代码库。
- **code-nav skill 升级方向**（针对 Linux）：检测到内核仓库时，自动改走 `make gtags`/`make cscope`（config 感知），有 `compile_commands.json` 则优先 clangd；函数指针类问题默认 grep `->ops`/`.open =`/`*_initcall` 填表模式。

**一句话**：对 Linux，「强大精确」= **config 感知的 gtags/cscope + clangd + grep**，不是 SVF，也不是任何图式 RAG。没有 embedding/图工具能给你比 Elixir 更准的 Linux 概览。

---

### 具体实现

**1. `scripts/index.sh` — 检测 + 双模式**

- 检测 kbuild 树：顶层 `Kconfig` + `scripts/tags.sh`（或 Makefile 里有 `gtags:`/`cscope:` 目标）
- **内核模式**（有 `.config`）：跑 `make gtags` / `make cscope`，**config 感知**（只索引当前配置真正编译的文件）
- 无 `.config` → 打印提示并优雅回退到列表模式
- 检测到 `compile_commands.json` → 提示优先走 clangd/LSP
- 列表模式（小/中型项目）行为不变，回归测试通过

**2. `scripts/ops.sh` — 新增，专治内核函数指针填表**

```
ops.sh <ROOT> <SYMBOL>      # SYMBOL 在哪被注册为回调
ops.sh <ROOT> --register    # 所有回调注册/initcall 点
ops.sh <ROOT> --invoke      # 所有 ops 结构调用点
```

实测：`ops.sh . read_diskdump` → 精确命中 `main.c:627`、`diskdump.c:1106` 的 `pc->readmem =` 赋值。

**3. `SKILL.md` 更新**

- 工具优先级新增**第 0 层 clangd/LSP**（有 compile_commands.json 时最优先）
- 新增「Kernel dispatch patterns」段：ops 结构填表 / initcall 注册 / ops 调用的完整 grep 模式
- 新增「Kernel / large-project mode」和「Large-repo guidance」段（含 SVF/CodeQL 在 Linux 上的限制、Elixir 定位）
