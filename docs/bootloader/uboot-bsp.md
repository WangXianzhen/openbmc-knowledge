# U-Boot BSP 概述和配置

## 1. 概述

本文档描述 AST2700 平台的 U-Boot 引导加载程序 (BSP) 配置体系。AST2700 使用 AspeedTech-BMC 维护的 U-Boot 分支，版本为 v2023.10。

### 1.1 版本信息

| 属性 | 值 |
|------|-----|
| U-Boot 版本 | v2023.10+git |
| 源码分支 | aspeed-master-v2023.10 |
| Git 提交 | b139e0526e716721e1d1be3ed0ea019aaaf079ed |
| 源码仓库 | https://github.com/AspeedTech-BMC/u-boot |

### 1.2 与前代平台的差异

| 特性 | AST2500/2600 | AST2700 |
|------|--------------|---------|
| U-Boot 版本 | 2019.04 | 2023.10 |
| 架构 | ARM32 (armv7) | ARM64 (armv8/aarch64) |
| 处理器 | Cortex-A7 | Cortex-A35 |
| SOC 系列 | aspeed-g5/g6 | aspeed-g7 |
| 设备树 | ast2500-evb.dts | ast2700-evb.dts |
| defconfig | evb-ast2500_defconfig | evb-ast2700_defconfig |

## 2. 架构设计

### 2.1 引导流程

AST2700 的引导流程涉及多个固件组件，U-Boot 是其中关键的启动阶段:

```
BootROM → FMC/BootMCU → BL31 (TF-A) → OP-TEE → U-Boot → Linux Kernel
    │           │              │            │         │
    │     (OTP root key)  (Caliptra   (Caliptra   (FIT signature)
    │                      Manifest)    Manifest)
```

### 2.2 组件职责

- **BootROM**: 不可变的信任根，验证 FMC
- **FMC (First Mutable Code)**: 首个可更新的代码，由 OTP 根密钥哈希验证
- **BL31 (TF-A)**: Trusted Firmware-A，提供安全世界服务
- **OP-TEE**: 可信操作系统，为安全应用提供 TEE 环境
- **U-Boot**: 通用引导加载程序，负责初始化硬件、加载内核

### 2.3 SOC 系列配置

AST2700 使用 `SOC_FAMILY = "aspeed-g7"`，这是 Aspeed 第 7 代 BMC 芯片。

```bitbake
SOC_FAMILY = "aspeed-g7"
include conf/machine/include/soc-family.inc
```

## 3. 机器配置结构

### 3.1 配置层次

AST2700 机器配置采用分层设计:

```
ast2700-default.conf (具体机器配置)
    ├── ast2700-sdk.inc (SOC 通用配置)
    │       ├── aspeed-sdk.inc (Aspeed SDK 通用配置)
    │       ├── ast-arm-trusted-firmware-a.inc (TF-A 配置)
    │       ├── ast-bootmcu.inc (BootMCU 配置)
    │       └── ast-optee-os.inc (OP-TEE 配置)
    ├── ast-ssp.inc (安全策略)
    ├── ast-tsp.inc (信任策略)
    ├── ast2700-secure-customize-gen.inc (安全启动定制)
    └── obmc-bsp-common.inc (OpenBMC 通用配置)
```

### 3.2 核心配置项

**ast2700-default.conf 关键配置:**

```bitbake
# U-Boot 构建设置
UBOOT_MACHINE = "evb-ast2700_defconfig"
UBOOT_DEVICETREE = "ast2700-evb"

# 内核构建设置
KERNEL_DEVICETREE = "aspeed/ast2700-evb.dtb"
KBUILD_DEFCONFIG = "defconfig"

# 闪存布局 (128MB flash)
FLASH_SIZE = "131072"
FLASH_UBOOT_OFFSET:flash-131072 = "0"
FLASH_UBOOT_ENV_OFFSET:flash-131072 = "4096"
FLASH_KERNEL_OFFSET:flash-131072 = "4224"
FLASH_ROFS_OFFSET:flash-131072 = "19584"
FLASH_RWFS_OFFSET:flash-131072 = "98304"
RWFS_SIZE = "33554432"
```

### 3.3 闪存布局设计

AST2700 使用 128MB 大容量闪存，布局经过优化:

