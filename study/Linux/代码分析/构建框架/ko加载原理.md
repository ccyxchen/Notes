# T402V (MT6768 / kernel 6.6 GKI) 内核模块 (ko) 机制全解

覆盖内容：user/userdebug 区分、BOARD 变量语义、打包流程、镜像生成、开机加载、depmod/strip、symbols 位置。

---

## 1. user/userdebug/eng 的区分：编译期过滤，非运行时

### 1.1 数据源：`ko_order_table.csv` 第 6 列 "Build mode"

`device/tinno/t402v/ko_order_table.csv` 每行 6 列：

```
KO名, KO路径, 分区(vendor/ramdisk), 开机前加载(Y/N), Recovery(Y/N), 适用build mode
```

当前 328 行：
- 323 行 `user/userdebug/eng` —— 三种版本都编入
- 4 行只有 `userdebug/eng` —— **user 版不编入**：
  - `irq_monitor.ko`（L56）
  - `mt6370-dbg.ko`（L96）
  - `mmqos_wrapper.ko`（L176）
  - `systracker.ko`（L282）

### 1.2 过滤逻辑：`device/tinno/t402v/gki_ko.mk`

由 `BoardConfig.mk:17` include。核心在 `gki_ko.mk:24`：

```make
ko_mode := $(subst /, ,$(word 6,$(ko_line)))   # "user/userdebug/eng" → 词列表
$(if $(filter $(TARGET_BUILD_VARIANT),$(ko_mode)),\
  ... += $(KERNEL_OUT)$(ko_path)               # 匹配才追加
  $(if $(filter Y,$(ko_loaded)), ..._LOAD += ...))
```

第 6 列拆成列表后与 `TARGET_BUILD_VARIANT` 做 `$(filter)`，命中才写入：
- `BOARD_VENDOR_KERNEL_MODULES` / `_LOAD`（vendor 分区）
- `BOARD_VENDOR_RAMDISK_KERNEL_MODULES` / `_LOAD`（ramdisk）
- `BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD`（recovery=Y 时）

### 1.3 产物路径也区分变体（gki_ko.mk:45-56）

```make
KERNEL_BUILD_VARIANT := $(TARGET_BUILD_VARIANT)
```

Kleaf/Bazel 内核构建本身分 `user/userdebug/eng` 输出目录（路径带 `.<variant>` 后缀），vendor 列表里的 ko 路径被重写到对应变体目录。

### 1.4 运行时不区分

`init.mtkgki.rc:1-13` 启动 `init.insmod.sh /vendor/etc/init.insmod.mt6768.cfg`，cfg 里只有 `modprobe|*` —— 加载镜像里已打包的全部模块。user 版那 4 个 ko 根本不在镜像里，自然加载不到。

---

## 2. `BOARD_*_KERNEL_MODULES` vs `_LOAD`

消费方在 `build/make/core/Makefile:567-572`（`build-image-kernel-modules-dir`）：

| 变量 | 作用 |
|---|---|
| `BOARD_<X>_KERNEL_MODULES` | 决定**打包进镜像**的 ko 集合：拷到 `<partition>/lib/modules/`，跑 depmod 生成 `modules.dep` |
| `BOARD_<X>_KERNEL_MODULES_LOAD` | 生成 `modules.load` 文件，即**开机自动加载**的子集 |

规则：
- `_LOAD` 为空 → Makefile:568-569 默认回填为 `MODULES` 全集
- `_LOAD` 显式为 `false` → 生成空 load 列表
- 对应 csv 第 4 列：`Y` → 两个变量都加（gki_ko.mk:26-27）；`N` → 只进 `MODULES`，镜像里有但开机不自动加载，由 HAL/service 之后手动 insmod

即：**打包集合 = MODULES，开机自动加载集合 = _LOAD（MODULES 的子集）**。

---

## 3. Kleaf 构建下的三个 ko 产物路径（gki_ko.mk:54-56）

```
mtk_ack_protected_ko_path = .../KLEAF_OBJ/dist/kernel_device_modules-6.6/$(KLEAF_BUILD_PROJECT)_kernel_aarch64.$(VARIANT)
mtk_ack_ko_path           = .../KLEAF_OBJ/dist/kernel_device_modules-6.6/$(KLEAF_BUILD_PROJECT).$(VARIANT)
mtk_kleaf_ko_path         = .../KLEAF_OBJ/dist/kernel_device_modules-6.6/$(KLEAF_BUILD_PROJECT)_$(customer|internal)_modules_install.$(VARIANT)
```

