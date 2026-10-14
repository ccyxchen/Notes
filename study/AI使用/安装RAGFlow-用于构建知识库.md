# 安装RAGFlow  - 用于构建知识库

## 环境准备

- 安装系统依赖
```bash
sudo apt update
sudo apt install -y python3-pip python3-venv poppler-utils libreoffice
sudo apt install -y curl git git-lfs

# 安装docker
sudo apt install docker
# 安装完成后，建议将当前用户加入 docker 组，以便无需 sudo 即可运行 Docker 命令。
sudo usermod -aG docker $USER
# 执行后需要重新登录或重启系统才能生效
```

- 调整系统参数 (关键)：RAGFlow 依赖的 Elasticsearch 等组件需要较大的虚拟内存。请检查并设置 vm.max_map_count。
```bash
# 检查当前值
sysctl vm.max_map_count

# 如果值小于 262144，执行以下命令临时设置
sudo sysctl -w vm.max_map_count=262144

# 为了永久生效，编辑 /etc/sysctl.conf 文件，添加以下行
# vm.max_map_count=262144
# 然后运行 sudo sysctl -p 使配置生效
```

## 安装RAGFlow

官方推荐通过克隆仓库并使用 Docker Compose 来启动服务，这样可以获取必要的配置模板。
1、克隆仓库并进入目录：
```bash
git clone https://github.com/infiniflow/ragflow.git
cd ragflow
```
2、（可选）切换稳定版本：仓库默认在 dev 分支，建议切换到最新的稳定版本（例如 v0.16.0），以获得更好的稳定性
3、启动 RAGFlow 容器：
`docker compose -f docker/docker-compose.yml up -d`
该方法启动的容器，在电脑重启后会自动重新启动，因为 配置中设置了restart: unless-stopped
的启动方式。
`docker/docker-compose.yml:71:    restart: unless-stopped`
常用的重启策略：

|策略|含义|
| --- | --- |
|no|默认，不自动重启
|always|无论退出原因，总是自动重启，开机也会启动
|unless-stopped|总是重启，除非你手动 docker stop 过它
|on-failure|仅在非正常退出（退出码非0）时重启

一般个人使用推荐 always 或 unless-stopped。

- ### 启动问题解决

报错：
```txt
Error response from daemon: failed to set up container networking: driver failed programming external connectivity on endpoint docker-ragflow-cpu-1 (32490b6f14feba55f8b9fa2f2bcdee57fe1b56f951757ea74bf776ecbce6e3ed): error while calling RootlessKit PortManager.AddPort(): cannot expose privileged port 80, you can add 'net.ipv4.ip_unprivileged_port_start=80' to /etc/sysctl.conf (currently 1024), or set CAP_NET_BIND_SERVICE on rootlesskit binary, or choose a larger port number (>= 1024): listen tcp4 0.0.0.0:80: bind: permission denied
```
这个报错的核心原因是，你正在以 Rootless 模式（非 root 用户）运行 Docker，而 Linux 系统默认禁止非 root 进程绑定小于 1024 的特权端口（如 80 端口）。
- 修改 RAGFlow 的端口映射
这是最稳妥、侵入性最小的方法。将宿主机上使用的 80 端口改成一个大于 1024 的端口（如 8880），容器内部的 80 端口保持不变。
1、编辑 docker-compose.yml 文件：
找到 docker/docker-compose.yml 文件，找到 ports 配置部分。
2、修改端口映射：
将 - 80:80 修改为 - 8880:80。
```diff
diff --git a/docker/.env b/docker/.env
index a933326bf..8fc0e1588 100644
--- a/docker/.env
+++ b/docker/.env
@@ -228,7 +228,7 @@ JAEGER_UI_PORT=16686
 
 # The port used to expose RAGFlow's HTTP API service to the host machine,
 # allowing EXTERNAL access to the service running inside the Docker container.
-SVR_WEB_HTTP_PORT=80
+SVR_WEB_HTTP_PORT=8880
```
> 注意：更新配置后，需要重新启动所有容器才能生效。

3、重启服务：
` docker compose -f docker/docker-compose.yml up -d`

4、验证服务状态：首次启动需要下载镜像并初始化，可能需要几分钟。你可以通过以下命令查看日志，确认服务是否正常运行。
`docker logs -f ragflow-server`

当看到服务正常启动的日志后，在浏览器中访问 http://localhost:8880 即可打开 RAGFlow 的 Web 界面。

