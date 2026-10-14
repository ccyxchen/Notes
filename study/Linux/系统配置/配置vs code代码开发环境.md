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
安装 clang编译器，然后用clang 交叉编译
```bash
# 1、安装必要的工具链
# 以 Ubuntu/Debian 为例
sudo apt update
sudo apt install -y clang lld llvm \
                    gcc-aarch64-linux-gnu \
                    make bc bison flex libssl-dev libelf-dev
                    
# 2、配置内核 -- 配置内核时，必须同时指定 ARCH、CC 和 CROSS_COMPILE 变量
# 使用 Clang 进行 ARM64 的默认配置 (defconfig)
make ARCH=arm64 CC=clang CROSS_COMPILE=aarch64-linux-gnu- defconfig

# 3、使用 Clang 编译内核
# 编译时，推荐使用 LLVM=1 这个简写，它会自动将 LD、AR、NM 等工具全部替换为对应的 LLVM 版本，比手动指定每个变量更方便。
# 使用 LLVM=1 进行交叉编译
# 如果你的 LLVM 工具不在 PATH 中，可以用 LLVM=/path/to/llvm/ 指定
make ARCH=arm64 LLVM=1 -j$(nproc)

# 4、生成 compile_commands.json
# 使用 Clang 编译的一个核心优势是生成的 compile_commands.json 与 clangd 兼容性极佳，能有效避免 GCC 编译时产生的“Unknown argument”错误。
# 可以在编译命令中直接加入 compile_commands.json 作为目标：
# 编译内核并同时生成 compile_commands.json
make ARCH=arm64 LLVM=1 -j$(nproc) all compile_commands.json
```

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

### .clangd 配置文件
即使使用 Clang 编译，clangd 仍可能遇到个别无法识别的参数。你可以在项目根目录创建一个 .clangd 配置文件，让 clangd 忽略这些参数，确保代码索引和跳转功能完全正常。

- 为 ARM64 交叉编译配置 clangd
这是最关键的一步，目的是让 clangd 知道它在分析的是 ARM64 代码，并找到正确的系统头文件。
创建 .clangd 配置文件：在内核源码根目录下创建一个名为 .clangd 的文件（YAML 格式）。
配置 --query-driver：这是解决交叉编译下找不到标准头文件（如 stdint.h）问题的关键。你需要将交叉编译器的完整路径传递给 clangd。例如：
```yaml
# .clangd 文件内容
CompileFlags:
  CompilationDatabase: build # 如果 compile_commands.json 在 build 目录
  Add:
    - --target=aarch64-linux-gnu
    - --sysroot=/usr/aarch64-linux-gnu
  Remove:
    - -mabi=lp64 # 移除可能冲突的参数
```
由于 compile_commands.json 是基于 GCC 生成的，其中一些参数 clangd 无法识别。你可以在 .clangd 文件的 CompileFlags.Remove 部分将它们移除。

---

#### 解决 armv7a 报错

使用clangd 解析 t402 的preloader 出现报错
```txt
[13:29:12.385] Could not build a preamble for file /home/chenyx/workspace/t402_v/vendor/mediatek/proprietary/bootable/bootloader/preloader/platform/mt6768/src/drivers/bmt.c version 1: CreateTargetInfo() return null                                                            E[13:29:12.385]   error: unknown target CPU 'armv7-a'                                         I[13:29:12.385] --> workspace/semanticTokens/refresh(1) 
```

原因是 preloader 使用的是gcc ，clang编译器不识别 armv7-a， 需要在.clangd 强制指定  target
```yaml
CompileFlags:
  Compiler: clang
  Add:
    - --target=armv7a-none-eabi
    - -mfloat-abi=softfp
    - -mfpu=vfpv4
```

#### 解决参数不兼容

某些gcc参数无法被clang识别，需要通过 remove 将它们移除，找到不兼容参数的方法：
使用脚本检测
                                                                 
```bash
python3 tools/analyze_compile_commands.py \
vendor/mediatek/proprietary/bootable/bootloader/preloader/compile_commands.json \
prebuilts/clang/host/linux-x86/clang-r510928/bin/clang \
armv7a-none-eabi
```

脚本逻辑：                                                                                                                                                                                         
1. 从 compile_commands.json 取编译命令                                                         
2. 替换编译器为 clang --target=...，加 -fsyntax-only 只做语法检查                              
3. 收集 clang 报的 unknown argument                                                            
4. Remove 后复测验证                                                                           
5. 自动生成 .clangd 建议（交互式可选写入）

##### 构建通用.clangd
由于 不兼容的参数在特定的clang 版本是固定的，我们可以设置一个通用的.clangd 文件，将不兼容
参数 和clang下会报错的语法警告写入，这样在所有项目上都可用。
 .clangd 的 Remove 列表里即使包含某项目不存在的参数，clangd 也只是跳过（no-op），不会报错。

通用.clangd:`/workspace2/tools/scripts/.clangd.universal`
```bash
# 复制到任意项目根目录/子目录，改 --target 一行即可
cp .clangd.universal vendor/mediatek/proprietary/bootable/bootloader/lk/.clangd
# 然后把 --target=armv7a-none-eabi 改成该项目实际 target
```
 > 覆盖范围