- **`_kernel_aarch64`（protected）**：Kleaf `kernel_aarch64` 目标输出 = ACK/GKI 公共内核本体的受保护模块。用于 **system 侧**列表（gki_ko.mk:68）
- **`$(PROJECT).$(VARIANT)`**：整个 project 的主 dist 目录。用于 vendor 列表中路径形如 `$(KERNEL_OUT)/xxx`（不含 `KERNEL_OUT/../` 前缀）的模块，保留子路径（gki_ko.mk:80）
- **`_modules_install`（kleaf）**：Kleaf 单独的 `modules_install` 目标输出 = MTK 设备树模块（`kernel_device_modules-*` + `vendor/mediatek/kernel_modules`）。`customer` vs `internal` 由是否存在 `vendor/mediatek/tests/kernel` 决定（gki_ko.mk:49-53）。用于路径含 `KERNEL_OUT/../` 前缀的模块 —— **ko_order_table.csv 里的条目全部属于此类**，且被 `$(notdir)` 扁平化到该目录下（gki_ko.mk:81）

重写判据（gki_ko.mk:79）：`$(filter $(subst $(KERNEL_OUT)/../,,$(ko)),$(ko))`
- 去掉前缀后路径不变 → 无前缀 → 走 `mtk_ack_ko_path`
- 变了 → 有前缀 → 走 `mtk_kleaf_ko_path` + basename

`BOARD_SYSTEM_KERNEL_MODULES := LOAD`（gki_ko.mk:74），system 侧打包列表 = 加载列表，一一对应。

### 3.1 `BOARD_SYSTEM_KERNEL_MODULES_LOAD` 是否预编译（gki_ko.mk:58-73）

- **有预编译 boot image**（`MTK_BOARD_PREBUILT_BOOTIMAGE` 非空，即 `vendor/aosp_gki/<ver>/aarch64/boot-*.img` 存在，BoardConfig-vext.mk:141）→ gki_ko.mk:60-61 直接指向 **ACK 预编译 ko**：`kernel/prebuilts/<kernel-ver>/arm64/*.ko`（列表来自该目录的 `modules.load`，BoardConfig-vext.mk:291 定义 `ALL_LOADED_GKI_MODULES`）+ `gzvm.ko`
- **无预编译**（源码编译内核）→ gki_ko.mk:63-71 把 `$(KERNEL_OUT)/...` 路径重写到 `mtk_ack_protected_ko_path` 下

---

## 4. ko 的去处：各分区打包位置

打包逻辑在 `build/make/core/Makefile:703-723`（变量名 `BOARD_<X>_KERNEL_MODULES` 动态拼接）。

| 变量 | 落盘位置 | 触发条件 |
|---|---|---|
| `BOARD_VENDOR_RAMDISK_KERNEL_MODULES` | vendor_boot 的 **vendor ramdisk** → `/lib/modules/<kver>/`（+`modules.load`，recovery 子集 → `modules.load.recovery`） | Makefile:709-711, 606-607 |
| `BOARD_VENDOR_KERNEL_MODULES` | **vendor.img** → `/vendor/lib/modules/<kver>/`（+`modules.load`） | Makefile:715；`BOARD_USES_VENDOR_DLKMIMAGE=true` 时改走 vendor_dlkm.img 的 `/vendor_dlkm/lib/modules`（BoardConfig-image.mk:11,29） |
| `BOARD_SYSTEM_KERNEL_MODULES` | **system_dlkm.img** → `/system_dlkm/lib/modules/` | Makefile:720；`BOARD_USES_SYSTEM_DLKMIMAGE=true` 时（BoardConfig-image.mk:13,31） |
| `BOARD_ODM_KERNEL_MODULES` | odm.img 或 odm_dlkm.img | Makefile:719；本项目 csv 无 odm 条目，为空 |
| `BOARD_GENERIC_RAMDISK_KERNEL_MODULES` | boot generic ramdisk / recovery root | Makefile:723, 597-598 |
| `BOARD_RECOVERY_KERNEL_MODULES` | recovery ramdisk | Makefile:703 |
| `BOARD_VENDOR_KERNEL_RAMDISK_*` | vendor_boot v5+ 的 vendor_kernel_boot ramdisk | Makefile:712；本平台 boot header v4 不用 |
| `*_CHARGER_KERNEL_MODULES_LOAD` | 各分区 `modules.load.charger` | Makefile:624-643；charger 开机模式由 first-stage init 选读 |
| `BOARD_<X>_KERNEL_MODULES_<kver>` | 同上带 `<kver>` 后缀（多内核版本） | Makefile:567 |

