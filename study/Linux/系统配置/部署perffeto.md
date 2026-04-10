# 部署perffeto
下面是如何离线部署 **Perfetto UI（即 [https://ui.perfetto.dev/）](https://ui.perfetto.dev/）)** 的全面步骤与说明。Perfetto UI 本身是一个完全静态的前端应用 —— 你可以将它打包后部署到自己控制的服务器或在内网中使用，而不依赖 Google 官方托管的 ui.perfetto.dev。([博客园][1])

---

## 1. 准备条件

* 一台 **Linux（推荐 Ubuntu）服务器/虚拟机**（也可以用 Windows/macOS，但文档多数示例基于 Unix）。
* 安装 **Git**、**Python 3.7+**、**Node.js / npm/yarn** 等前端构建工具。
* 足够的内存与磁盘空间（编译 Perfetto UI 的源码可能较占用系统资源）。([博客园][1])

---

## 2. 获取 Perfetto 源代码

Perfetto UI 的源代码是开源的，你可以从官方仓库克隆：

```bash
git clone https://github.com/google/perfetto.git
cd perfetto
```

（Perfetto 也可以从 Android 的源代码树 `external/perfetto` 获取，但直接从 GitHub 更灵活。）([Perfetto][2])

---

## 3. 下载前端依赖

进入源码后，为 UI 构建环境安装依赖：

```bash
# 安装构建依赖，包括 Node/npm 和 Perfetto 所需的脚本
tools/install-build-deps --ui
```

该命令会下载所有 UI 构建需要的前端依赖。请确保你的环境可以访问 npm registry。([Perfetto][2])

---

## 4. 构建 Perfetto UI

在源码根目录下运行：

```bash
# 编译 Perfetto UI
ui/build
```

这会构建静态资源，包括 HTML、JS、CSS、WASM 等文件。构建完成后，静态文件通常会在一个 **`dist`** 或类似目录中生成。([博客园][1])

---

## 5. 本地测试运行（可选）

Perfetto 提供一个开发服务器用于测试：

```bash
ui/run-dev-server
```

默认服务监听 `localhost:10000`，你可以在浏览器访问它来验证构建是否成功。([博客园][1])

---

## 6. 离线部署到生产服务器

### 6.1 导出静态文件

构建完成后，你会看到类似以下文件结构（这是构建输出示例）：

```
dist/
├── index.html
├── manifest.json
├── service_worker.js
├── engine_bundle.js
├── frontend_bundle.js
├── trace_processor.wasm
├── traceconv.wasm
├── assets/...
└── ...
```

这些都是前端静态资源。([博客园][1])

### 6.2 部署静态文件

将这些静态文件上传到你自己的 Web 服务器（Nginx、Apache、Caddy、Lighttpd 等）或静态内容托管服务。 配置说明如下：

#### Nginx 示例配置

```nginx
server {
    listen 80;
    server_name perfetto-ui.local;

    root /path/to/perfetto-ui/dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

确保所有静态资源可以正确返回，并启用适当的缓存策略（尤其是 service worker 文件）。([博客园][1])

---

## 7. 使 UI 真正离线

Perfetto UI 使用 **Service Worker** 缓存资源，从而在首次访问后实现离线加载。这样用户即使断网，也可以继续打开已缓存的 UI 界面。([DeepWiki][3])

---

## 8. 避免访问 Google 内部服务（可选）

官方构建中可能仍然引用了某些 Google 内部脚本（例如 `storage.cloud.google.com/.../is_internal_user.js`）：

* 最简单：构建后手动删除或重写这些引用。
* 另一种：在构建源码前定位并注释掉相关代码，然后重新构建。([博客园][1])

---

## 9. 可选：使用 Electron 打包成桌面离线应用

如果你希望更加“完全离线”，可以将构建后的静态资源打包成 Electron 桌面应用：

1. 创建一个简单的 Electron 项目，将静态资源放入项目内部。
2. 配置 `main.js` 以加载本地 `index.html`。
3. 使用 Electron Builder 或类似工具打包为 Windows/Mac/Linux 二进制。

这种做法可以让 UI 在没有 Web 服务器的环境下运行。([博客园][4])

---

## 注意事项

* Perfetto UI 默认使用 WebAssembly（WASM）在浏览器中处理 Trace 数据，因此确保浏览器支持 WebAssembly。([DeepWiki][3])
* 构建时可能需要较高内存与 CPU 资源（尤其是首次安装依赖与编译）。([博客园][1])
* 如果部署在 HTTPS 环境下，可以实现 USB ADB 调试等高级功能（需要 HTTPS 证书配置）。([博客园][1])

---

如果你需要 **具体的构建命令脚本、Dockerfile 配置** 或 **Nginx 部署示例文件**，请告知你的目标环境与用途（如内网、生产站点、开发测试等），我可以进一步提供详细模板。

[1]: https://www.cnblogs.com/SupperMary/p/17575717.html?utm_source=chatgpt.com "如何离线部署perfetto ui - SupperMary - 博客园"
[2]: https://perfetto.dev/docs/contributing/build-instructions?utm_source=chatgpt.com "Perfetto build instructions - Perfetto Tracing Docs"
[3]: https://deepwiki.com/google/perfetto/6-profiling-tools?utm_source=chatgpt.com "User Interface | google/perfetto | DeepWiki"
[4]: https://www.cnblogs.com/arnoldlu/p/19265072?utm_source=chatgpt.com "Perfetto：离线版本和Electron打包桌面应用 - ArnoldLu - 博客园"
