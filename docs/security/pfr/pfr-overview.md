# AST2700 PFR (Platform Firmware Resilience) 架构概述

## 1. PFR 概述

Platform Firmware Resilience (PFR) 是 Intel 提出的平台固件保护标准，Aspeed 将其集成到 AST2700 BMC 芯片中，为 BMC 和 PCH/CPU 固件提供端到端的完整性保护和恢复机制。

### 1.1 核心目标

- **固件完整性验证**: 确保只有经过签名验证的固件才能执行
- **自动恢复**: 固件验证失败时自动回滚到备份版本
- **防回滚保护**: 阻止使用已知存在安全漏洞的旧版本固件
- **BMC 防护**: 防止未授权的 BMC 固件更新

### 1.2 PFR 架构分层

```
+-------------------+
|   应用层          |  OpenBMC 应用程序
+-------------------+
        |
+-------------------+
|   Linux Kernel    |  设备驱动 (I2C/SMBus, MCTP)
+-------------------+
        |
+-------------------+
| aspeed-pfr-tool   |  用户空间工具
+-------------------+
        |
+-------------------+
|   BMC RoT CPLD    |  硬件信任根 (FPGA/SoC 集成)
+-------------------+
        |
+-------------------+
|   SPI Flash       |  固件存储介质
+-------------------+
```

## 2. 目录结构

### 2.1 meta-aspeed-pfr 层结构

```
meta-aspeed-pfr/
|-- classes/                    # BitBake 类文件
|   |-- cerberus-pfr-signing-image.bbclass
|   |-- intel-pfr-signing-image.bbclass
|
|-- conf/
|   |-- layer.conf             # 层级配置
|
|-- meta-ast2600-pfr/          # AST2600 特定配置
|   |-- conf/
|   |   |-- layer.conf
|   |-- recipes-aspeed/
|   |-- recipes-bsp/
|   |-- recipes-intel/
|   |-- recipes-kernel/
|   |-- recipes-networking/
|   |-- recipes-phosphor/
|   |-- recipes-x86/
|
|-- meta-ast2700-pfr/          # AST2700 特定配置
|   |-- conf/
|   |   |-- layer.conf
|   |   |-- machine/
|   |       |-- ast2700-dcscm.conf
|   |       |-- ast2700-a1-dcscm.conf
|   |-- recipes-aspeed/
|   |-- recipes-intel/
|   |-- recipes-networking/
|   |-- recipes-phosphor/
|
|-- recipes-aspeed/             # Aspeed 配方
|   |-- aspeed-pfr-tool/       # PFR 工具
|   |   |-- aspeed-pfr-tool/
|   |   |-- pfr-i3ctool/       # I3C 工具
|   |   |-- aspeed-pfr-tool.bb
|   |   |-- pfr-i3ctool.bb
|   |-- packagegroups/
|       |-- packagegroup-aspeed-pfr.bb
|       |-- packagegroup-cerberus-pfr.bb
|       |-- packagegroup-intel-pfr.bb
|
|-- recipes-cerberus/           # Cerberus 相关配方
|   |-- cerberus-pfr-key-cancellation-image/
|   |-- cerberus-pfr-key-manifest-image/
|   |-- cerberus-pfr-provision-image/
|   |-- cerberus-pfr-signing-utility/
|
|-- recipes-core/               # 核心配方
|
|-- recipes-intel/              # Intel PFR 配方
|   |-- bmc-boot-done/
|   |-- host-misc-comm-manager/
|   |-- pfr/
|   |   |-- hash-sigs-native_git.bb
|   |   |-- intel-pfr-signing-utility-native.bb
|   |   |-- obmc-pfr-image.bb
|   |   |-- pfr-manager_git.bb
|   |   |-- pfr-mctp-i3c_git.bb
|   |-- phosphor-u-boot-mgr/
|   |-- prov-mode-mgr/
|
|-- recipes-phosphor/           # Phosphor 组件
|   |-- dbus/
|   |   |-- phosphor-dbus-interfaces/
|   |-- flash/
|   |   |-- phosphor-software-manager/
|   |-- ipmi/
|   |-- settings/
|       |-- phosphor-settings-manager/
|
|-- recipes-support/            # 支持工具
    |-- spdm-emu/
        |-- spdm-emu_git.bb
```

