# BootMCU Firmware - 固件配置和构建

## 1. 固件概述

AST2700 BootMCU 固件是运行在 RISC-V 32 位处理器上的 Zephyr RTOS 应用程序，负责在安全启动流程中作为 FMC (First Mutable Code) 加载后续组件。

### 1.1 固件名称

| 芯片版本 | FMC 二进制 | 原始固件 |
|----------|------------|----------|
| AST2700 A1 | `ast2700-mcu-runtime.bin` | `ast2700-ibex-spl.bin` |
| AST2700 A2 | `ast2700-mcu-runtime.bin` | `ast2700-mcu-runtime.bin` |

## 2. 构建配置

### 2.1 配方文件分析

#### 2.1.1 Zephyr BootMCU (A2) 配方

**文件**: `meta-aspeed-sdk/dynamic-layers/zephyrcore-layer/recipes-kernel/zephyr-aspeed/zephyr-aspeed-bootmcu_git.bb`

```bitbake
require recipes-kernel/zephyr-kernel/zephyr-image.inc
require zephyr-aspeed-src.inc
require zephyr-aspeed-project-src.inc

SUMMARY = "BootMCU runtime firmware"
PACKAGE_ARCH = "${MACHINE_ARCH}"

PROVIDES += "virtual/bootmcu"
PV = "1.0+git"

# 关键配置
ZEPHYR_BOARD_BOOTMCU ??= "ast2700_evb/ast2700/bootmcu"
ZEPHYR_BOARD = "${ZEPHYR_BOARD_BOOTMCU}"
ZEPHYR_ASPEED_OUTPUT = "${BOOTMCU_FMC_BINARY} ${BOOTMCU_FW_BINARY}"

DEPENDS += "fmc-imgtool-native"
DEPENDS += "${@bb.utils.contains('MACHINE_FEATURES', 'ast-secure', 'aspeed-secure-config-native', '', d)}"
```

#### 2.1.2 Zephyr BootMCU (A1) 配方

**文件**: `meta-vendor/meta-vendor-amd/meta-amd-sp7/recipes-kernel/zephyr-aspeed/zephyr-aspeed-bootmcu-a1_git.bb`

```bitbake
require conf/machine/include/riscv/tune-riscv.inc

DEFAULTTUNE = "riscv32nf"

# BootMCU Build Settings
BOOTMCU_MACHINE = "ibex-ast2700_defconfig"
BOOTMCU_FW_BINARY = "ast2700-ibex-spl.bin"
```

### 2.2 机器配置文件

#### 2.2.1 AST2700 A1 机器配置

**文件**: `meta-aspeed-sdk/meta-ast2700-sdk/conf/machine/ast2700-a1.conf`

```bitbake
require conf/machine/include/ast2700-sdk.inc
require conf/machine/include/ast2700-a1.inc
# ...

# BootMCU Build Settings
# SoC First Mutable Code (FMC) image
FMC_IMAGE_ENABLE = "1"
BOOTMCU_FMC_BINARY = "ast2700-mcu-runtime.bin"
ZEPHYR_BOARD_BOOTMCU ?= "ast2700_evb/ast2700_a1/bootmcu"
```

#### 2.2.2 AST2700 A2 (默认) 机器配置

**文件**: `meta-aspeed-sdk/meta-ast2700-sdk/conf/machine/ast2700-default.conf`

```bitbake
require conf/machine/include/ast2700-sdk.inc
# ...

# BootMCU Build Settings
BOOTMCU_FW_BINARY = "ast2700-mcu-runtime.bin"
```

## 3. 固件构建流程

### 3.1 构建任务序列

```
do_configure()  -> 配置 Zephyr 项目
       │
       ▼
do_compile()    -> 编译 Zephyr 固件 (zephyr/zephyr.bin)
       │
       ▼
do_create_fmc_image()  -> 使用 fmc-imgtool 生成 FMC 镜像
       │
       ▼
do_install()    -> 安装固件到目标目录
       │
       ▼
do_deploy()     -> 部署固件到 deploy 目录
```

### 3.2 FMC 镜像生成

