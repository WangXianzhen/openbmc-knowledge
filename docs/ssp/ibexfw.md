# AST2700 Ibex 微控制器固件

## 1. 概述

Ibex 是一个 32 位 RISC-V 微控制器内核，集成在 AST2700 BMC 芯片中，作为 BootMCU (First Mutable Code) 运行时环境。

## 2. Ibex 内核规格

### 2.1 内核特性

| 参数 | 规格 |
|------|------|
| **架构** | RISC-V RV32IMC |
| **位宽** | 32 位 |
| **指令集** | RV32I + M (乘法) + C (压缩) |
| **TCM 大小** | 16KB (Tightly Coupled Memory) |
| **中断数** | 16 个本地中断 + 外部中断 |
| **特性** | PMP (Physical Memory Protection) |

### 2.2 内存映射

```
Ibex TCM (16KB)
+----------+ 0x14BA8000 (Load Address)
|          |
|  Firmware|
|   .text  |
|          |
+----------+
|          |
|  .rodata |
|          |
+----------+
|          |
|  .data   |
|          |
+----------+ 0x14BAC000
```

## 3. 固件架构

### 3.1 双固件配置

AST2700 使用两个不同的 Ibex 固件:

| 固件 | 用途 | 加载地址 |
|------|------|----------|
| **BootMCU (FMC)** | 安全启动第一阶段 | 0x14BA8000 |
| **Ibexfw** | 运行时固件 | 0x14BA8000 |

### 3.2 BootMCU 固件

**文件**: `dynamic-layers/zephyrcore-layer/recipes-kernel/zephyr-aspeed/zephyr-aspeed-bootmcu_git.bb`

```bitbake
SUMMARY = "BootMCU runtime firmware"
PROVIDES += "virtual/bootmcu"

ZEPHYR_BOARD_BOOTMCU ??= "ast2700_evb/ast2700/bootmcu"
ZEPHYR_BOARD = "${ZEPHYR_BOARD_BOOTMCU}"

# 输出两个文件: FMC 镜像 + 原始固件
ZEPHYR_ASPEED_OUTPUT = "${BOOTMCU_FMC_BINARY} ${BOOTMCU_FW_BINARY}"
```

### 3.3 Ibexfw 固件

**文件**: `dynamic-layers/zephyrcore-layer/recipes-kernel/zephyr-aspeed/zephyr-aspeed-ibexfw_git.bb`

```bitbake
SUMMARY = "Ibex firmware"
PROVIDES += "virtual/ibexfw"

ZEPHYR_BOARD_IBEXFW ??= "ast2700_evb/ast2700/bootmcu"
ZEPHYR_BOARD = "${ZEPHYR_BOARD_IBEXFW}"

ZEPHYR_SRC_DIR ??= "${ZEPHYR_BASE}/samples/boards/ast2700_evb/demo"
```

## 4. BitBake 配方

### 4.1 源码配方 (已弃用)

**文件**: `recipes-aspeed/ibexfw/ibexfw.bb`

```bitbake
SUMMARY = "Ibex firmware"
DESCRIPTION = "Ibex firmware for AST2700."
LICENSE = "Apache-2.0"
PACKAGE_ARCH = "${MACHINE_ARCH}"

PROVIDES += "virtual/ibexfw"

IBEX_FIRMWARE ?= "ast2700-ibex-fw.bin"

S = "${UNPACKDIR}"
SRC_URI = "file://${IBEX_FIRMWARE}"

do_patch[noexec] = "1"
do_configure[noexec] = "1"
do_compile[noexec] = "1"

inherit deploy

do_deploy () {
    install -d ${DEPLOYDIR}
    install -m 644 ${S}/${IBEX_FIRMWARE} ${DEPLOYDIR}/.
}
```

### 4.2 固件文件

```bash
# 预编译固件
$ ls -la recipes-aspeed/ibexfw/ibexfw/
ast2700-ibex-fw.bin  # 46KB 预编译固件
```

## 5. 机器配置

### 5.1 Ibexfw Feature