### 2.2 aspeed-pfr-tool 源码结构

```
aspeed-pfr-tool/
|-- main.c              # 主程序和命令行解析
|-- provision.c         # 根密钥配置和 UFM 编程
|-- spdm.c              # SPDM 协议实现
|-- status.c            # PFR 状态查询
|-- info.c              # PFM 版本信息查询
|-- checkpoint.c        # 检查点控制
|-- i2c_utils.c         # I2C/SMBus 通信
|-- utils.c             # 工具函数
|
|-- include/
|   |-- arguments.h     # 命令行参数定义
|   |-- checkpoint.h    # 检查点定义
|   |-- config.h        # 配置定义
|   |-- i2c_utils.h     # I2C 工具头文件
|   |-- info.h          # 信息查询头文件
|   |-- mailbox_enums.h # 邮箱寄存器枚举
|   |-- provision.h     # 配置头文件
|   |-- spdm.h          # SPDM 头文件
|   |-- status.h        # 状态头文件
|   |-- utils.h         # 工具头文件
|
|-- test/               # 测试代码
```

## 3. 固件区域划分

### 3.1 存储区域映射

PFR 系统管理三个主要固件区域:

| 区域类型 | 描述 | 用途 |
|---------|------|------|
| Active PFM | 主固件区域 | 当前运行的固件 |
| Recovery PFM | 恢复固件区域 | 备份/恢复用固件 |
| Staging | 暂存区域 | 固件更新包临时存储 |

### 3.2 BMC/PCH 偏移地址

每个组件都有独立的区域偏移量配置:

```
BMC 区域:
  - Active PFM Offset:    主固件偏移
  - Recovery Offset:      恢复固件偏移
  - Staging Offset:       暂存区域偏移

PCH/CPU 区域:
  - Active PFM Offset:    主固件偏移
  - Recovery Offset:      恢复固件偏移
  - Staging Offset:       暂存区域偏移

AFM (可选):
  - Staging Offset:       AFM 暂存区域偏移
```

## 4. 平台状态机

### 4.1 状态定义

PFR RoT CPLD 实现了完整的状态机，跟踪平台启动和恢复过程:

| 状态码 | 状态名称 | 说明 |
|--------|----------|------|
| 0x01 | CPLD waiting to start | 等待启动 |
| 0x02 | CPLD started | CPLD 已启动 |
| 0x03 | Enter T-1 | 进入 T-1 阶段 |
| 0x06 | BMC flash authentication | BMC 固件认证 |
| 0x07 | PCH/CPU flash authentication | PCH/CPU 固件认证 |
| 0x08 | Lockdown due to auth failure | 因认证失败锁定 |
| 0x09 | Enter T0 | 进入 T0 阶段 |
| 0x0A | T0 BMC booted | BMC 已启动 |
| 0x0B | T0 Intel ME booted | ME 已启动 |
| 0x0C | T0 ACM booted | ACM 已启动 |
| 0x0D | T0 BIOS booted | BIOS 已启动 |
| 0x0E | T0 boot completed | 启动完成 |
| 0x15 | PCH/CPU firmware update | PCH/CPU 固件更新中 |
| 0x16 | BMC firmware update | BMC 固件更新中 |

### 4.2 恢复相关状态

| 状态码 | 状态名称 |
|--------|----------|
| 0x44 | T-1 firmware recovery due to authentication failure |
| 0x45 | T-1 forced active firmware recovery |
| 0x46 | Watchdog timer timeout recovery |
| 0x47 | CPLD recovery |
| 0x48 | Lockdown due to PIT L1 |
| 0x49 | PIT L2 firmware sealed |
| 0x4A | Lockdown due to PIT L2 PCH/CPU firmware hash mismatch |
| 0x4B | Lockdown due to PIT L2 BMC firmware hash mismatch |