#### 3.2.1 构建脚本逻辑

```bash
do_create_fmc_image() {
    export OPENSSL_MODULES="${STAGING_LIBDIR_NATIVE}/ossl-modules"

    # 检查是否启用 FMC
    if [ "${FMC_IMAGE_ENABLE}" != "1" ]; then
        # A2: 直接使用原始固件
        install -m 0644 ${B}/zephyr/zephyr.bin ${B}/zephyr/${BOOTMCU_FW_BINARY}
        return
    fi

    # A1: 使用 fmc-imgtool 包装固件
    fmc-imgtool \
        --verbose \
        --version 2 \
        --input ${B}/zephyr/zephyr.bin \
        --output ${B}/zephyr/${BOOTMCU_FMC_BINARY} \
        --prebuilt-dir ${DEPLOY_DIR_IMAGE}/ \
        ${ecc_key} ${ecc_key_index} ${lms_key} ${lms_key_index}
}
```

#### 3.2.2 fmc-imgtool 参数

| 参数 | 说明 | 适用场景 |
|------|------|----------|
| `--version 2` | 使用 FMCv2 头格式 | A1 安全启动 |
| `--input` | 原始固件路径 | 所有场景 |
| `--output` | FMC 镜像输出路径 | 所有场景 |
| `--prebuilt-dir` | 预构建组件目录 | 需要预构建镜像 |
| `--ecc-key` | ECC 私钥文件 | A1 签名 |
| `--ecc-key-index` | ECC 密钥槽索引 (0-15) | A1 签名 |
| `--lms-key` | LMS 私钥文件 | A1 LMS 签名 |
| `--lms-key-index` | LMS 密钥槽索引 | A1 LMS 签名 |

## 4. Flash 布局配置

### 4.1 AST2700 A1 Flash 布局

**文件**: `image_types_phosphor_aspeed_g7.bbclass`

```
┌─────────────────────────────────────────────────────────────────┐
│                      131072 KB Flash Memory                      │
├─────────────┬────────────┬─────────────┬───────────┬───────────┤
│   0 KB      │   128 KB   │   896 KB    │   动态    │   动态    │
│ (0x00000)   │ (0x20000)  │  (0xE1000)  │           │           │
├─────────────┼────────────┼─────────────┼───────────┼───────────┤
│  Caliptra   │  BootMCU   │   U-Boot    │  Kernel   │   ROFS    │
│   Firmware  │ (FMC)      │   + Env     │   镜像    │   RWFS    │
│             │            │             │           │           │
│  固定       │  固定      │   固定      │   动态    │   动态    │
└─────────────┴────────────┴─────────────┴───────────┴───────────┘

配置参数:
FLASH_CALIPTRA_SIZE = "128"      # 128 KB
FLASH_BMCU_SIZE = "896"          # 896 KB
FLASH_UBOOT_OFFSET = 0           # 从 0 开始
FLASH_KERNEL_OFFSET = 4224 KB    # 0x420000
```

### 4.2 AST2700 A2 Flash 布局

```
┌─────────────────────────────────────────────────────────────────┐
│                      131072 KB Flash Memory                      │
├─────────────┬───────────────────────────────────────────────────┤
│   0 KB      │                    动态                           │
│ (0x00000)   │                                                  │
├─────────────┼───────────────────────────────────────────────────┤
│  Caliptra   │   其他组件 (U-Boot, Kernel, ROFS, RWFS)           │
│  Manifest   │                                                  │
│  (含MCU)    │                                                  │
└─────────────┴───────────────────────────────────────────────────┘

注意: BootMCU 集成在 Caliptra Manifest 中，不再有独立的 FMC 分区
```

### 4.3 镜像合并逻辑