* **443端口报错**
调整内核参数，允许非特权端口绑定
>解决方案：使用 /etc/sysctl.d/ 目录
>正确的做法是将配置放到 /etc/sysctl.d/ 目录下的一个 .conf 文件里。这个目录是 systemd-sysctl 在启动时会主动扫描并加载的。
>操作步骤：
>1、创建独立的配置文件（推荐用 99- 前缀，确保在其他配置之后加载，避免被覆盖）：
> ```bash
 >echo 'net.ipv4.ip_unprivileged_port_start=443' | sudo tee /etc/sysctl.d/99-unprivileged-port.conf
 >```
>2、让当前系统立即生效（无需重启）：
>`sudo sysctl --system`
>3、验证当前值：
>`sysctl net.ipv4.ip_unprivileged_port_start`
>应该输出 net.ipv4.ip_unprivileged_port_start = 443。
>4、重启并再次验证，确认配置在开机后自动生效。

* **memory_lock 导致权限问题**
```txt
 ✔ Container docker-ragflow-cpu-1 Started                                                       0.1s
Error response from daemon: failed to create task for container: failed to create shim task: OCI runtime create failed: runc create failed: unable to start container process: error during container init: error setting rlimits for ready process: error setting rlimit type 8: operation not permitted
```

Docker 在创建容器时，仍然会尝试按照 docker-compose.yml 里的 ulimits 配置去设置进程的资源限制。只要 ulimits 里还有 memlock 相关的条目，Docker 守护进程就会因为权限不足而报出 error setting rlimit type 8 错误。

🛠️ 核心操作：彻底移除 ulimits
```diff
diff --git a/docker/docker-compose-base.yml b/docker/docker-compose-base.yml
index 751451035..1a4556627 100644
--- a/docker/docker-compose-base.yml
+++ b/docker/docker-compose-base.yml
@@ -24,10 +24,10 @@ services:
       - cluster.routing.allocation.disk.watermark.high=3gb
       - cluster.routing.allocation.disk.watermark.flood_stage=2gb
     mem_limit: ${MEM_LIMIT}
-    ulimits:
-      memlock:
-        soft: -1
-        hard: -1
+    #ulimits:
+    #  memlock:
+    #    soft: -1
+    #    hard: -1
```

## 配置本地模型（以localAI为例）

进入 RAGFlow 的 Web 界面进行配置。

1. 进入模型供应商设置：点击右上角的头像，在菜单中选择“模型供应商”。
搜索localAI 供应商,点击“添加模型”按钮。
2. 配置模型参数：
基础 URL：填写 http://你的IP:localAI的端口  来让容器访问宿主机服务。
API-Key：留空即可。
填写完毕后点击“确定”。
点击验证按钮，会自动获取可用的模型列表，在列表中添加需要的模型即可。
3. 设置系统默认模型
为了让 RAGFlow 的知识库和对话功能正常工作，你需要指定默认使用的模型。
在 RAGFlow 界面中，进入“系统模型设置”页面。
将你刚刚添加的 Chat 模型（如 deepseek-r1:7b）设为默认的对话模型。
将 Embedding 模型（如 bge-m3）设为默认的嵌入模型。这一步至关重要，因为嵌入模型负责将你的文档转化为向量，是 RAG 检索的基础。

### reranker模型配置

> 注意：reranker 类型的模型无法通过这个方法安装，需要使用 OpenAI-API-Compatible 的类型。
>- 搜索OpenAI-API-Compatible 供应商,点击“添加模型”按钮。
>- 基础 URL：填写 http://你的IP:localAI的端口/v1 来让容器访问宿主机服务。
>- API-Key：留空即可。
>- 点击模型列表 按钮，会自动列出可用模型，点击模型+ 键添加即可。
>- 使用这种方式无法识别出模型准确的类型和上下文大小，需要点击模型
>的设置按钮修改为正确数值。

完成以上步骤后，你就可以在 RAGFlow 中创建知识库、上传文档，并使用你配置的本地模型进行问答了。

## 停止RAGFlow
`docker compose -f docker/docker-compose.yml down`

## RAGFlow 知识库索引设置

RAGFlow解析器的“内置选项”主要分为两个层面：**“解析器（Parser）”** 和 **“分块方法（Chunk Method）”**。它们共同决定了文档如何被“读懂”并切分成适合检索的知识块。