| 类别 | 处理方式 |
|------|---------|
| A: GCC 专有 CLI 参数（`unknown argument`，~40 个） | `Remove` |
| B: GCC 专有 `-W` 参数（`unknown warning option`，~33 个） | `-Wno-unknown-warning-option` 统一屏蔽 + `Remove` 兜底 |
| C: clang 15+ 默认 error 的 6 类（`int-conversion` 等） | `-Wno-error=...` |
| 嵌入式常见 warning 噪音 | `-Wno-...` |

> 局限性

- **target 需手改**：ARM32（`armv7a-none-eabi`）、ARM64（`aarch64-none-elf`）、x86 各不同
- **不能保证 100% 覆盖**：clang 版本升级可能新增 default-as-error，新项目可能有新 GCC 参数
- **保险做法**：每换一个新模块，跑一次 `probe_incompatible_flags.py` 扫一遍，把新增的不兼容参数补进 `Remove`

### vs code 中配置clangd
1、安装插件
安装 clangd、Clang-Format

2、配置 `~/.config/Code/User/settings.json`

```txt
{
    "clangd.path": "/usr/bin/clangd",
    "clangd.arguments": [
        "--compile-commands-dir=${workspaceFolder}",
        "--background-index",
        "--pch-storage=memory",
        "--query-driver=/usr/bin/aarch64-linux-gnu-gcc",
        "--clang-tidy"
    ]
}
```
交叉 GCC 工具链（如 aarch64-linux-gnu-gcc）在安装时，就已经配置好了目标平台的头文件搜索路径。你可以通过以下命令看到这些路径：
`aarch64-linux-gnu-gcc -E -v -x c /dev/null`
clangd 的 --query-driver 就是让 clangd 自动运行这个命令，解析出这些路径和宏，然后应用到代码分析中。这样 clangd 才能找到 stdint.h 等头文件，避免报“找不到头文件”的错误。

#### 🧱 Linux 内核不依赖 libc 和系统头文件

普通用户空间程序（比如一个 ARM64 的 `hello` 程序）需要：
- glibc 提供的 `stdio.h`、`stdlib.h` 等
- 动态链接器、启动文件（crt0.o）
- 这些位于交叉工具链的 sysroot 中，如 `/usr/aarch64-linux-gnu/include`

而 Linux 内核：
- **不使用 libc**，它自己实现所有底层功能。
- 编译时使用 **`-nostdinc`**，明确告诉编译器“不要搜索标准系统头文件”。
- 通过 `-I`、`-isystem` 指定内核自己的头文件目录（如 `include/`、`arch/arm64/include/`）。
- 所有类型定义（如 `u32`、`size_t`）都由内核头文件或编译器内置头文件提供。

因此，`/usr/aarch64-linux-gnu/include` 里的东西对内核编译毫无用处，Clang 不知道它在哪里也完全不影响。

#### ⚖️ 对比：什么时候才需要 `--query-driver` 或 sysroot？

| 场景 | 是否需要 ARM64 系统头文件 | 是否需要 `--query-driver` |
| :--- | :--- | :--- |
| **编译 Linux 内核** | ❌ 不需要（内核自包含） | ❌ 通常不需要 |
| **编译用户空间 ARM64 程序** | ✅ 需要（glibc 头文件） | ✅ 需要，或手动指定 sysroot |
| **clangd 分析内核代码** | ❌ 不需要（内核不用 libc） | ❌ 通常不需要，因为 `compile_commands.json` 已含所有 `-I` 路径 |

之前提到“普通 Clang 安装没有为 ARM64 配置系统头文件路径”，那是针对**用户空间交叉编译**的。你的内核编译场景是特例，所以 Clang 能直接工作。

#### 配置参数
|参数	| 作用 | 建议
| --- | --- | --- |
|--query-driver | 不是用来编译代码的，而是让 clangd 向指定的编译器“打听”交叉编译环境的系统头文件路径和内置宏定义。 |  即使你编译时用 Clang，clangd 在分析代码时仍然需要这些信息才能正确理解 ARM64 的目标环境。
| --compile-commands-dir=${workspaceFolder} |	告诉 clangd 去哪里找 compile_commands.json。默认会在源文件所在目录向上查找；如果是 out-of-tree 构建，数据库在 build/ 目录，就必须显式指定。	| 若 compile_commands.json 在源码根目录可省略；否则写成 ${workspaceFolder}/build。
|--background-index |	开启后台索引，让 clangd 在后台扫描整个项目，建立全局符号表，从而支持跨文件跳转、补全和重命名。大型项目强烈建议开启。	| 显式开启更稳妥，会消耗一些 CPU 和内存。
|--pch-storage=memory | 指定预编译头（PCH）存储在内存中，加快索引和响应速度，但会增加内存占用。可选 disk 或 memory。	| 内存充足时用 memory 更快；内存紧张时用 disk。
|  "--clang-tidy" | 在 clangd 的代码分析中集成 clang-tidy 静态检查。 | 开启后，clangd 不仅提供语法/语义分析（跳转、补全、错误提示），还会运行 clang-tidy 的各类检查规则，并将发现的问题（如潜在 bug、代码风格、性能隐患）以诊断信息的形式显示在编辑器中。

#### 验证与使用
完成配置后，按 Ctrl+Shift+P 打开命令面板，运行 clangd: Restart language server 来重启 clangd 服务，使配置生效。
之后，当你打开内核源码文件时，clangd 将开始分析代码。你应该能体验到：
- 精确的跳转：F12 跳转到定义，Ctrl+Click 查看声明。
- 代码补全：输入时获得准确的成员和函数补全。
- 实时错误检查：无需编译即可看到代码中的错误和警告。

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