**文件**: `conf/machine/include/ast-ibexfw.inc`

```bitbake
MACHINE_FEATURES:append = " ast-ibexfw"
MACHINEOVERRIDES .= ":ast-ibexfw"

# FIT 固件节点配置
UBOOT_FIT_CONF_FIRMWARE = "ibexfw"
```

### 5.2 AST2700 SDK 配置

**文件**: `conf/machine/include/ast2700-sdk.inc`

```bitbake
# Ibexfw FIT 配置
UBOOT_FIT_IBEXFW_ARCH ?= "riscv"
UBOOT_FIT_IBEXFW_OS ?= "zephyr"
UBOOT_FIT_IBEXFW_LOADADDRESS ?= "0x14ba8000"
UBOOT_FIT_IBEXFW_ENTRYPOINT ?= "0x14ba8000"

# 部署镜像
UBOOT_FIT_IBEXFW_IMAGE ?= "${DEPLOY_DIR_IMAGE}/zephyr-aspeed-ibexfw.bin"

# 首选提供者
PREFERRED_PROVIDER_virtual/ibexfw ??= "zephyr-aspeed-ibexfw"
```

## 6. FIT 镜像集成

### 6.1 U-Boot FIT 配置

Ibexfw 通过 FIT 镜像的 FIRMWARE 节点加载:

```bash
# 设备树配置示例
/ {
    firmware {
        ibexfw {
            description = "Ibex RISC-V microcontroller firmware";
            firmware = "zephyr-aspeed-ibexfw.bin";
            load = <0x14ba8000>;
            entry = <0x14ba8000>;
            arch = "riscv";
            os = "zephyr";
            type = "firmware";
        };
    };
};
```

### 6.2 加载流程

```
BootROM --> FMC/BootMCU (验证) --> BL31/OP-TEE --> U-Boot --> 
    |
    +--> 加载 Ibexfw FIT 节点
    |         |
    |         v
    |    +-----------+
    |    | Ibex TCM  |
    |    | 0x14BA8000|
    |    +-----------+
    |         |
    v         v
  Linux Kernel
```

## 7. Zephyr RTOS 支持

### 7.1 源码配置

从 `zephyr-aspeed-src.inc`:

```bitbake
# RISC-V 架构支持已内置于 Zephyr
# Aspeed 维护的 Zephyr 分支包含完整的 Ibex 支持
ZEPHYR_BRANCH = "aspeed-main-v3.7.0"
```

### 7.2 Zephyr 板级支持

Board 配置: `ast2700_evb/ast2700/bootmcu`

```
zephyr/boards/riscv/ast2700_evb/
+-- Kconfig.board
+-- Kconfig.defconfig
+-- ast2700-evb.yaml
+-- board.cmake
+-- board.h
+-- CMakeLists.txt
+-- prebuilt/
|   +-- bootmcu.elf    # 预编译 BootROM 接口
+-- zephyr/
    +-- export.h
    +-- linker.ld
    +-- main.c
    +-- pinmux.c
```

### 7.3 Zephyr 源码示例

**文件**: `samples/boards/ast2700_evb/demo`

这是 Ibex 固件的默认源码路径，提供:
- 基础系统初始化
- 外设驱动
- 与主系统的通信接口

## 8. 安全功能

### 8.1 PMP (Physical Memory Protection)

Ibex 内置 PMP 模块，提供内存区域保护:

```c
// PMP 配置示例
void pmp_init(void) {
    // 配置只读区域
    // 配置执行区域
    // 配置共享内存访问
}
```

### 8.2 安全启动

**A1 芯片**: FMC 需要 ECDSA 签名验证

```bash
# FMC 镜像生成 (A1)
fmc-imgtool \
    --version 2 \
    --input zephyr.bin \
    --output bootmcu_fmc.bin \
    --prebuilt-dir ${DEPLOY_DIR_IMAGE}/ \
    --ecc-key pri.pem \
    --ecc-key-index 0
```

**A2 芯片**: FMC 集成在 Caliptra 中，无需单独签名

