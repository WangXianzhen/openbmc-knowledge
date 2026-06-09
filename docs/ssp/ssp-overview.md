# AST2700 SSP (Silicon Security Processor) 概述

## 1. SSP 架构

### 1.1 什么是 SSP

SSP (Secondary Service Processor) 是 AST2700 BMC 芯片中的辅助服务处理器，用于卸载主处理器 (PSP/Cortex-A35) 的外设监控和控制任务。

### 1.2 处理器规格

| 参数 | AST2700 | AST2600 |
|------|---------|---------|
| **处理器类型** | ARM Cortex-M4F | ARM Cortex-M3 |
| **架构版本** | r0p1 | r2p1 |
| **用途** | 外设控制/监控 | 外设控制/监控 |

### 1.3 内存映射

```
+------------------+ 0xFFFFFFFF
|                  |
|   Reserved       |
|                  |
+------------------+ 0xB0000000
|                  |
|   TF-A (BL31)    | ARM Trusted Firmware
|                  |
+------------------+ 0xAC000000
|                  |
|   SSP Firmware   | <-- SSP LOADADDRESS = 0xAC000000
|                  |
+------------------+ 0x80000000
|                  |
|   U-Boot         |
|                  |
+------------------+ 0x00000000
```

## 2. SSP 固件配置

### 2.1 BitBake 配方

**文件**: `meta-aspeed-sdk/recipes-aspeed/ssp/ssp.bb`

```bitbake
SUMMARY = "The Secondary Service Processor (SSP) firmware"
DESCRIPTION = "The Secondary Service Processor (SSP) is an ARM Cortex-M3 r2p1 \
processor for AST2600 and ARM Cortex-M4F r0p1 processor for AST2700..."

PROVIDES += "virtual/ssp"

SSP_FIRMWARE ?= "ast2700-ssp.bin"
SSP_FIRMWARE:aspeed-g6 ?= "ast2600_ssp.bin"
```

### 2.2 固件文件

| 平台 | 固件文件 | ELF调试文件 | 大小 |
|------|----------|-------------|------|
| AST2700 | `ast2700-ssp.bin` | `ast2700-ssp.elf` | 71KB / 2.1MB |
| AST2600 | `ast2600_ssp.bin` | N/A | 40KB |

### 2.3 机器配置

**文件**: `meta-aspeed-sdk/conf/machine/include/ast-ssp.inc`

```bitbake
MACHINE_FEATURES:append = " ast-ssp"
MACHINEOVERRIDES .= ":ast-ssp"

# AST2700: Load SSP via U-Boot FIT
UBOOT_FIT_CONF_USER_LOADABLES:append:aspeed-g7 = ' ,"sspfw"'
```

### 2.4 FIT 镜像配置 (AST2700)

**文件**: `meta-aspeed-sdk/conf/machine/include/ast2700-sdk.inc`

```bitbake
UBOOT_FIT_SSP_ARCH ?= "arm"
UBOOT_FIT_SSP_OS ?= "zephyr"
UBOOT_FIT_SSP_LOADADDRESS ?= "0xac000000"
UBOOT_FIT_SSP_ENTRYPOINT ?= "0xac000000"
UBOOT_FIT_SSP_IMAGE ?= "${DEPLOY_DIR_IMAGE}/zephyr-aspeed-ssp.bin"
```

## 3. Zephyr RTOS 支持

### 3.1 Zephyr 固件构建

从 `ast2700-sdk.inc` 中的配置:

```bitbake
# Zephyr pre-built toolchain
ZEPHYR_TOOLCHAIN_VARIANT = "zephyr"

# Zephyr build
PREFERRED_PROVIDER_virtual/ssp ??= "zephyr-aspeed-ssp"
PREFERRED_VERSION_zephyr-kernel ??= "3.7.0"
```

### 3.2 Zephyr 配方

**文件**: `meta-aspeed-sdk/dynamic-layers/zephyrcore-layer/recipes-kernel/zephyr-aspeed/zephyr-aspeed-ssp_git.bb`

```bitbake
require recipes-kernel/zephyr-kernel/zephyr-image.inc
require zephyr-aspeed-src.inc

SUMMARY = "The Secondary Service Processor (SSP) firmware"
PROVIDES += "virtual/ssp"

ZEPHYR_BOARD_SSP ??= "ast2700_evb/ast2700/ssp_tsp"
ZEPHYR_BOARD = "${ZEPHYR_BOARD_SSP}"

ZEPHYR_SRC_DIR ??= "${ZEPHYR_BASE}/samples/subsys/shell/shell_module"
```

### 3.3 Zephyr 源代码分支

**文件**: `zephyr-aspeed-src.inc`

```bitbake
# Tag for v00.03.07
SRCREV_zephyr = "cfe94dc149ffa0af7e1af668a27f57eecf0cd1e9"
ZEPHYR_BRANCH = "aspeed-main-v3.7.0"

SRC_URI_ZEPHYR = "git://github.com/AspeedTech-BMC/zephyr;protocol=https"
```

## 4. IROT (Immutable Root of Trust) 支持

### 4.1 SSP IROT 固件

除了标准 SSP 固件，还提供安全增强版本:

**文件**: `zephyr-aspeed-ssp-irot_git.bb`

```bitbake
require recipes-kernel/zephyr-kernel/zephyr-image.inc
require zephyr-aspeed-src.inc
require zephyr-aspeed-project-src.inc

SUMMARY = "AST2700 SSP ASPEED-IROT Firmware"
PROVIDES += "virtual/ssp"

ZEPHYR_BOARD_SSP ?= "ast2700_evb/ast2700/ssp"
ZEPHYR_BOARD = "${ZEPHYR_BOARD_SSP}"

ZEPHYR_SRC_DIR ??= "${S}/aspeed-zephyr-project/apps/aspeed-irot"
```

