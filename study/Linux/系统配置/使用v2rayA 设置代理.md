# 使用v2rayA 设置代理

在 Ubuntu 上让 v2rayA 开机自动运行指定代理分组，核心在于两步：**先将 v2rayA 服务设为开机自启，再在 Web 界面中配置好代理分组并启动它**。v2rayA 会记忆你退出时的代理状态，并在下次启动时自动恢复。

### 🔧 第一步：安装 v2rayA

推荐通过官方 APT 源安装，便于后续管理和自启动配置。

1. **添加官方 GPG 密钥和软件源**（适用于 Ubuntu 22.04 及更新版本）：
   ```bash
   wget -qO - https://apt.v2raya.org/key/public-key.asc | sudo tee /etc/apt/keyrings/v2raya.asc
   echo "deb [signed-by=/etc/apt/keyrings/v2raya.asc] https://apt.v2raya.org/ v2raya main" | sudo tee /etc/apt/sources.list.d/v2raya.list
   sudo apt update
   ```
   > **注意**：如果系统提示 `/etc/apt/keyrings` 目录不存在，请先执行 `sudo mkdir -p /etc/apt/keyrings` 创建目录。

2. **安装 v2rayA 及内核**：
   ```bash
   sudo apt install v2raya v2ray
   ```

### 🚀 第二步：设置开机自动运行特定代理分组

**1. 启动服务并设为开机自启**
```bash
sudo systemctl start v2raya.service
sudo systemctl enable v2raya.service
```
执行 `enable` 后，v2rayA 服务就会在系统启动时自动运行。

**2. 在 Web 界面配置代理分组**
打开浏览器访问 `http://localhost:2017`，首次访问需创建管理员账户。
- **导入节点**：在界面中导入你的订阅链接或节点信息。
- **创建/选择分组**：在节点标签页中，选择一个或多个节点点击“选择”按钮，即可将它们组合成一个代理分组。

**3. 启动代理分组**
在选择好节点后，**点击左上角的“启动”按钮**（就绪状态图标会变蓝）。v2rayA 会记住这个启动状态。

**4. 验证自动恢复**
执行 `sudo reboot` 重启系统。开机后再次访问 `http://localhost:2017`，你应该会看到之前选择的代理分组已处于**自动启动**状态。

### ⚠️ 关键修复：解决重启后代理未自动启动的问题

部分用户反馈，即使设置了开机自启，重启后代理仍可能未运行。这通常是因为 systemd 默认的 `KillMode=control-group` 在关机时误杀了 v2rayA 的子进程，导致状态未能正确保存。

**解决方法**：创建一个 systemd 配置重写文件，将 KillMode 改为 `process`。

```bash
sudo mkdir -p /etc/systemd/system/v2raya.service.d/
sudo tee /etc/systemd/system/v2raya.service.d/fix-killmode.conf > /dev/null <<'EOF'
[Service]
KillMode=process
EOF
sudo systemctl daemon-reload
sudo systemctl restart v2raya
```

### 🔍 故障排查

如果重启后代理仍未自动启动，可按以下步骤检查：

1. **检查服务状态**：
   ```bash
   sudo systemctl status v2raya.service
   ```
   确认输出中包含 `Active: active (running)`。

2. **查看日志定位问题**：
   ```bash
   sudo journalctl -u v2raya.service -b
   ```
   查看本次启动的日志，寻找可能的错误信息。

3. **确认代理分组已选中**：
   登录 Web 界面，检查节点是否仍处于蓝色（已启动）状态。如果变为柚红色（未启动），手动点击启动按钮即可。

4. **验证代理端口**：
   v2rayA 启动后通常会开放 `20170` (SOCKS5) 和 `20171` (HTTP) 端口，可用 `ss -tlnp | grep 2017` 检查端口是否在监听。