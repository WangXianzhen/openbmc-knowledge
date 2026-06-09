# BootMCU Overview - BootMCU 在启动流程中的角色

## 1. 概述

AST2700 BootMCU (AST2700-MCU Runtime) 是运行在 RISC-V 32 位处理器上的固件组件，在芯片的信任链中扮演关键角色。作为第一级可验证代码 (First Mutable Code, FMC)，它负责初始化并加载后续的安全组件。

### 1.1 核心职责

| 职责 | 描述 |
|------|------|
| **信任链第一环** | BootROM 之后的第一个可更新代码组件 |
| **FMC 验证** | 验证 BootROM 中 OTP 存储的公钥哈希 |
| **后续加载** | 验证并加载 BL31 (TF-A) 或 Caliptra |
| **安全启动** | 支持 ECDSA384/SHA384/LMS 签名验证 |

## 2. 硬件架构

### 2.1 处理器

```
BootMCU 处理器规格:
- 架构: RISC-V 32-bit
- 指令集: RV32IMAC (整数 + 乘除 + 原子操作 + 压缩指令)
- 配置: ibex-ast2700_defconfig
- 工具链: ast2700-riscv-linux-gnu
```

### 2.2 内存映射

| 地址范围 | 组件 | 说明 |
|----------|------|------|
| 0x00000000 - 0x0FFFFFFF | BootROM | 芯片内置，不可修改 |
| 0x10000000 - 0x13FFFFFF | SRAM | MCU 工作内存 |
| 0x14BA8000 | IBEX FW | BootMCU 固件入口点 |

## 3. 启动流程

### 3.1 完整信任链

```
┌─────────────────────────────────────────────────────────────────┐
│                        BootROM (ROM)                            │
│                   (不可变的硬件信任根)                           │
│                   地址: 0x00000000 开始                          │
└────────────────────────────┬────────────────────────────────────┘
                             │ 读取 OTP Root Key Hash
                             │ 验证 BootMCU (FMC) 签名
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              BootMCU (AST2700-MCU Runtime)                      │
│         RISC-V 32-bit, Zephyr RTOS, FMC 分区                    │
│                   地址: FMC 分区起始                             │
└────────────────────────────┬────────────────────────────────────┘
                             │ 验证并加载
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    BL31 (Trusted Firmware-A)                    │
│              ARM Cortex-A35, 加载地址: 0xB0000000               │
│              由 Caliptra Manifest 签名验证                       │
└────────────────────────────┬────────────────────────────────────┘
                             │ 验证并执行
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      OP-TEE (Trusted OS)                        │
│              地址: 0xB0080000                                    │
│              由 Caliptra Manifest 签名验证                       │
└────────────────────────────┬────────────────────────────────────┘
                             │ 验证并执行
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                         U-Boot                                  │
│              ARM Cortex-A35, 加载地址: 0x80000000               │
│         由 Kernel FIT 镜像签名验证 (ecdsa384/sha384)            │
└────────────────────────────┬────────────────────────────────────┘
                             │ 验证并执行
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Linux Kernel FIT Image                      │
│         由 U-Boot 使用嵌入的公钥进行验证                        │
└─────────────────────────────────────────────────────────────────┘
```

## 4. BootMCU 与其他芯片版本的关系

### 4.1 AST2700 A1 vs A2 差异

| 特性 | AST2700 A1 | AST2700 A2 |
|------|------------|------------|
| **BootMCU 位置** | 独立 FMC 分区 | 集成在 Caliptra Manifest 中 |
| **FMC 签名要求** | 必须签名 | 不需要 FMC 签名 |
| **Flash 布局** | Caliptra + BootMCU + U-Boot | Caliptra Manifest (含 BootMCU) |
| **恢复镜像** | BootMCU + Caliptra | 仅 Caliptra |

### 4.2 架构差异图

#### AST2700 A1

```
┌──────────┐    ┌──────────────┐    ┌────────────┐    ┌──────────┐
│  BootROM │───▶│    BootMCU   │───▶│   BL31     │───▶│  U-Boot  │
│          │    │  (FMC签名)   │    │ (Caliptra) │    │(FIT签名) │
└──────────┘    └──────────────┘    └────────────┘    └──────────┘
     │                 │                   │                │
     │ 验证OTP         │ 验证OTP中DSS      │ 验证Caliptra   │ 验证FIT
     │ Root Key        │ 公钥              │ Manifest       │ 签名
```

#### AST2700 A2

```
┌──────────┐    ┌────────────┐    ┌────────────┐    ┌──────────┐
│  BootROM │───▶│  Caliptra  │───▶│   BL31     │───▶│  U-Boot  │
│          │    │ (含FMC功能)│    │ (Caliptra) │    │(FIT签名) │
└──────────┘    └────────────┘    └────────────┘    └──────────┘
     │                 │                   │                │
     │ 验证OTP         │ 验证Caliptra      │ 验证Caliptra   │ 验证FIT
     │ Root Key        │ OTP中公钥         │ Manifest       │ 签名
```

## 5. 关键配置文件

### 5.1 配方文件位置

```
meta-aspeed-sdk/
├── recipes-bsp/bootmcu/
│   ├── bootmcu-spl.inc           # SPL 构建配置
│   └── bootmcu-spl_2023.10.bb    # 配方文件
├── dynamic-layers/zephyrcore-layer/recipes-kernel/zephyr-aspeed/
│   └── zephyr-aspeed-bootmcu_git.bb  # Zephyr BootMCU (A2)
└── meta-vendor/meta-vendor-amd/meta-amd-sp7/recipes-kernel/zephyr-aspeed/
    └── zephyr-aspeed-bootmcu-a1_git.bb  # Zephyr BootMCU (A1)
```

### 5.2 机器配置

```bash
# AST2700 A1
meta-aspeed-sdk/meta-ast2700-sdk/conf/machine/ast2700-a1.conf

# AST2700 A2 (默认)
meta-aspeed-sdk/meta-ast2700-sdk/conf/machine/ast2700-default.conf
```

## 6. 安全特性

### 6.1 签名验证

| 阶段 | 验证算法 | 密钥来源 |
|------|----------|----------|
| BootROM -> BootMCU | ECDSA384/SHA384 | OTP 中的 Root Key Hash |
| BootMCU -> BL31 | Caliptra Manifest | Caliptra 内部密钥 |
| U-Boot -> Kernel | FIT 签名 | U-Boot DTB 嵌入公钥 |

### 6.2 抗量子攻击

AST2700 支持 LMS (Leighton-Micali Signature) 算法作为量子安全增强选项:

```bash
# 启用 LMS 签名验证
Enable_LMS_verify = true
```

## 7. 调试与开发

### 7.1 串口调试

BootMCU 通过 UART 输出启动日志:

```bash
# 串口配置
波特率: 115200
数据位: 8
停止位: 1
校验: 无
```

### 7.2 构建调试版本

```bash
# 在 local.conf 中启用调试
EXTRA_OEMAKE += 'DEBUG=1'
UBOOT_LOCALVERSION = "-debug"
```

## 8. 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| 1.0 | 2024-12-11 | 初始版本 |
| 2.0 | 2025-06-09 | 更新 A1/A2 差异说明 |