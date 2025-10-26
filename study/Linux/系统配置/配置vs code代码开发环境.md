# ubuntu配置vs code代码开发环境

vs code的c/c++ 提供代码跳转和补全功能，但对于大型工程效率太低，下面的方法需要先禁用
该插件的C_Cpp.intelliSenseEngine功能。

在~/.config/Code/User/settings.json 全局配置文件中禁用：
`"C_Cpp.intelliSenseEngine": "disabled"`

## 使用global实现通用解析
1、安装 global
`sudo apt install global`
`sudo apt install universal-ctags`

2、在项目中生成数据库文件
`gtags --gtagslabel=universal-ctags`
会生成GPATH、GRTAGS、GTAGS 3个文件

3、配置vs code的环境
安装扩展：
* vscode-gnu-global
* vscode-gtags

在~/.config/Code/User/settings.json 中配置
```txt
{
  "global.executable": "/usr/bin/global",
  "global.updateOnSave": true,
  "global.autoUpdate": true
}
```

## 使用clangd配置C/C++
### 安装clang
`sudo apt install clangd`

###  生成compile_commands.json文件
#### 使用 CMake
如果工程用 CMake 构建：
`cmake -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON`
生成的文件在：build/compile_commands.json

#### 使用bear
安装bear
`sudo apt install bear`

编译并生成json
`bear -- make -j$(nproc)`

#### 使用 intercept-build
安装工具
`sudo apt install clang-tools`

编译并生成json
intercept-build make -j$(nproc)

#### Bazel / Ninja / QMake 等其他构建系统
* Bazel：可以用 bazel-compilation-database。
* Ninja：CMake 生成时一样可以加 -DCMAKE_EXPORT_COMPILE_COMMANDS=ON。
* QMake：用 qmake-compdb 生成。

#### 使用某些项目自带的方式
1、linux
在代码根目录中，先编译一次工程，然后执行
`./scripts/clang-tools/gen_compile_commands.py`
注意: 交叉编译无法使用该方法.
2、aosp
设置编译环境
 
 ```shell
 source build/envsetup.sh
lunch aosp_cf_x86_64_phone-bp2a-eng
```

启用COMPDB的功能，以生成编译数据库

```Shell
export SOONG_GEN_COMPDB=1
# Optional: for debug information
export SOONG_GEN_COMPDB_DEBUG=1
```

执行编译后，文件位于
`./out/soong/development/ide/compdb/compile_commands.json`

### vs code 中配置clangd
1、安装插件
安装 clangd、Clang-Format

2、配置
```txt
{
    "clangd.path": "/usr/bin/clangd",
    "clangd.arguments": [
        "--compile-commands-dir=${workspaceFolder}",
        "--background-index",
        "--pch-storage=memory"
    ]
}
```

### 交叉编译的项目
对于交叉编译，还需要配置.clangd文件，让clangd加载额外的头文件
在代码根目录下 添加.clangd，内容如下：
```txt
CompileFlags:
  Add:
    - -D__KERNEL__
    - -DCONFIG_ARM64
    - -I/home/cyx/mywork/code_study/linux_6_12/include
    - -I/home/cyx/mywork/code_study/linux_6_12/arch/arm64/include
```

## 使用ccls配置C/C++

1、安装插件 ccls
2、安装软件
`sudo apt install ccls`
3、在vs code 配置
```txt
{
    "ccls.launch.command": "/usr/bin/ccls",
    "ccls.cache.directory": ".ccls-cache",
    "ccls.launch.args": ["--log-file=/tmp/ccls.log"],
    "ccls.compilationDatabaseDirectory": "${workspaceFolder}",
}
```