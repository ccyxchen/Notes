# ubuntu常见问题FAQ

- git status显示中文乱码

>Git 默认 core.quotepath = true，会把非 ASCII 字符（中文、日文、emoji 等）转义成八进制形式，例如：
>`"\346\265\213\350\257\225.txt"`
>设置为：
>```bash
 >git config --global core.quotepath false
 >```
>后，Git 不再转义，直接输出原始 UTF-8 字节。现代终端默认按 UTF-8 解码，所以你就看到了正常中文。

- ubuntu PDF显示异常

>  系统默认阅读器兼容性不强，使用Okular
> 
>  **Okular**
>- 核心功能：功能全面的万能文档查看器，支持 PDF、EPub、DjVu 等多种格式。其批注功能非常强大，支持高亮、下划线、自由文本、弹出式笔记、绘图等多种方式，甚至可以填写表单和添加数字签名。
>- 优点：功能丰富，批注工具专业，性能流畅，是许多 Linux 用户的首选阅读器。
>- 安装：`sudo apt install okular`
>- 适用场景：需要深度阅读、审阅和批注学术论文、技术文档或电子书的用户。

- ubuntu 快速笔记
>Simplenote：极致轻快的纯文本笔记
>- 同步方式：提供官方免费的云同步服务，无需自己配置，跨设备同步速度很快。
>- 安装方式：通过 Snap 安装非常方便：sudo snap install simplenote。
>- 适合人群：需要快速捕捉灵感、记录纯文本，且不希望折腾同步设置的用户。