### 4.2 IROT 特性

- **IROT**: Immutable Root of Trust - 不可变信任根
- 支持安全启动验证
- 用于高安全场景

## 5. 启动流程

### 5.1 完整启动流程

```
+------------------------------------------------------------------+
|                        BootROM (ROM)                             |
|                     (不可变的信任根)                              |
+-------------------------------+----------------------------------+
                                | 验证并执行
                                v
+------------------------------------------------------------------+
|                   FMC (First Mutable Code)                       |
|                     BootMCU (RISC-V Ibex)                        |
+-------------------------------+----------------------------------+
                                | 验证并执行
                                v
+------------------------------------------------------------------+
|                    BL31 (TF-A Trusted Firmware)                  |
+-------------------------------+----------------------------------+
                                | 验证并执行
                                v
+------------------------------------------------------------------+
|                      OP-TEE (可信执行环境)                        |
+-------------------------------+----------------------------------+
                                | 验证并执行
                                v
+------------------------------------------------------------------+
|                         U-Boot                                   |
|                                                                      |
|  +----------------+  +----------------+  +----------------+         |
|  |   sspfw        |  |   tspfw        |  |   ibexfw       |         |
|  |  (SSP固件)     |  |  (TSP固件)     |  |  (Ibex固件)    |         |
|  +----------------+  +----------------+  +----------------+         |
|         ^                  ^                  ^                      |
|         |                  |                  |                      |
+---------+------------------+------------------+----------------------+
                                | 验证FIT签名
                                v
+------------------------------------------------------------------+
|                     Linux Kernel FIT Image                        |
+------------------------------------------------------------------+
```

### 5.2 U-Boot FIT 配置

SSP、TSP 和 Ibexfw 通过 U-Boot 的 USER_LOADABLES 机制加载:

```bash
# AST2700 SSP via FIT
UBOOT_FIT_CONF_USER_LOADABLES:append:aspeed-g7 = ' ,"sspfw"'

# 所有平台的 TSP via FIT  
UBOOT_FIT_CONF_USER_LOADABLES:append = ' ,"tspfw"'

# Ibexfw via FIT firmware node
UBOOT_FIT_CONF_FIRMWARE = "ibexfw"
```

## 6. 内核模块

### 6.1 aspeed-ssp 模块

SSP 固件需要对应的内核模块进行通信:

```bitbake
# packagegroup-aspeed-coprocessor.bb
RRECOMMENDS:${PN}-ssp = " \
    kernel-module-aspeed-ssp \
    "
```

### 6.2 模块配置

**文件**: `ast-ssp.inc`

```bitbake
# AST2600: Do not load the "aspeed-ssp" module on boot.
KERNEL_MODULE_PROBECONF:append:aspeed-g6 = " aspeed-ssp"
module_conf_aspeed-ssp = "blacklist aspeed-ssp"
```

## 7. 软件包组

### 7.1 Coprocessor 包组

**文件**: `packagegroup-aspeed-coprocessor.bb`

```bitbake
PACKAGES = " \
    ${PN}-ssp \
    "

SUMMARY:${PN}-ssp = "AspeedTech Secondary Service Processor"
RDEPENDS:${PN}-ssp = " \
    virtual-ssp \
    "
RRECOMMENDS:${PN}-ssp = " \
    kernel-module-aspeed-ssp \
    "
```

## 8. 构建说明

### 8.1 独立构建 SSP

```bash
# 设置构建环境
cd /path/to/openbmc
. setup ast2700-default

# 构建 SSP 固件
bitbake zephyr-aspeed-ssp

# 或者使用 IROT 版本
bitbake zephyr-aspeed-ssp-irot
```

### 8.2 构建完整镜像

```bash
# 构建完整 BMC 镜像 (包含所有固件)
bitbake obmc-phosphor-image

# 查看部署的固件
ls tmp/deploy/images/ast2700-default/
# - zephyr-aspeed-ssp.bin
# - zephyr-aspeed-tsp.bin
# - zephyr-aspeed-ibexfw.bin
```

## 9. 相关文件列表

| 类型 | 路径 |
|------|------|
| **SSP 配方** | `meta-aspeed-sdk/recipes-aspeed/ssp/ssp.bb` |
| **Zephyr SSP** | `dynamic-layers/zephyrcore-layer/recipes-kernel/zephyr-aspeed/zephyr-aspeed-ssp_git.bb` |
| **Zephyr IROT** | `dynamic-layers/zephyrcore-layer/recipes-kernel/zephyr-aspeed/zephyr-aspeed-ssp-irot_git.bb` |
| **Zephyr 源码配置** | `dynamic-layers/zephyrcore-layer/recipes-kernel/zephyr-aspeed/zephyr-aspeed-src.inc` |
| **机器配置** | `conf/machine/include/ast-ssp.inc` |
| **包组** | `recipes-aspeed/packagegroups/packagegroup-aspeed-coprocessor.bb` |
| **固件源码** | `https://github.com/AspeedTech-BMC/aspeed-zephyr-project` (branch: aspeed-master) |

## 10. 总结

AST2700 的 SSP 是一个基于 ARM Cortex-M4F 的辅助处理器，在 Zephyr RTOS 上运行，负责外设监控和控制功能。通过 FIT 镜像机制与主系统安全集成，支持标准版和安全 (IROT) 版固件。