```bash
do_merge_uboot() {
    uboot_offset=0

    # 合并 Caliptra 镜像
    mk_empty_image_zeros ${DEPLOY_DIR_IMAGE}/u-boot.${UBOOT_SUFFIX} ${FLASH_CALIPTRA_SIZE}
    dd bs=1k seek=0 if=${DEPLOY_DIR_IMAGE}/${CALIPTRA_FW_BINARY} of=${DEPLOY_DIR_IMAGE}/u-boot.${UBOOT_SUFFIX}
    uboot_offset=${FLASH_CALIPTRA_SIZE}

    # A1: 合并 BootMCU FMC 镜像
    if [ -n "${BOOTMCU_FMC_BINARY}" ]; then
        dd bs=1k seek=${uboot_offset} if=${DEPLOY_DIR_IMAGE}/${BOOTMCU_FMC_BINARY} of=${DEPLOY_DIR_IMAGE}/u-boot.${UBOOT_SUFFIX}
        uboot_offset=$(expr ${uboot_offset} + ${FLASH_BMCU_SIZE})
    fi

    # 合并 U-Boot
    dd bs=1k seek=${uboot_offset} if=${DEPLOY_DIR_IMAGE}/${UBOOT_BINARY} of=${DEPLOY_DIR_IMAGE}/u-boot.${UBOOT_SUFFIX}
}
```

## 5. 工具链配置

### 5.1 RISC-V 工具链

```bitbake
# bootmcu-spl.inc
RISCV_PREBUILT_TOOLCHAIN = "${STAGING_DIR_NATIVE}${datadir}/ast2700-riscv-linux-gnu/bin/riscv32-unknown-linux-gnu-"

EXTRA_OEMAKE = 'CROSS_COMPILE=${RISCV_PREBUILT_TOOLCHAIN} CC="${RISCV_PREBUILT_TOOLCHAIN}gcc" V=1'
```

### 5.2 Zephyr 工具链

```bitbake
# zephyr-aspeed-bootmcu_git.bb
ZEPHYR_TOOLCHAIN_VARIANT = "zephyr"
PREFERRED_VERSION_zephyr-sdk-native = "0.16.9"
```

## 6. 依赖关系

### 6.1 构建依赖

```bitbake
DEPENDS = "ast2700-riscv-linux-gnu-native kern-tools-native swig-native"
DEPENDS += "${PYTHON_PN}-setuptools-native fmc-imgtool-native"
DEPENDS += "${@bb.utils.contains('MACHINE_FEATURES', 'ast-secure', 'aspeed-secure-config-native u-boot-tools-native', '', d)}"
```

### 6.2 部署依赖

```bitbake
do_create_fmc_image[depends] += "bmc-pb:do_deploy"
do_merge_uboot[depends] += "u-boot:do_deploy virtual/bootmcu:do_deploy"
```

## 7. 安全构建选项

### 7.1 启用签名

```bash
# local.conf
FMC_SIGN_ENABLE = "1"
FMC_ECC_KEY = "/path/to/ecc-private-key.pem"
FMC_ECC_KEY_INDEX = "0"
FMC_LMS_KEY = "/path/to/lms-private-key.prv"
FMC_LMS_KEY_INDEX = "0"
```

### 7.2 安全特性检查

```bash
# 检查机器特性
MACHINE_FEATURES += "ast-secure"

# 启用安全配置
require conf/machine/include/ast2700-secure-mode.inc
```

## 8. 输出文件

### 8.1 部署目录文件

```
tmp/deploy/images/ast2700-xxx/
├── u-boot-spl.dtb              # SPL 设备树 (ARM)
├── u-boot-spl-nodtb.bin        # SPL 二进制 (无 DTB)
├── u-boot-spl.bin              # SPL 完整二进制
├── ast2700-ibex-spl.bin        # RISC-V BootMCU 原始固件
└── ast2700-mcu-runtime.bin     # FMC 封装的 BootMCU (A1)
```

### 8.2 镜像合并输出

```
tmp/deploy/images/ast2700-xxx/
├── image-bmc                   # 完整 Flash 镜像
├── image-u-boot.merged         # 合并的 U-Boot 镜像 (含 Caliptra/BootMCU)
└── image-u-boot                # 原始 U-Boot
```

## 9. 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| 1.0 | 2024-12-11 | 初始版本 |
| 2.0 | 2025-06-09 | 更新 A1/A2 差异和 fmc-imgtool 集成 |