| 分区 | 偏移 (KB) | 大小 (KB) | 用途 |
|------|----------|----------|------|
| U-Boot | 0 | 4096 (4MB) | 引导加载程序 |
| U-Boot Env | 4096 | 128 (128KB) | 环境变量 |
| Kernel/FIT | 4224 | 15360 (15MB) | 内核和设备树 |
| ROFS | 19584 | 78720 (77MB) | 只读根文件系统 |
| RWFS | 98304 | 32768 (32MB) | 读写数据存储 |

## 4. FIT 镜像配置

### 4.1 FIT 架构

AST2700 使用 Flattened Image Tree (FIT) 格式打包多组件镜像，这是 ARM64 架构的标准做法。

### 4.2 FIT 组件地址映射

```bitbake
# U-Boot FIT 配置
UBOOT_FIT_UBOOT_ENTRYPOINT ?= "0x80000000"
UBOOT_FIT_UBOOT_LOADADDRESS ?= "0x80000000"

# ARM Trusted Firmware (BL31)
UBOOT_FIT_ARM_TRUSTED_FIRMWARE_LOADADDRESS ?= "0xb0000000"
UBOOT_FIT_ARM_TRUSTED_FIRMWARE_ENTRYPOINT ?= "0xb0000000"

# OP-TEE (BL32)
UBOOT_FIT_TEE_LOADADDRESS ?= "0xb0080000"
UBOOT_FIT_TEE_ENTRYPOINT ?= "0xb0080000"

# SSP (Zephyr)
UBOOT_FIT_SSP_ARCH ?= "arm"
UBOOT_FIT_SSP_OS ?= "zephyr"
UBOOT_FIT_SSP_LOADADDRESS ?= "0xac000000"
UBOOT_FIT_SSP_ENTRYPOINT ?= "0xac000000"

# TSP (Zephyr)
UBOOT_FIT_TSP_ARCH ?= "arm"
UBOOT_FIT_TSP_OS ?= "zephyr"
UBOOT_FIT_TSP_LOADADDRESS ?= "0xae000000"
UBOOT_FIT_TSP_ENTRYPOINT ?= "0xae000000"

# iBEX Firmware (RISC-V)
UBOOT_FIT_IBEXFW_ARCH ?= "riscv"
UBOOT_FIT_IBEXFW_OS ?= "zephyr"
UBOOT_FIT_IBEXFW_LOADADDRESS ?= "0x14ba8000"
UBOOT_FIT_IBEXFW_ENTRYPOINT ?= "0x14ba8000"
```

### 4.3 地址空间分配

| 组件 | 地址范围 | 大小 | 说明 |
|------|---------|------|------|
| ATF (BL31) | 0xB0000000 | 512KB | ARM Trusted Firmware |
| OP-TEE (BL32) | 0xB0080000 | 512KB | 可信操作系统 |
| U-Boot | 0x80000000 | 2MB | 主引导加载程序 |
| SSP | 0xAC000000 | - | Zephyr 安全服务 |
| TSP | 0xAE000000 | - | Zephyr 信任服务 |
| iBEX | 0x14BA8000 | - | RISC-V 加密子系统 |

### 4.4 内核 FIT 配置

```bitbake
# 使用 lzma 压缩节省空间
FIT_KERNEL_COMP_ALG ?= "lzma"
FIT_KERNEL_COMP_ALG_EXTENSION ?= ".lzma"

# 地址单元配置
FIT_ADDRESS_CELLS ?= "2"

# U-Boot 入口点 (ARM64 使用 64-bit 格式)
UBOOT_ENTRYPOINT ?= "0x4 0x00000000"
UBOOT_LOADADDRESS ?= "0x4 0x00000000"
```

## 5. 安全启动集成

### 5.1 安全启动架构

AST2700 支持完整的安全启动链，U-Boot 在其中扮演重要角色:

```bitbake
# 启用安全启动
MACHINE_FEATURES += "ast-secure"

# 安全启动时添加依赖
DEPENDS += "${@bb.utils.contains('MACHINE_FEATURES', 'ast-secure', 'aspeed-secure-config-native', '', d)}"
```

### 5.2 U-Boot 签名配置