MTK 补充：
- `KERNEL_TESTS`（gki_ko.mk:86-88，存在 `vendor/mediatek/tests` 时追加）
- out-of-tree ko 经 `device/mediatek/build/core/build_ko.mk:36` append 到 `BOARD_VENDOR_KERNEL_MODULES`

本项目实际用到：**vendor ramdisk（153 个）、vendor 分区（175 个）、system_dlkm（GKI+gzvm）**。

### 4.1 system_dlkm 是否使用、存什么

**使用**。启用链：
- system 侧（`full_t402v` → `SYS_TARGET_PROJECT=mssi_64_cn`）：`device/mediatek/system/common/BoardConfig-image.mk:6-8` 在 `ifndef MTK_TARGET_PROJECT` 时设置 `BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := ext4` + `TARGET_COPY_OUT_SYSTEM_DLKM := system_dlkm`
- `build/make/core/board_config.mk:899-904`：`BOARD_USES_SYSTEM_DLKMIMAGE := true`、`BUILDING_SYSTEM_DLKM_IMAGE := true`
- 分区表：`vendor/mediatek/proprietary/tools/ptgen/MT6768/partition_table_emmc_ab.csv:40` 有 `system_dlkm` 分区
- 加载：`device/mediatek/vendor/common/init.insmod.sh:35` 明确扫 `/system_dlkm/lib/modules`

**内容**（gki_ko.mk:58-74）：
- GKI/ACK 保护模块（`ALL_LOADED_GKI_MODULES` 或 `kernel_aarch64` dist）
- `gzvm.ko`（GenieZone hypervisor）

设计意图：GKI 架构下必须由 system 侧拥有、vendor 不可改的模块，放独立的 system_dlkm 分区保证 GKI 模块 ABI 全设备一致，system 可独立于 vendor 升级。

### 4.2 分区表来源

MTK 分区表由 **ptgen** 工具生成，目录约定 `vendor/mediatek/proprietary/tools/ptgen/<芯片号>/`：
- `BoardConfig.mk:140`：`include vendor/mediatek/proprietary/tools/ptgen/$(MTK_PTGEN_CHIP)/partition_size.mk`
- 本项目芯片 MT6768 → `vendor/mediatek/proprietary/tools/ptgen/MT6768/partition_table_emmc_ab.csv`（含 `vendor_dlkm`:39、`system_dlkm`:40）

---

## 5. ko 打包进 img 的流程

分两段：**先安装到 out/ 目录树，再由镜像目标打包成 img**。

### 5.1 第一段：ko → `out/target/product/<dev>/...` 安装目录

入口 `build/make/core/Makefile:560-575` 的 `build-image-kernel-modules-dir`：

1. **拷贝+strip**（Makefile:410-419 `build-image-kernel-modules`）：每个 ko 经 `copy-and-strip-kernel-module` 去掉 debug 符号，拷到 `<partition_out>/lib/modules/<kver>/xxx.ko`（Makefile:573 `copy-many-files`）
2. **depmod**（Makefile:442-498）：ko 集中到 `obj/PACKAGING/depmod_<X>/` staging，跑 `$(DEPMOD) -b staging 0.0`，生成 `modules.dep`/`modules.alias`/`modules.softdep` 拷回；`_LOAD` 列表 `basename` 化写成 `modules.load`（Makefile:503-514）
3. 结果通过 `ALL_DEFAULT_INSTALLED_MODULES +=`（Makefile:573）挂进默认构建目标

### 5.2 第二段：安装目录 → img 文件