### 8.3 Caliptra Manifest

**文件**: `configs/ast2700/caliptra/ast2700-default-ecc-lms-manifest.toml`

```toml
# 镜像运行时列表
[image_runtime_list]
caliptra_file = "caliptra-fw.bin"
mcu_file = "zephyr-aspeed-bootmcu.bin"

# 镜像元数据
[[image_metadata_list]]
file = "zephyr-aspeed-bootmcu.bin"
source = 1
fw_id = 1
ignore_auth_check = false
load_stage = 0  # 早期加载
```

## 9. 构建说明

### 9.1 独立构建

```bash
# 初始化构建环境
. setup ast2700-default

# 构建 Ibexfw 固件
bitbake zephyr-aspeed-ibexfw

# 构建 BootMCU 固件 (FMC)
bitbake zephyr-aspeed-bootmcu
```

### 9.2 构建产物

```bash
# 查看部署的固件
ls -la tmp/deploy/images/ast2700-default/zephyr-aspeed-ibexfw.bin
ls -la tmp/deploy/images/ast2700-default/bootmcu_fmc.bin (A1)
ls -la tmp/deploy/images/ast2700-default/bootmcu_fw.bin
```

### 9.3 固件大小

| 固件 | 大小 |
|------|------|
| `ast2700-ibex-fw.bin` (预编译) | 46KB |
| `zephyr-aspeed-ibexfw.bin` | 可变 |
| `bootmcu_fmc.bin` | 可变 |
| `bootmcu_fw.bin` | 可变 |

## 10. 调试

### 10.1 JTAG 调试

Ibex 支持 JTAG 调试接口:

```
+-------------+
|    JTAG     |
|   (TCK,     |
|    TMS,     |
|    TDI,     |
|    TDO)     |
+------+------+
       |
       v
+-------------+
|    Ibex     |
|   Debug     |
|   Module    |
+-------------+
```

### 10.2 OpenOCD 支持

```bash
# OpenOCD 配置示例
# 使用 OpenOCD + RISC-V 调试器
openocd -f interface/xxx.cfg -c "adapter speed 10000" \
    -c "init" -c "halt"
```

### 10.3 GDB 调试

```bash
# 连接到 OpenOCD
riscv64-unknown-elf-gdb zephyr.elf

# 连接目标
target remote localhost:3333

# 加载符号
symbol-file zephyr.elf

# 断点设置
break main
break bootmcu_init
```

## 11. 源码仓库

| 仓库 | URL | 用途 |
|------|-----|------|
| **Zephyr** | `https://github.com/AspeedTech-BMC/zephyr` (aspeed-main-v3.7.0) | RTOS 内核和 Ibex 板级支持 |
| **aspeed-zephyr-project** | `https://github.com/AspeedTech-BMC/aspeed-zephyr-project` | Aspeed 专有应用和驱动 |

## 12. 相关文件列表

| 类型 | 路径 |
|------|------|
| **Ibexfw 配方 (旧)** | `recipes-aspeed/ibexfw/ibexfw.bb` |
| **BootMCU 配方** | `dynamic-layers/zephyrcore-layer/recipes-kernel/zephyr-aspeed/zephyr-aspeed-bootmcu_git.bb` |
| **Ibexfw 配方 (新)** | `dynamic-layers/zephyrcore-layer/recipes-kernel/zephyr-aspeed/zephyr-aspeed-ibexfw_git.bb` |
| **机器配置** | `conf/machine/include/ast-ibexfw.inc` |
| **AST2700 SDK** | `conf/machine/include/ast2700-sdk.inc` |
| **预编译固件** | `recipes-aspeed/ibexfw/ibexfw/ast2700-ibex-fw.bin` |

## 13. 总结

AST2700 的 Ibex RISC-V 微控制器是安全启动链中的关键组件。A1 芯片使用它作为 BootMCU (FMC) 执行安全验证，A2 芯片则将 FMC 功能集成到 Caliptra 中。固件基于 Zephyr RTOS 构建，支持 RISC-V 架构的标准调试接口。