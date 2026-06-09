# AST2700 RTOS 支持

## 1. 概述

AST2700 BMC 芯片上的协处理器 (SSP, TSP, BootMCU, Ibex) 均使用 Zephyr RTOS 作为运行时固件。本文档详细介绍 Zephyr RTOS 支持架构。

## 2. Zephyr RTOS 版本

| 参数 | 版本 |
|------|------|
| **Zephyr 内核版本** | 3.7.0 |
| **Zephyr SDK 版本** | 0.16.9 |
| **Aspeed 维护分支** | `aspeed-main-v3.7.0` |

## 3. Zephyr 源码配置

### 3.1 源码配方

**文件**: `dynamic-layers/zephyrcore-layer/recipes-kernel/zephyr-aspeed/zephyr-aspeed-src.inc`

```bitbake
# Tag for v00.03.07
SRCREV_zephyr = "cfe94dc149ffa0af7e1af668a27f57eecf0cd1e9"
ZEPHYR_BRANCH = "aspeed-main-v3.7.0"

SRCREV_mbedtls = "a78176c6ff0733ba08018cba4447bd3f20de7978"
SRCREV_cmsis = "4b96cbb174678dcd3ca86e11e1f24bc5f8726da0"

SRC_URI_ZEPHYR = "git://github.com/AspeedTech-BMC/zephyr;protocol=https"
SRC_URI_ZEPHYR_MBEDTLS = "git://github.com/zephyrproject-rtos/mbedtls;protocol=https"
SRC_URI_ZEPHYR_CMSIS = "git://github.com/zephyrproject-rtos/cmsis;protocol=https"
```

### 3.2 Zephyr 模块

```bitbake
ZEPHYR_MODULES = "\
${S}/modules/crypto/mbedtls\;\
${S}/modules/hal/cmsis\;\
"
```

### 3.3 Aspeed Zephyr 项目

**文件**: `zephyr-aspeed-project-src.inc`

```bitbake
# aspeed-zephyr-project bootmcu
SRC_URI_ASPEED_ZEPHYR_PROJECT = "gitsm://github.com/AspeedTech-BMC/aspeed-zephyr-project;protocol=https"
ASPEED_ZEPHYR_PROJECT_BRANCH ??= "aspeed-master"

# Tag for v03.06
SRCREV_app = "4214794e852eafdc5ee32bcecf888db216e7722c"

ZEPHYR_MODULES:append = "\
${S}/aspeed-zephyr-project\;\
"

ZEPHYR_SRC_DIR ??= "${S}/aspeed-zephyr-project/apps/mcu-runtime"
```

## 4. 协处理器 Zephyr 固件

### 4.1 固件列表

| 协处理器 | 配方文件 | Zephyr Board | 源码路径 |
|----------|----------|--------------|----------|
| **SSP** | `zephyr-aspeed-ssp_git.bb` | `ast2700_evb/ast2700/ssp_tsp` | `samples/subsys/shell/shell_module` |
| **TSP** | `zephyr-aspeed-tsp_git.bb` | `ast2700_evb/ast2700/tsp` | `samples/subsys/shell/shell_module` |
| **BootMCU** | `zephyr-aspeed-bootmcu_git.bb` | `ast2700_evb/ast2700/bootmcu` | `samples/boards/ast2700_evb/demo` |
| **Ibexfw** | `zephyr-aspeed-ibexfw_git.bb` | `ast2700_evb/ast2700/bootmcu` | `samples/boards/ast2700_evb/demo` |

### 4.2 SSP (Secondary Service Processor)

**文件**: `zephyr-aspeed-ssp_git.bb`

```bitbake
require recipes-kernel/zephyr-kernel/zephyr-image.inc
require zephyr-aspeed-src.inc

SUMMARY = "The Secondary Service Processor (SSP) firmware"
PROVIDES += "virtual/ssp"

ZEPHYR_BOARD_SSP ??= "ast2700_evb/ast2700/ssp_tsp"
ZEPHYR_BOARD = "${ZEPHYR_BOARD_SSP}"

ZEPHYR_SRC_DIR ??= "${ZEPHYR_BASE}/samples/subsys/shell/shell_module"
```

### 4.3 TSP (Tertiary Service Processor)

**文件**: `zephyr-aspeed-tsp_git.bb`

```bitbake
require recipes-kernel/zephyr-kernel/zephyr-image.inc
require zephyr-aspeed-src.inc

SUMMARY = "The Tertiary Service Processor (TSP) firmware"
PROVIDES += "virtual/tsp"

ZEPHYR_BOARD_TSP ??= "ast2700_evb/ast2700/tsp"
ZEPHYR_BOARD = "${ZEPHYR_BOARD_TSP}"

ZEPHYR_SRC_DIR ??= "${ZEPHYR_BASE}/samples/subsys/shell/shell_module"
```

