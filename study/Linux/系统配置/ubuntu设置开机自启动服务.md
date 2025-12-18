# ubuntu设置开机服务
下面按**常见操作系统场景**，系统性说明 **Tomcat 设置为开机自启动** 的标准做法。请根据你的运行环境选择对应方案。

---

## 一、Linux（systemd，主流服务器环境，推荐）

### 1. 前提条件

* 已安装 JDK
* Tomcat 已解压（例如：`/opt/tomcat`）
* 以非 root 用户运行 Tomcat（推荐）

假设：

* Tomcat 目录：`/opt/tomcat`
* 运行用户：`tomcat`
* JAVA_HOME：`/usr/lib/jvm/java-17-openjdk`

---

### 2. 创建 systemd 服务文件

```bash
sudo vi /etc/systemd/system/tomcat.service
```

内容示例：

```ini
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

User=tomcat
Group=tomcat

Environment=JAVA_HOME=/usr/lib/jvm/java-17-openjdk
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

Restart=on-failure

[Install]
WantedBy=multi-user.target
```
//注意这里的User 请设置为实际用户名

---

### 3. 启用并启动服务

```bash
sudo systemctl daemon-reload
sudo systemctl enable tomcat
sudo systemctl start tomcat
```

---

### 4. 验证状态

```bash
systemctl status tomcat
```

---

## 二、Linux（SysV / rc.local，旧系统或简化方式）

### 使用 rc.local（不推荐，仅兼容老系统）

```bash
vi /etc/rc.local
```

添加：

```bash
/opt/tomcat/bin/startup.sh
```

确保可执行：

```bash
chmod +x /etc/rc.local
```

---

## 三、Windows（以服务方式运行，推荐）

### 1. 进入 Tomcat bin 目录

```bat
cd C:\tomcat\bin
```

---

### 2. 安装 Windows 服务

```bat
service.bat install
```

默认服务名：`Tomcat9` / `Tomcat10`

---

### 3. 设置开机自启动

```bat
services.msc
```

* 找到 **Apache Tomcat**
* 启动类型设为 **自动**

---

### 4. 启动服务

```bat
net start Tomcat9
```

---

## 四、Docker 场景（补充）

如果你是 **Docker 运行 Tomcat**：

```bash
docker run -d --restart=always tomcat
```

---

## 五、常见问题与排查

### 1. 服务启动失败

```bash
journalctl -u tomcat -xe
```

### 2. JAVA_HOME 未生效

* 不要依赖 `.bashrc`
* 必须在 `systemd service` 中显式设置

### 3. 端口占用

```bash
ss -lntp | grep 8080
```

---

## 六、推荐实践总结

| 场景         | 推荐方式                   |
| ---------- | ---------------------- |
| Linux 生产环境 | systemd 服务             |
| Windows    | Tomcat Windows Service |
| 测试/临时      | startup.sh             |
| 容器化        | Docker restart policy  |

---

如果你愿意，可以告诉我：

* 操作系统版本（如 CentOS 7 / Ubuntu 22.04 / Windows Server）
* Tomcat 版本
* 是否使用 root 或普通用户

我可以按你的实际环境给出**可直接复制执行**的配置。
