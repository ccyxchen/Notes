# 安装和更新ROCM

使用AMD RX6900XT 加速AI模型需要安装 ROCM 驱动。

## 安装

- 方法一：使用 amdgpu-install 脚本（官方推荐，最通用）

这是 AMD 官方推荐的安装和升级工具，其升级流程与首次安装完全相同，脚本会自动处理旧版本的替换。
1. 下载并安装最新版 amdgpu-install 工具
下载地址：[radeon.com](https://repo.radeon.com/amdgpu-install/)
在其中找到最新的软件版本和对应的ubuntu版本驱动下载并安装。
2. 执行升级安装
`sudo amdgpu-install --usecase=rocm`

- 方法二：使用 rocm-cli 工具

ROCm 官方推出了新的 rocm 命令行工具，可以更精细地管理安装和更新。
```bash
# 安装cli工具
sudo apt update
sudo apt dist-upgrade
sudo apt install rocm
sudo reboot

# 或者使用一键安装脚本
curl -fsSL https://raw.githubusercontent.com/ROCm/rocm-cli/main/install.sh | sh 
#安装程序会将 rocm 和 rocmd 二进制文件放入 ~/.local/bin，并自动将其添加到你的 shell PATH 中

# 检查更新并应用
rocm update --apply

# 查看当前安装状态
rocm examine
这个命令会检查你的 GPU、ROCm 安装情况以及框架兼容性，非常适合在升级前后进行诊断。
```

>为 RDNA 2 显卡应用必要的覆盖（针对 RX 6900 XT）
> RX 6900 XT 属于 RDNA 2 架构，并非 ROCm 官方正式支持的型号。为了让 ROCm 正确识别并使用它，必须设置 HSA_OVERRIDE_GFX_VERSION 环境变量.
> 永久设置（推荐）：将以下行添加到你的 ~/.bashrc 或 ~/.profile 文件末尾：
>```bash
 > export HSA_OVERRIDE_GFX_VERSION=10.3.0
 >```