### 4.4 BootMCU (FMC 固件)

**文件**: `zephyr-aspeed-bootmcu_git.bb`

```bitbake
require recipes-kernel/zephyr-kernel/zephyr-image.inc
require zephyr-aspeed-src.inc
require zephyr-aspeed-project-src.inc

SUMMARY = "BootMCU runtime firmware"
PROVIDES += "virtual/bootmcu"

ZEPHYR_BOARD_BOOTMCU ??= "ast2700_evb/ast2700/bootmcu"
ZEPHYR_BOARD = "${ZEPHYR_BOARD_BOOTMCU}"
ZEPHYR_ASPEED_OUTPUT = "${BOOTMCU_FMC_BINARY} ${BOOTMCU_FW_BINARY}"

DEPENDS += "fmc-imgtool-native"

inherit otptool

# FMC 镜像生成 (支持签名)
do_create_fmc_image() {
    # ...
    fmc-imgtool \
        --verbose \
        --version 2 \
        --input ${B}/zephyr/zephyr.bin \
        --output ${B}/zephyr/${BOOTMCU_FMC_BINARY} \
        --prebuilt-dir ${DEPLOY_DIR_IMAGE}/ \
        ${sign_args}
}
```

### 4.5 Ibexfw (RISC-V 核心固件)

**文件**: `zephyr-aspeed-ibexfw_git.bb`

```bitbake
require recipes-kernel/zephyr-kernel/zephyr-image.inc
require zephyr-aspeed-src.inc

SUMMARY = "Ibex firmware"
PROVIDES += "virtual/ibexfw"

ZEPHYR_BOARD_IBEXFW ??= "ast2700_evb/ast2700/bootmcu"
ZEPHYR_BOARD = "${ZEPHYR_BOARD_IBEXFW}"

ZEPHYR_SRC_DIR ??= "${ZEPHYR_BASE}/samples/boards/ast2700_evb/demo"
```

## 5. 机器配置

### 5.1 AST2700 SDK 配置

**文件**: `conf/machine/include/ast2700-sdk.inc`

```bitbake
# Zephyr pre-built toolchain
ZEPHYR_TOOLCHAIN_VARIANT = "zephyr"

# Zephyr build
PREFERRED_PROVIDER_virtual/ssp ??= "zephyr-aspeed-ssp"
PREFERRED_PROVIDER_virtual/tsp ??= "zephyr-aspeed-tsp"
PREFERRED_PROVIDER_virtual/ibexfw ??= "zephyr-aspeed-ibexfw"

PREFERRED_VERSION_zephyr-sdk-native = "0.16.9"
PREFERRED_VERSION_zephyr-kernel ??= "3.7.0"
```

### 5.2 RTOS Feature 配置

**文件**: `conf/machine/include/ast-rtos.inc`

```bitbake
MACHINE_FEATURES:append = " ast-rtos"
MACHINEOVERRIDES .= ":ast-rtos"
```

## 6. FIT 镜像内存映射

### 6.1 协处理器地址

| 组件 | 架构 | OS | 加载地址 | 入口地址 | 镜像文件 |
|------|------|-----|----------|----------|----------|
| **SSP** | arm | zephyr | 0xAC000000 | 0xAC000000 | `zephyr-aspeed-ssp.bin` |
| **TSP** | arm | zephyr | 0xAE000000 | 0xAE000000 | `zephyr-aspeed-tsp.bin` |
| **Ibexfw** | riscv | zephyr | 0x14BA8000 | 0x14BA8000 | `zephyr-aspeed-ibexfw.bin` |

**文件**: `ast2700-sdk.inc`

```bitbake
UBOOT_FIT_SSP_ARCH ?= "arm"
UBOOT_FIT_SSP_OS ?= "zephyr"
UBOOT_FIT_SSP_LOADADDRESS ?= "0xac000000"
UBOOT_FIT_SSP_ENTRYPOINT ?= "0xac000000"

UBOOT_FIT_TSP_ARCH ?= "arm"
UBOOT_FIT_TSP_OS ?= "zephyr"
UBOOT_FIT_TSP_LOADADDRESS ?= "0xae000000"
UBOOT_FIT_TSP_ENTRYPOINT ?= "0xae000000"

UBOOT_FIT_IBEXFW_ARCH ?= "riscv"
UBOOT_FIT_IBEXFW_OS ?= "zephyr"
UBOOT_FIT_IBEXFW_LOADADDRESS ?= "0x14ba8000"
UBOOT_FIT_IBEXFW_ENTRYPOINT ?= "0x14ba8000"
```