- **vendor.img**：Makefile:3847-3876 `build-vendorimage-target` → `generate-image-prop-dictionary` 生成 `vendor_image_info.txt` → 调 `build/make/tools/releasetools/build_image.py`（内部 `mke2fs`）把 `$(TARGET_OUT_VENDOR)` 打成 ext4 → `$(PRODUCT_OUT)/vendor.img`
- **system_dlkm.img**：Makefile:4287-4301 `build-system_dlkmimage-target`，同样调 `build_image.py` → `system_dlkm.img`
- **vendor_boot.img**（ramdisk 型 ko 走这条）：Makefile:1573-1588 `mkbootfs` 把 `TARGET_VENDOR_RAMDISK_OUT` 打成 `vendor_ramdisk.cpio(.gz)`，再 Makefile:1677-1697 `mkbootimg --vendor_ramdisk ... --vendor_boot` + AVB 签名 → `vendor_boot.img`

### 5.3 汇总链

```
gki_ko.mk 填 BOARD_*_KERNEL_MODULES[_LOAD]
  → Makefile:560 build-image-kernel-modules-dir
    → copy+strip 到 <partition>/lib/modules/
    → depmod 生成 modules.dep / modules.load
  → 各 image target (Makefile:3850 vendor / 4290 system_dlkm / 1678 vendor_boot)
    → build_image.py / mkbootfs+mkbootimg
  → out/target/product/t402v/{vendor.img, system_dlkm.img, vendor_boot.img}
  → MTK scatter(ptgen 生成) + SP Flash Tool / OTA 写入对应分区
```

---

## 6. depmod 与 strip

### 6.1 depmod 的作用

`depmod` 是内核模块依赖分析工具（kmod 包自带）。Makefile:442-498 对 staging 目录跑 `$(DEPMOD) -b $staging 0.0`：

1. 解析每个 .ko 的符号表（`__versions`、导出符号），比对模块间依赖（A 用到 B 导出的符号 → 记录 `A.ko: B.ko`）
2. 生成索引文件：
   - `modules.dep` —— 依赖关系表，`modprobe` 靠它自动加载依赖链（`insmod` 不会）
   - `modules.alias` —— modalias 别名表，ueventd/modalias_handler 靠硬件 modalias 反查该加载哪个 ko
   - `modules.softdep` —— 软依赖（`pre: xxx`，加载顺序保证）
3. Makefile:487 用 `sed` 把 `modules.dep` 里相对路径转绝对路径

版本号传 `0.0` 是故意跳过内核版本校验（GKI 场景编译时 `uname -r` 和真机不一致）。

### 6.2 strip

是的，`copy-and-strip-kernel-module` 用 host 的 `strip`（或 `llvm-strip`）去掉 `.ko` 里的 DWARF 调试段，只保留运行必需的动态符号表。目的：减小镜像体积、减少首次加载时内核解析模块的开销。

### 6.3 userdebug/eng 也 strip

**会 strip**。打包阶段无条件执行（Makefile:410-419，不区分 `TARGET_BUILD_VARIANT`），三种版本 img 里的 ko 都是 stripped 的。

debug 符号去哪了？MTK 在 `device/mediatek/build/tasks/mtk_kernel_modules.mk:52-73` 打包前把 **unstripped** 的 ko 备份到 symbols 目录（见第 8 节）。

user/userdebug/eng 的差异不在 strip 与否，而在：**user 版少了 4 个 userdebug/eng-only 的 ko**（见 1.1）。

---

## 7. 开机加载流程

三类 ko 打包位置和加载时机不同：

### 7.1 vendor ramdisk 模块 → first-stage init，最早加载

`system/core/init/first_stage_init.cpp:442` 在挂载分区/switch_root **之前**调用 `LoadKernelModules()`：扫 ramdisk 里的 `/lib/modules/<uname -r>/`（first_stage_init.cpp:212, 269-277），按 `modules.load` 逐个加载。recovery 开机改读 `modules.load.recovery`，charger 模式读 `modules.load.charger`（first_stage_init.cpp:187-196）。

这就是为什么 `ko_order_table.csv` 里放在 ramdisk、`Recovery=Y` 的模块（bootprof、clk、pinctrl 等）必须在这一批 —— 后面挂 vendor/system 都需要它们。

### 7.2 vendor / system_dlkm 分区模块 → second stage，MTK `insmod_sh` 服务加载

`device/tinno/t402v/init.mtkgki.rc:1-13`：`on early-init` → `start insmod_sh`（disabled + oneshot service）：

```
service insmod_sh /vendor/bin/init.insmod.sh /vendor/etc/init.insmod.${ro.hardware}.cfg
```