### 📄 PDF解析器 (Parser) 选项

这是你之前处理水印问题时接触到的核心设置。它主要针对PDF文件，决定采用什么“视觉模型”来执行**OCR（文字识别）、TSR（表格结构识别）和DLR（版面识别）** 任务。其下拉菜单包含以下选项：

*   **DeepDoc（默认）**：RAGFlow的默认视觉模型，功能最强，能处理扫描件、复杂排版、表格和图片。缺点是**耗时较长**，资源消耗大。
*   **Naive（朴素）**：**纯文本PDF的加速选项**。它**跳过**OCR、TSR和DLR所有视觉任务，直接提取文字，速度极快。**前提是PDF必须是电子版（文字可选中）**，否则会提取失败。
*   **MinerU（实验性）**：一个开源工具，将PDF转换为机器可读格式。适合处理复杂版面，需要额外部署MinerU服务。
*   **Docling（实验性）**：另一个用于生成式AI的开源文档处理工具，作为替代的视觉模型选项。
*   **OpenDataLoader（实验性）**：一个确定性的、本地优先的PDF解析器，输出结构化JSON和Markdown，作为独立服务运行，无需Java环境。
*   **第三方视觉模型**：你可以接入自己配置的VLM（视觉语言模型）提供商来解析PDF。

> **注意**：PDF解析器下拉菜单**仅在选择了与PDF兼容的分块方法时才会出现**，如General、Manual、Paper、Book等。

### ✂️ 内置分块方法 (Chunk Method)

这是另一个维度的“内置选项”，在数据集配置的“解析类型”下选择，决定了文本被切分成知识块的**策略和模板**。RAGFlow提供了多种模板以适应不同文档布局。

| 分块模板 | 描述 | 兼容文件格式 |
| :--- | :--- | :--- |
| **通用 (General)** | 根据预设的分块Token数量连续进行分块，适用于大多数文档。 | PDF, DOCX, TXT, MD, HTML等 |
| **问答 (Q&A)** | 检索相关信息并生成答案以回应问题，适用于FAQ或问答对数据。 | XLSX, CSV, TXT |
| **简历 (Resume)** | 仅限企业版，用于解析简历。 | DOCX, PDF, TXT |
| **手动 (Manual)** | 手动模式，可能提供更高的控制权。 | - |
| **表格 (Table)** | 使用TSI技术进行高效的数据解析，适用于表格数据。 | XLSX, CSV, TXT |
| **论文 (Paper)** | 针对学术论文的排版和结构进行优化。 | DOCX, PDF, TXT |
| **书籍 (Book)** | 针对书籍的章节结构进行优化。 | DOCX, PDF, TXT |
| **法律 (Laws)** | 针对法律文档的条款结构进行优化。 | DOCX, PDF, TXT |
| **演示文稿 (Presentation)** | 针对PPT等演示文稿的布局进行解析。 | PDF, PPTX |
| **图片 (Image)** | 对图片文件进行OCR文字提取。 | JPEG, PNG, TIF, GIF |
| **整篇 (One)** | 每个文档作为一个整体（一个块）进行分块，不进行切分。 | DOCX, XLSX, PDF, TXT |
| **标签 (Tag)** | 该数据集用作其他数据集的标签集。 | XLSX, CSV, TXT |

### ⚙️ 解析器配置 (Parser Config) 参数

在选择了解析器和分块方法后，还可以进一步微调`parser_config`中的参数，这些参数会影响分块和检索的细节。以下是一些关键参数：

*   **`chunk_token_num`**：目标分块大小（以Token计），默认值通常为`128`或`512`。控制每个知识块的文本量。
*   **`delimiter`**：用于切分文本的分隔符，默认值包括`\n!?。；！？`等。可根据文档的语言和结构自定义。
*   **`parent_child`**：父子分块设置。启用后，每个块会进一步拆分为更小的子块，检索时先用子块精准匹配，再返回父块提供上下文，能有效提升检索精度。
*   **`table_context_size` / `image_context_size`**：为表格和图片附加的周围文本上下文大小（Token数），有助于提升图表内容的检索召回率。

总结来说，**解析器（Parser）** 解决的是“如何看懂PDF”（尤其是有无复杂版面），而 **分块方法（Chunk Method）** 解决的是“如何切分文本”。两者结合，再通过`parser_config`进行微调，才能为你的知识库构建出最合适的检索基础。

