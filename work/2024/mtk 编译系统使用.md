# mtk 编译系统

## 使用传统Android编译系统

### 非GKI项目

非GKI使用的是MTK split build 1.0编译体系。
split build 1.0编译分为 sys和vnd两部分
以T402为例，下面是实际编译各部分以及打包的命令。
各个部分的项目名可以如下确认：
system部分
查看 vendor/device/tinno/t402aa/full_t402aa.mk 中定义了
`SYS_TARGET_PROJECT := mssi_t_64_cn_wifi` 就是system的项目名。

vendor部分：
查看 vendor/device/tinno/t402aa/full_t402aa.mk 中定义了
`MTK_TARGET_PROJECT := t402aa` 就是vendor的项目名。

```Shell
# 编译命令
# system编译：
cd system
source build/envsetup.sh
export OUT_DIR=out_sys && lunch sys_mssi_t_64_cn_wifi-userdebug && make sys_images

# vendor部分：
cd vendor
source build/envsetup.sh
export OUT_DIR=out && lunch vnd_t402aa-userdebug && make vnd_images krn_images

# 单编
cd vendor
source build/envsetup.sh
export OUT_DIR=out && lunch vnd_t402aa-userdebug 
## 编译 kernel 
make bootimage
## 编译 vendor boot
make vendorbootimage
## 编译 dtb
make dtboimage
## 编译preloader
make pl
## 编译lk
make lk

# 签名和打包
python system/out_sys/target/product/mssi_t_64_cn_wifi/images/split_build.py --system-dir system/out_sys/target/product/mssi_t_64_cn_wifi/images --vendor-dir vendor/out/target/product/t402aa/images --kernel-dir vendor/out/target/product/t402aa/images --output-dir vendor/out/target/product/t402aa/merged
```

### GKI项目

GKI使用的是MTK split build 2.0编译体系。

split build 2.0将编译的的产物分为 MSSI/MGVI/MGK/VendorExt 4个部分，其中MSSI是system的编译产物，
MGVI/MGK/VendorExt是vendor的产物。它们各自需要有独立的out folder，而post-process 只需要这4 个out folder
中的一个folder (out_xxx/target/product/{project name}/images/)的内容
即可进行image 打包。

以P528为例，下面是实际编译各部分以及打包的命令。
P528对每个部分都做了项目克隆，和官方的命令会有差异
各个部分的项目名可以如下确认：
system部分
MSSI：
查看 ./system/device/mediatek/system/ 目录下有mssi_p528 克隆项目文件夹，所以lunch名为sys_mssi_p528

vendor部分
查看 ./vendor/device/tinno/p528/full_p528.mk 定义了vnd的项目名
VND_TARGET_PROJECT := p528
则vnd的变量定义在：./vendor/device/tinno/p528/vnd_p528.mk
其中各部分的项目名为：
MGVI: `HAL_TARGET_PROJECT := mgvi_64_armv82`
MGK: `KRN_TARGET_PROJECT := mgk_64_entry_level_k510`
VendorExt: `VEXT_TARGET_PROJECT := p528`

```Shell
source build/envsetup.sh
# MSSI
# Configuration: device/mediatek/system/mssi_xxx_yyy
# Build cmd: 
export OUT_DIR=out_sys && lunch sys_mssi_p528-userdebug && make sys_images

# MGVI
# Configuration: device/mediatek/vendor/mgvi_xxx_yyy
# Build cmd: 
export OUT_DIR=out_hal && lunch hal_mgvi_64_armv82-userdebug && make hal_images

# MGK
# Configuration: device/mediatek/kernel/mgk_xxx_yyy
# Including kernel-5.10/arch/arm64/configs/mgk_64_k510_defconfig
# Build cmd: 
export OUT_DIR=out_krn && lunch krn_mgk_64_entry_level_k510-userdebug && make krn_images

# VendorExt
# Configuration: device/mediateksample/kxxxx_yyy
# device/mediateksample/kxxxx_yyy/full_kxxxx_yyy.mk 会列出使用哪个mssi project 和vnd project。
# device/mediateksample/kxxxx_yyy/vnd_kxxxx_yyy.mk 会列出使用哪个mgvi project 和mgk project。
# Build cmd: 
export OUT_DIR=out && lunch vext_p528-userdebug && make vext_images

# 其中 MGVI/MGK/VendorExt 可以使用vnd 来进行统一编译
lunch vnd_p528-userdebug && make vnd_images krn_images

# Post-process(以p528 举例) 打包：
python ./system/out_sys/target/product/mssi_p528/images/split_build.py --system-dir ./system/out_sys/target/product/mssi_p528/images --vendor-dir ./vendor/out_hal/target/product/mgvi_64_armv82/images --kernel-dir ./vendor/out_krn/target/product/mgk_64_entry_level_k510/images --vext-dir ./vendor/out/target/product/p528/images --output-dir ./merged/
```

#### 解压vendor_boot.img和boot.img

```Shell
# 解压vendor_boot.img
mkdir vendor_boot_file && python3.8 ./vendor/system/tools/mkbootimg/unpack_bootimg.py --boot_img vendor_boot.img --out vendor_boot_file --format mkbootimg -0 | tr "\0" "\n" > ./vendor_boot_file/mkbootimg_args

cd vendor_boot_file

gunzip -c vendor_ramdisk00 | cpio -i

# 解压boot.img
mkdir boot_file && python3.8 ./vendor/system/tools/mkbootimg/unpack_bootimg.py --boot_img boot.img --out boot_file --format mkbootimg -0 | tr "\0" "\n" > ./boot_file/mkbootimg_args

cd boot_file
gunzip -c ramdisk | cpio -i
```

#### 单编

```Shell
export OUT_DIR=out && lunch vnd_p528-userdebug 
make bootimage
make vendorbootimage
make lk
make preloader
```