## 5. 恢复机制

### 5.1 恢复原因

`Last Recovery Reason` 寄存器记录最近一次恢复的原因:

| 代码 | 原因 |
|------|------|
| 0x01 | PCH/CPU active failure |
| 0x02 | PCH/CPU recovery failure |
| 0x03 | Intel ME launch failure |
| 0x04 | ACM launch failure |
| 0x05 | IBB launch failure |
| 0x06 | OBB launch failure |
| 0x07 | BMC active failure |
| 0x08 | BMC recovery failure |
| 0x09 | BMC launch failure |
| 0x0A | CPLD WDT expired forced active fw recovery |
| 0x0B | CPLD active failure |

### 5.2 恢复流程

```
1. 检测固件认证失败
   |
2. 增加 Recovery Count
   |
3. 记录 Last Recovery Reason
   |
4. 从 Recovery PFM 区域加载固件
   |
5. 验证 Recovery 固件签名
   |
6. 执行 Recovery 固件
   |
7. 标记 Panic Event
```

## 6. 错误代码

### 6.1 Major Error Code

主要错误类型:

| 代码 | 错误描述 |
|------|----------|
| 0x01 | BMC authentication failure |
| 0x02 | PCH/CPU authentication failure |
| 0x03 | in-band and OOB update failure (BMC or PCH or ROT) |
| 0x04 | ROT authentication failure |
| 0x05 | Attestation measurement mismatch |
| 0x06 | Attestation Challenge timeout |
| 0x07 | SPDM Protocol Error |
| 0x08 | CPU/SCM/Debug CPLD Authentication failure |

### 6.2 Minor Authentication Error

认证相关的次要错误:

| 代码 | 错误描述 |
|------|----------|
| 0x01 | Active region authentication failure |
| 0x02 | Recovery region authentication failure |
| 0x03 | Active and Recovery region authentication failure |
| 0x04 | Active, Recovery and Staging region authentication failure |
| 0x05 | AFM Active region authentication failure |
| 0x06 | AFM Recovery region authentication failure |
| 0x07 | AFM Active and Recovery region authentication failure |
| 0x08 | AFM Active, Recovery and Staging region authentication failure |

### 6.3 Minor Update Error

更新相关的次要错误:

| 代码 | 错误描述 |
|------|----------|
| 0x01 | Invalid update intent |
| 0x02 | Update capsule has invalid SVN |
| 0x03 | Update capsule failed authentication |
| 0x04 | Exceeded maximum failed update attempts |
| 0x05 | Active firmware update not allowed (recovery region failed auth) |
| 0x06 | FW update capsule failed auth before promotion |
| 0x07 | AFM update is not allowed |
| 0x08 | Unknown AFM |
| 0x09 | Unknown FV type |
| 0x0A | Authentication failed after seamless update |

## 7. UFM 配置状态

UFM (User Flash Memory) 配置状态位:

| 位 | 名称 | 说明 |
|----|------|------|
| Bit[0] | Command Busy | 命令正在执行 |
| Bit[1] | Command Done | 命令完成 |
| Bit[2] | Command Error | 命令执行错误 |
| Bit[4] | UFM locked | UFM 已锁定 |
| Bit[5] | UFM Provisioned | UFM 已配置 |
| Bit[6] | PIT Level-1 enforced | PIT L1 已强制执行 |
| Bit[7] | PIT Level-2 completed | PIT L2 已成功完成 |

## 8. 相关文档

- `/mnt/d/code/aspped-github/openbmc/meta-aspeed-sdk/meta-aspeed-pfr/recipes-aspeed/aspeed-pfr-tool/` - PFR 工具源码
- `/mnt/d/code/aspped-github/openbmc/meta-aspeed-sdk/meta-aspeed-pfr/recipes-intel/pfr/` - Intel PFR 组件