脚本 `device/mediatek/vendor/common/init.insmod.sh:35-49` 收到 cfg 里的 `modprobe|*` 后，遍历 **`/system_dlkm/lib/modules` 和 `/vendor/lib/modules`**，对每个含 `modules.load` 的目录执行 `modprobe -a -d $dir $(cat modules.load)`，最后 `setprop vendor.all.modules.ready 1`。

### 7.3 之后的热插拔

first-stage 起的 `modalias_handler`（system/core/init/modalias_handler.cpp）根据 uevent modalias 按需 `LoadWithAliases`，处理剩余模块。

### 7.4 时序总结

```
kernel
  → first-stage init 加载 vendor ramdisk ko（/lib/modules）
  → mount vendor / system_dlkm
  → early-init 启动 insmod_sh 加载 system_dlkm + vendor ko（并设 vendor.all.modules.ready）
  → 热插拔 modalias 按需加载
```

---

## 8. symbols（unstripped ko）位置

**只在编译主机的 out 目录，不在设备上，adb 拿不到**：

```
out/target/product/t402v/symbols/kernel-6.6/system/lib/modules/          # in-tree ko（unstripped）
out/target/product/t402v/symbols/kernel-6.6/system/vendor/lib/modules/   # out-of-tree ko（unstripped）
out/target/product/t402v/symbols/kernel-6.6/vmlinux                      # 内核符号
```

依据：
- `TARGET_OUT_UNSTRIPPED := $(PRODUCT_OUT)/symbols`（build/make/core/envsetup.mk:991）
- `mtk_kernel_modules.mk:55-63`：in-tree ko 拷到 `$(TARGET_OUT_UNSTRIPPED)/$(LINUX_KERNEL_VERSION)/system/lib/modules`
- `mtk_kernel_modules.mk:67-73`：`vendor/mediatek/kernel_modules` 下的 out-of-tree ko 拷到 `.../system/vendor/lib/modules`

`symbols/` 不打进任何 img，供开发者本地用 crash/gdb 解析。

**adb 能拿到的**只有设备上已 strip 的 ko：
- `/vendor/lib/modules/`（或 vendor_dlkm 挂载后 `/vendor_dlkm/lib/modules/`）
- `/system_dlkm/lib/modules/`
- vendor_boot ramdisk 里的 `/lib/modules/`（root 后从挂载点读或解包 vendor_boot.img）

Kleaf 构建注意：`KERNEL_USE_BAZEL=yes` 时 `KERNEL_SYMBOL_OUT` 指向 `KLEAF_OBJ/dist/.../mgk_64_k66.<variant>`（mtk_kernel_modules.mk:24-27），真正的 unstripped ko 原始产物在那里，symbols/ 下只是再拷贝一份。user/userdebug/eng 各有各的 dist 目录（`.<variant>` 后缀）。

---

## 9. 相关文件索引

| 文件 | 作用 |
|---|---|
| `device/tinno/t402v/ko_order_table.csv` | ko 清单：名称/路径/分区/加载/recovery/build mode |
| `device/tinno/t402v/gki_ko.mk` | 解析 csv → 填 BOARD_* 变量；Kleaf 路径重写 |
| `device/tinno/t402v/BoardConfig.mk:17` | include gki_ko.mk |
| `device/tinno/t402v/init.mtkgki.rc` | 定义 insmod_sh 服务，early-init 启动 |
| `device/tinno/t402v/init.insmod.mt6768.cfg` | insmod.sh 的指令：`modprobe|*` + setprop |
| `device/mediatek/vendor/common/init.insmod.sh` | 实际加载脚本：扫 system_dlkm + vendor |
| `device/mediatek/build/tasks/mtk_kernel_modules.mk` | ko 依赖内核镜像；unstripped ko 备份到 symbols |
| `device/mediatek/build/core/build_ko.mk` | out-of-tree ko 编译安装规则 |
| `build/make/core/Makefile:410-723` | ko 打包：copy/strip/depmod/modules.load |
| `build/make/core/Makefile:3847/4287/1677` | vendor.img / system_dlkm.img / vendor_boot.img 生成 |
| `build/make/core/board_config.mk:899-904` | BOARD_USES_SYSTEM_DLKMIMAGE 推导 |
| `system/core/init/first_stage_init.cpp` | first-stage 加载 ramdisk ko |
| `vendor/mediatek/proprietary/tools/ptgen/MT6768/` | 分区表生成（scatter） |
