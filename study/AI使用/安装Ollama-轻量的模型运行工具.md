# 安装Ollama-轻量的模型运行工具

Ollama 用于运行本地模型，支持使用Rocm 显卡架构。

## 安装

>查看可用模型: [ollama library](https://ollama.com/library)

安装命令：
```bash
# 一键安装脚本
curl -fsSL https://ollama.com/install.sh | sh 
# 设置模型默认下载路径
执行 sudo systemctl edit ollama，在编辑器中添加以下内容
[Service]
Environment="OLLAMA_MODELS=下载路径"

保存后，执行 sudo systemctl daemon-reload 和 sudo systemctl restart ollama

# 拉取所需模型（共约 10GB）
ollama pull qwen2.5:7b        # 文本生成
ollama pull nomic-embed-text  # 向量嵌入
ollama pull qwen2.5vl:7b      # 图片与扫描 PDF 分析
```

## ollama 常用命令

* 导入本地模型
```bash
# 1. 下载 Q8_0 GGUF
huggingface-cli download Qwen/Qwen2.5-VL-7B-Instruct-GGUF \
  qwen2.5-vl-7b-instruct-q8_0.gguf \
  --local-dir ./models

# 2. 创建 Modelfile
cat > Modelfile << 'EOF'
FROM ./models/qwen2.5-vl-7b-instruct-q8_0.gguf
PARAMETER num_ctx 8192
EOF

# 3. 导入
ollama create qwen2.5vl:7b-q8_0 -f Modelfile

# 4. 运行
ollama run qwen2.5vl:7b-q8_0
```
* 显示可用模型
```bash
ollama list
# 应显示两个版本：
# qwen2.5vl:7b        6.0 GB   (Q4_K_M)
# qwen2.5vl:7b-q8_0   ~9.0 GB  (Q8_0)
```

## 迁移模型安装路径

1. 修改路径
执行 `sudo systemctl edit ollama`，在编辑器中添加以下内容
```ini
[Service]
Environment="OLLAMA_MODELS=/mnt/storage/ollama-models"
```
保存后，执行 : 
```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

2. 迁移已有模型
停止 Ollama 服务 (`sudo systemctl stop ollama`)，将旧目录 /usr/share/ollama/.ollama/models 下的内容移动到新路径。

3. 重启验证
启动服务 (sudo systemctl start ollama)，运行 ollama list 检查。