```bitbake
# 启用签名
UBOOT_SIGN_ENABLE ?= "1"
UBOOT_SIGN_KEYDIR ?= "${STAGING_DATADIR_NATIVE}/aspeed-secure-config/ast2700/keys"

# 签名算法配置
UBOOT_SIGN_KEYNAME ?= "test_bl3_ecdsa_secp384r1"
FIT_HASH_ALG ?= "sha384"
FIT_SIGN_ALG ?= "ecdsa384"
FIT_SIGN_NUMBITS ?= "384"
```

### 5.3 设备树密钥加载

U-Boot 工具链支持从 FDT 加载 ECDSA 公钥:

- **PATCH 文件**: `v1-0001-lib-ecdsa-Add-support-for-loading-ECDSA-pubkey.patch`
- **功能**: 支持从 FIT 镜像设备树的 `/signature` 节点解析公钥
- **支持的曲线**: prime256v1 (P-256), secp384r1 (P-384)

```c
// 密钥属性格式
ecdsa,curve = "secp384r1";    // 曲线类型
ecdsa,x-point = [...];        // X 坐标 (48 bytes for P-384)
ecdsa,y-point = [...];        // Y 坐标 (48 bytes for P-384)
```

## 6. 多种启动变体

AST2700 支持多种启动配置:

| 配置文件 | 描述 | 设备树 |
|---------|------|--------|
| ast2700-default.conf | 默认配置 | ast2700-evb |
| ast2700-emmc.conf | eMMC 启动 | ast2700-evb |
| ast2700-ufs.conf | UFS 启动 | ast2700-evb |
| ast2700-rtos.conf | RTOS 支持 | ast2700-evb |
| ast2700-irot.conf | iROT 支持 | ast2700-evb |
| ast2700-default-ncsi.conf | NCSI 网络 | ast2700-ncsi |
| ast2700-default-raw.conf | 原始闪存 | ast2700-raw |
| ast2700-a1.conf | A1 硅片 | ast2700-evb |

### 6.1 启动存储配置

AST2700 支持多种启动介质:

```bitbake
# SPI Flash (默认)
UBOOT_ENV_SIZE:ast-mmc = "0x20000"
UBOOT_ENV:ast-mmc = "u-boot-env"
UBOOT_ENV_SUFFIX:ast-mmc = "bin"

# UFS
UBOOT_ENV_SIZE:ast-ufs = "0x20000"
UBOOT_ENV:ast-ufs = "u-boot-env"
UBOOT_ENV_SUFFIX:ast-ufs = "bin"
```

## 7. QEMU 支持

```bitbake
# QEMU 仿真配置
QB_SYSTEM_NAME = "qemu-system-aarch64"
QB_MACHINE = "-machine ast2700a1-evb"
QB_MEM = "-m 1G"
```

## 8. 关键依赖

| 依赖项 | 用途 |
|--------|------|
| bc-native | 引导脚本处理 |
| dtc-native | 设备树编译 |
| aspeed-secure-config-native | 安全启动配置 (可选) |
| flex-native, bison-native | 源码编译 |
| openssl-native | 签名工具 |
| kern-tools-native | 内核工具链 |
| mtd-utils | MTD 工具 |

## 9. 文件清单

### 9.1 配方文件位置

```
meta-aspeed-sdk/recipes-bsp/u-boot/
├── u-boot-common-aspeed-sdk_2023.10.inc  # 源码和版本配置
├── u-boot-aspeed-sdk_2023.10.bb          # 主配方
├── u-boot-aspeed.inc                     # 构建逻辑
├── u-boot-aspeed-sdk_%.bbappend          # 配方追加
├── u-boot-fw-utils-aspeed-sdk_2023.10.bb # fw_printenv 工具
└── u-boot-tools/
    └── v1-0001-lib-ecdsa-...patch        # ECDSA FDT 密钥加载补丁
```

### 9.2 机器配置文件位置

```
meta-aspeed-sdk/
├── conf/machine/include/ast2700-sdk.inc         # SOC 通用配置
└── meta-ast2700-sdk/conf/machine/
    ├── ast2700-default.conf                      # 默认机器配置
    ├── ast2700-emmc.conf
    ├── ast2700-ufs.conf
    └── include/
        ├── ast2700-secure-mode.inc              # 安全模式配置
        └── ast2700-secure-cot.inc               # 信任链配置
```