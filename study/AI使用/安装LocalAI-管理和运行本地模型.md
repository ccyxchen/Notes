# 安装LocalAI  - 管理和运行本地模型

## 安装方法
1、ocalAI直接运行在docker上，可以使用docker安装
```bash

docker run -ti --name local-ai -p 8081:8080   --device=/dev/dri   --group-add video   -v /workspace2/ollama/models:/models   --network ai-net --restart unless-stopped   localai/localai:latest-gpu-vulkan
```
参数解析：
`--network ai-net`   将容器加入到ai-net网络，这样就可以和其他容器互通网络。 
`docker network create ai-net` 创建网络
`--restart unless-stopped`  使容器在开机后自动启动
/models 是localAI的默认模型下载和安装路径

2、直接在本地安装
下载程序
[local-ai-v4.10.0-linux-amd64](https://github.com/mudler/LocalAI/releases/download/v4.10.0/local-ai-v4.10.0-linux-amd64)
放入一个独立的文件夹，首次启动会自动创建多个资源文件夹存放后端和模型。
运行：
```bash
chmod +x local-ai-v4.10.0-linux-amd64
./local-ai-v4.10.0-linux-amd64 --address "0.0.0.0:8081"
```
`--address "0.0.0.0:8081"`用于指定网站监听端口。

## yaml 示例
```yaml
backend: rocm-llama-cpp
context_size: 32768
description: Imported from file:///models/Qwen2.5-VL-7B-Instruct-abliterated.Q8_0.gguf
function:
    automatic_tool_parsing_fallback: true
    grammar:
        disable: true
known_usecases:
    - chat
mmproj: Spatial-Interactor-Qwen2.5-VL-7B.mmproj-Q8_0.gguf
name: Qwen2.5-VL-7B-Instruct-abliterated.Q8_0.gguf
options:
    - use_jinja:true
parameters:
    min_p: 0.1
    model: Qwen2.5-VL-7B-Instruct-abliterated.Q8_0.gguf
    repeat_penalty: 1
    temperature: 1.5
    top_k: -1
    top_p: 0.95
template:
    use_tokenizer_template: true

```

## rerank模型安装

rerank 模型 需要通过 hf 的镜像去加载，目前无法调通，改用加载本地GGUF文件，通过
llama-cpp 后端运行，yaml配置如下：
```yaml
backend: rocm-llama-cpp
description: Imported from hf://BAAI/bge-reranker-v2-m3
known_usecases:
    - rerank
name: bge-reranker-v2-m3
parameters:
    model: bge-reranker-v2-m3-Q8_0.gguf
reranking: true
```

> **在RAGFlow中，需要使用 OpenAI-API-Compatible 的供应商类型添加rerank 模型。**

## 设置开机启动

使用 systemd Socket 激活（按需启动）让 LocalAI 监听 8081 端口的完整步骤。
以下是使用 systemd Socket 激活（按需启动）让 LocalAI 监听 8081 端口的完整步骤。

### 🧠 核心机制：理解 Socket 激活

Socket 激活的核心是**分离“监听”与“服务”**。systemd 会先接管端口 8081 的监听，当第一个客户端连接到来时，systemd 才启动 LocalAI 进程，并将该连接的文件描述符传递给它。

这意味着 LocalAI 进程在无请求时可以完全退出，从而释放 GPU 和内存资源。

### 📁 步骤一：创建 Socket 单元文件

创建 `/etc/systemd/system/local-ai.socket`，让 systemd 负责监听 8081 端口：

```ini
[Unit]
Description=LocalAI API socket

[Socket]
ListenStream=8081
NoDelay=true

[Install]
WantedBy=sockets.target
```

> **关键参数**：`ListenStream=8081` 指定公开监听端口。`NoDelay=true` 禁用 Nagle 算法，降低交互延迟。

### ⚙️ 步骤二：创建 Service 单元文件

创建 `/etc/systemd/system/local-ai.service`，这是 LocalAI 的实际启动配置：

```ini
[Unit]
Description=LocalAI
After=network.target

[Service][Unit]
Description=LocalAI

[Service]
Type=simple
User=chenyx
Group=chenyx
ExecStart=/workspace2/localAI/local-ai-v4.10.0-linux-amd64 run
WorkingDirectory=/workspace2/localAI
```

**需要根据你的实际情况修改的字段：**

| 字段 | 说明 |
|---|---|
| `User` / `Group` | 运行 LocalAI 的系统用户，需对模型目录有读权限 |
| `ExecStart` | LocalAI 可执行文件的**绝对路径**，并带上 `run` 子命令 |
| `WorkingDirectory` | 模型和数据所在的工作目录 |

### 🔗 步骤三：配置 LocalAI 使用继承的 Socket

这是 Socket 激活的关键。当 systemd 启动 LocalAI 时，会通过环境变量传递一个已监听的 socket 文件描述符。LocalAI 会自动检测 `LISTEN_PID` 和 `LISTEN_FDS` 环境变量，并使用这个继承的 socket，**忽略 `LOCALAI_ADDRESS` 和 `--address` 参数**。

因此，你**不需要**在 service 文件中设置 `LOCALAI_ADDRESS=:8081`。systemd 传递的 socket 已经绑定在 8081 端口上，LocalAI 会自动使用它。

> **注意**：如果 LocalAI 检测到多个继承的 stream listener，它会**拒绝启动**，以避免绑定到错误的端点。确保 socket 文件中只定义了一个 `ListenStream`。

### ✅ 步骤四：启用并测试 Socket 激活

**1. 重新加载 systemd 配置**
```bash
sudo systemctl daemon-reload
```

**2. 启用并启动 socket（不是 service）**
```bash
sudo systemctl enable --now local-ai.socket
```

**3. 验证 socket 状态**
```bash
sudo systemctl status local-ai.socket
```
应看到 `Active: active (listening)`，表示 systemd 已在监听 8081 端口。

**4. 触发按需启动**
```bash
curl http://localhost:8081/v1/models
```
第一次请求会触发 systemd 启动 `local-ai.service`。systemd 会保持这个连接，直到 LocalAI 准备好接受它。

**5. 验证服务已启动**
```bash
sudo systemctl status local-ai.service
```

### 💡 验证清单

| 检查项 | 命令 | 预期结果 |
|---|---|---|
| Socket 是否监听 | `sudo systemctl status local-ai.socket` | `active (listening)` |
| 端口是否被 systemd 占用 | `sudo ss -tlnp \| grep 8081` | 显示 `systemd` 进程 |
| Service 是否按需启动 | `sudo systemctl status local-ai.service` | 首次请求后变为 `active (running)` |
| API 是否可达 | `curl http://localhost:8081/v1/models` | 返回模型列表 JSON |

### 停止localAI

```bash
# 如果使用了 socket 激活，先停止并禁用 socket
sudo systemctl stop local-ai.socket
sudo systemctl disable local-ai.socket

# 然后屏蔽服务，防止它被任何方式自动拉起
sudo systemctl mask local-ai.service

# 此时再停止服务
sudo systemctl stop local-ai.service
```
mask 会创建一个指向 /dev/null 的符号链接，彻底阻止服务被启动。需要恢复时执行 sudo systemctl unmask local-ai.service 即可。



## 注意事项

1、如果使用了其他版本的LocalAI容器，不能一直使用 ` -v /workspace2/ollama/models:/models`，因为/models 下包含之前的设置和容器，不能混用到其他版本的localAI。
2、自己下载的模型文件，需要使用网页的导入功能导入，会自动解析并设置
合适的参数，自己写的yaml 文件会出现奇怪的问题。

## 问题解决

### 安装后端和模型报错

```txt
failed to download backend "quay.io/go-skynet/local-ai-backends:latest-gpu-rocm-hipblas-diffusers": failed to download image tar: failed to extract uncompressed tar: write /tmp/localai-oci-1190542188.tar: disk quota exceeded
```
原因： /tmp 目录只有16GB，存储空间不够
解决：将 localAI 使用的/tmp 目录定位到本地存储路径
```bash
# 在/etc/systemd/system/local-ai.service的[Service]字段中加入
Environment="TMPDIR=/workspace2/localAI/tmp"
```

修改后，执行以下命令使配置生效：
```bash
sudo systemctl daemon-reload
sudo systemctl restart local-ai
```

### 使用时出现定屏

1. 首要尝试：调整ROCm运行时环境变量
在启动LocalAI的服务或容器时，添加以下环境变量，可以规避一些已知的驱动交互问题：
`HSA_ENABLE_SDMA=0`：这个变量会强制ROCm使用着色器（shader）进行数据拷贝，而不是系统DMA引擎。DMA引擎在某些APU或特定架构上可能导致内核挂起，这是ROCm社区中一个标准的规避方法。

2. 调整LocalAI自身配置
限制并发后端：将 `Max Active Backends` 设置为 1，可以避免多个ROCm进程同时访问GPU，减少驱动队列管理的压力。
启用内存回收：设置环境变量 `LOCALAI_MEMORY_RECLAIMER=true` 和 `LOCALAI_MEMORY_RECLAIMER_THRESHOLD=0.95`，可以让LocalAI在系统内存紧张时自动卸载模型，防止因OOM引发的连锁崩溃。

3. 修改内核启动参数（需要重启）
如果环境变量无效，可以尝试修改GRUB配置，添加内核启动参数来规避驱动缺陷。
- amdgpu.runpm=0：禁用GPU的动态电源管理。这虽然会增加一些待机功耗，但能有效避免因电源状态切换导致的冻结。
- amdgpu.aspm=0：同时禁用ASPM（主动状态电源管理），常与 runpm=0 配合使用。
- amd_iommu=on iommu=pt
在 iommu=pt 模式下：
> - 中断重映射仍然启用，保证了系统在多核环境下的稳定性。
> - I/O 地址转换被禁用，设备 DMA 直接使用物理地址，这可以规避一些因地址转换引发的性能开销或兼容性问题，同时保留了设备直通的基本能力。

操作步骤：
1、编辑 /etc/default/grub 文件。
2、在 GRUB_CMDLINE_LINUX_DEFAULT 行中，引号内添加参数，例如：
```text
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amdgpu.runpm=0 amdgpu.aspm=0 amd_iommu=on iommu=pt"
```
3、更新GRUB并重启：
```basa
sudo update-grub
sudo reboot
```

### 模型对话时重复输出卡死

它通常不是模型“坏了”，而是采样参数设置和上下文管理这两个关键环节需要调整。你提到写代码时不卡，是因为编程任务目标明确，而分析开放性问题时，模型更容易陷入“认知崩溃”的重复循环。

#### 🎯 根本原因：为什么模型会陷入“思考循环”？
模型在输出多个“thinking”步骤后开始重复，主要有以下几个原因：

- “贪婪解码”的陷阱：temperature（温度）设置过低（比如 OpenCode 默认的 0），会让模型每次都选择概率最高的词。这在需要确定性输出的代码任务中没问题，但在开放式分析中，一旦产生一个句子，模型会倾向于再次输出同样的句子，从而陷入循环。

- 上下文窗口过载：当对话历史过长，触及模型的上下文上限时，最早的对话会被“挤”出视野。模型只能看到自己最近重复的输出，于是会“镜像”这些内容，导致重复。你长时间分析问题，比短促的代码生成更容易触发这个情况。

- 模型自身的特性：ornith-1.5-9b-uncensored 这类模型，有报告指出其推理循环（reasoning loops） 问题较为突出，容易在思考链中反复自我质疑，直到耗尽输出预算。

- 缺乏“反重复”机制：默认的采样参数中没有开启 repeat_penalty（重复惩罚）或 presence_penalty（存在惩罚），模型没有动力去避免重复已出现过的内容。

#### 🛠️ 解决方案：从参数调整到上下文管理

你可以按照以下顺序逐一排查和调整：

##### 1. 调整采样参数（最直接的修复）

这是解决重复问题最关键的一步。你需要修改 OpenCode 的模型配置，或者在启动 LocalAI 时传递相关参数。

*   **提高 `temperature`**：这是首要任务。对于分析、写作等开放式任务，建议将温度设置在 **`0.7`** 左右。一些模型卡甚至建议 `1.0` 以获得更好的创造性。
*   **设置重复惩罚**：启用 `repeat_penalty`，建议值从 **`1.1`** 开始尝试。这能有效降低重复 token 的生成概率。
*   **配合其他惩罚**：可以考虑同时设置 `presence_penalty`（建议值 `1.5`）和 `frequency_penalty`，它们能进一步抑制内容重复。
*   **使用 `min-p` 采样**：`min-p` 是一种现代采样方法，可以动态调整候选词范围。建议从 **`0.05`** 开始设置。
*   **关键：禁用贪婪解码**：**务必确保 `temperature` 不为 `0`**。对于 Ornith 系列模型，有报告指出低温度反而会加剧循环问题。

**推荐的采样参数组合示例：**
```yaml
# 在 LocalAI 的模型配置 YAML 或启动参数中设置
temperature: 0.8
top_p: 0.95
min_p: 0.05
repeat_penalty: 1.1
presence_penalty: 1.5
```

##### 2. 管理上下文长度

如果调整参数后问题依然存在，就需要从上下文入手。

*   **开启 LocalAI 的上下文压缩**：LocalAI 提供了上下文压缩功能，当聊天请求达到模型 `context_size` 的一定比例（默认 `0.75`）时，会自动将较早的对话轮次压缩为摘要，从而释放空间。你需要在模型的配置文件中开启此功能。
*   **使用 OpenCode 上下文修剪插件**：可以安装如 `@bandonker/opencode-context-pruner` 之类的插件，它能以 token 为单位精确修剪上下文，去重并清除陈旧输出，有效控制上下文长度。
*   **手动管理会话**：最简单的办法是，在长分析任务中，定期请求模型总结当前对话的要点，然后开启一个新的聊天会话，并粘贴总结作为第一条消息，以此“重置”上下文。

##### 3. 模型与 OpenCode 特定配置

*   **为 OpenCode 创建专用 Agent**：不要使用默认配置。你可以为分析类任务创建一个新的 Agent，在配置文件中明确指定较高的 `temperature` 和 `repeat_penalty` 等参数。
*   **确保参数被正确传递**：需要在 OpenCode 的模型配置中，将 `temperature` 设为 `true`，以确保你设置的参数能覆盖默认值并传递给后端。
*   **考虑禁用思考模式**：对于 `Ornith-1.5-9B` 模型，其文档明确建议使用 `--reasoning off` 来预防思考模式下的循环问题。如果循环问题严重，可以尝试在 LocalAI 启动参数中加入此选项。

#### 💎 总结与建议操作顺序

建议你按以下顺序尝试，通常能解决大部分重复问题：

1.  **第一步（最快见效）**：**立即调高 `temperature` 到 `0.7` 或以上，并设置 `repeat_penalty` 为 `1.1`**。这是解决“贪婪解码”导致循环的最直接方法。
2.  **第二步**：如果问题依旧，为你的模型**开启 LocalAI 的上下文压缩**功能，或安装 OpenCode 的上下文修剪插件，以应对长对话场景。
3.  **第三步**：为分析任务**创建一个专用的 OpenCode Agent**，固化上述参数，避免每次手动调整。如果模型支持，尝试**禁用“思考模式”**。