### 6.2 完整内存映射

```
0xFFFFFFFF +----------------------------------+
           |                                  |
           |       Reserved / PCIe           |
           |                                  |
0x1C000000 +----------------------------------+
           |                                  |
           |         DRAM (2GB)              |
           |                                  |
0x14000000 +----------------------------------+
           |                                  |
           |   Ibex (RISC-V) TCM @ 16KB     |
           |       0x14BA8000               |
           |                                  |
0xB0080000 +----------------------------------+
           |                                  |
           |     OP-TEE OS (128KB)           |
           |                                  |
0xB0000000 +----------------------------------+
           |                                  |
           |    BL31 / TF-A (ARM Trusted     |
           |         Firmware)               |
           |                                  |
0xAE000000 +----------------------------------+
           |                                  |
           |   TSP (Tertiary Service Proc)   |
           |         128KB Flash             |
           |                                  |
0xAC000000 +----------------------------------+
           |                                  |
           |   SSP (Secondary Service Proc)  |
           |         128KB Flash             |
           |                                  |
0x80000000 +----------------------------------+
           |                                  |
           |          U-Boot                 |
           |                                  |
0x00000000 +----------------------------------+
```

## 7. 构建说明

### 7.1 环境准备

```bash
# 初始化构建环境
cd /path/to/openbmc
. setup ast2700-default
```

### 7.2 独立构建协处理器固件

```bash
# 构建 SSP 固件
bitbake zephyr-aspeed-ssp

# 构建 TSP 固件
bitbake zephyr-aspeed-tsp

# 构建 BootMCU 固件
bitbake zephyr-aspeed-bootmcu

# 构建 Ibexfw 固件
bitbake zephyr-aspeed-ibexfw

# 构建所有协处理器
bitbake zephyr-aspeed-ssp zephyr-aspeed-tsp zephyr-aspeed-bootmcu zephyr-aspeed-ibexfw
```

### 7.3 查看构建产物

```bash
# 查看部署的固件
ls tmp/deploy/images/ast2700-default/zephyr-aspeed-*.bin

# 验证固件大小
ls -la tmp/deploy/images/ast2700-default/zephyr-aspeed-ssp.bin
ls -la tmp/deploy/images/ast2700-default/zephyr-aspeed-tsp.bin
ls -la tmp/deploy/images/ast2700-default/zephyr-aspeed-ibexfw.bin
```

### 7.4 构建完整镜像

```bash
# 包含所有固件的完整镜像
bitbake obmc-phosphor-image

# 输出文件
# - image-bmc: 完整 Flash 镜像
# - zephyr-aspeed-*.bin: 各个协处理器固件
```

## 8. 源码仓库

| 仓库 | URL | 用途 |
|------|-----|------|
| **zephyr** | `https://github.com/AspeedTech-BMC/zephyr` (branch: aspeed-main-v3.7.0) | Zephyr RTOS 内核 |
| **aspeed-zephyr-project** | `https://github.com/AspeedTech-BMC/aspeed-zephyr-project` (branch: aspeed-master) | Aspeed 专有应用 |
| **mbedtls** | `https://github.com/zephyrproject-rtos/mbedtls` | 加密库 |
| **cmsis** | `https://github.com/zephyrproject-rtos/cmsis` | ARM CMSIS 库 |

## 9. 协处理器功能

### 9.1 SSP 功能

- 外设时钟管理
- GPIO 控制
- PWM 生成
- 看门狗监控
- 定时器管理

### 9.2 TSP 功能

- 高级外设控制
- 系统监控
- 传感器数据采集

### 9.3 BootMCU/Ibex 功能

- FMC (First Mutable Code) 运行时
- 安全启动验证 (A1 芯片)
- 密钥存储访问

## 10. 调试

### 10.1 启用 Shell 模块

所有协处理器默认使用 Zephyr shell 模块:

```bash
# ZEPHYR_SRC_DIR 配置
ZEPHYR_SRC_DIR ??= "${ZEPHYR_BASE}/samples/subsys/shell/shell_module"
```

### 10.2 串口访问

协处理器通过独立串口或共享 UART 与主系统通信:

```bash
# 查看日志
# 通常通过 /dev/ttyS* 访问
```

## 11. 总结

AST2700 的所有协处理器均基于 Zephyr RTOS 3.7.0 构建，由 Aspeed 维护的 Zephyr 分支提供支持。固件通过 U-Boot FIT 镜像机制与主系统集成，支持 ARM (SSP/TSP) 和 RISC-V (Ibex) 两种架构。