# wsl如何新建和挂载虚拟磁盘（vhdx）

## Windows中新建虚拟磁盘

1、打开磁盘管理，选择 操作 -> 创建 VHD
![1](/tmpimage/20230618110525.png)

然后重启计算机解除占用

2、重启后管理员运行powershell，挂载并格式化磁盘

```Shell
@ps运行
# Windows 加载虚拟磁盘
Write-Output "\\.\PhysicalDrive$((Mount-VHD -Path G:\workspace.vhdx -PassThru | Get-Disk).Number)"
-> \\.\PhysicalDrive5

# 挂载到wsl
wsl --mount \\.\PhysicalDrive5
```

@wsl运行
查看挂载设备
`lsblk`
![2](/tmpimage/20230618111051.png)

磁盘为sde，格式化为ext4格式
`mkfs.ext4 /dev/sde`

## 设置开机自动挂载

1、windows默认不允许允许powershell脚本，需设置允许

想了解 计算机上的现用执行策略，打开PowerShell 然后输入 get-executionpolicy
![3](/tmpimage/20230618111441.png)

以管理员身份打开PowerShell 输入 set-executionpolicy remotesigned
![4](/tmpimage/20230618111510.png)
然后就可以允许了

2、Windows 管理员允许程序会每次弹出确认框，每次开机弹出很烦，要禁用
Win + r运行 gpedit.msc
![5](/tmpimage/20230618111819.png)

3、设置脚本自动挂载

```BAT
#wsl_mount.bat

@echo off
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
goto UACPrompt
) else ( goto gotAdmin )
:UACPrompt
echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
"%temp%\getadmin.vbs"
exit /B
:gotAdmin
if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
pushd "%CD%"
CD /D "%~dp0"

powershell D:\wsl\wsl_mount1.ps1

#wsl_mount.ps1

Write-Output "\\.\PhysicalDrive$((Mount-VHD -Path G:\workspace.vhdx -PassThru | Get-Disk).Number)"
wsl --mount \\.\PhysicalDrive5 --name workspace
```

将wsl_mount.bat加入到开机启动项
Win + r运行 shell:startup，将wsl_mount.bat脚本复制到打开的文件夹下。
