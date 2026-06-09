# AST2700 驱动架构概述

## 1. 架构总览

AST2700 (Aspeed G7) 是 Aspeed 第七代 BMC 芯片，采用 ARM Cortex-A35 架构。驱动架构遵循 Linux 内核标准框架，同时包含 Aspeed 特有的硬件加速驱动。

### 1.1 芯片特性

| 特性 | 说明 |
|------|------|
| CPU | ARM Cortex-A35 (双核或单核) |
| 架构 | ARMv8A 64-bit |
| 最大频率 | 1.2 GHz |
| 制程 | 12nm |
| 安全子系统 | 内置 Caliptra |

### 1.2 内核版本支持

```bash
# meta-aspeed-sdk 支持的内核版本
linux-aspeed_5.15.bb   # 旧版本
linux-aspeed_6.6.bb    # 稳定版
linux-aspeed_6.12.bb   # 主线版 (推荐)
linux-aspeed_6.18.bb   # 最新版
```

主要版本:
- **6.12**: Tag v00.07.03, SRCREV: 3c16a1fa761f2edbd2a2de6b8b31ab9c27f4e333

## 2. 驱动源码位置

### 2.1 Linux 内核源码

```
git://github.com/AspeedTech-BMC/linux.git
branch: aspeed-master-v6.12
```

### 2.2 设备树文件位置

| 目录 | 用途 |
|------|------|
| `meta-aspeed-sdk/meta-aspeed-pfr/meta-ast2700-pfr/recipes-kernel/linux/linux-aspeed/` | PFR 设备树 |
| `meta-aspeed-sdk/meta-vendor/meta-vendor-amd/meta-amd-sp7/recipes-kernel/linux/linux-aspeed/` | AMD 平台设备树 |

### 2.3 设备树文件列表

```dts
# PFR 设备树
ast2700-dcscm-mctp-socket.dts      # AST2700 DCSCM + MCTP
ast2700a1-dcscm-mctp-socket.dts    # AST2700 A1 DCSCM + MCTP

# AMD 平台设备树
aspeed-bmc-amd-kenya.dts           # AMD Kenya PRB 主板
ast2700-dcscm-amd.dts              # AST2700 AMD DCSCM
```

## 3. 驱动分类

### 3.1 按功能分类

```
drivers/
|-- pinctrl/           # 引脚控制器
|-- gpio/              # GPIO
|-- i2c/               # I2C/SMBus
|-- spi/               # SPI
|-- mmc/               # SD/eMMC
|-- usb/               # USB 控制器
|-- net/               # 以太网 MAC
|-- video/             # 视频引擎
|-- thermal/           # 温控
|-- watchdog/          # 看门狗
`-- misc/              # 杂项驱动
```

### 3.2 关键驱动列表

| 驱动 | 内核配置 | 说明 |
|------|----------|------|
| Aspeed PCIe | CONFIG_PCIEASPEED | AST2700 PCIe 控制器 |
| GPIO | CONFIG_GPIOLIB | GPIO 框架 |
| I2C | CONFIG_I2C | I2C 总线驱动 |
| SPI | CONFIG_SPI | SPI 总线驱动 |
| USB Gadget | CONFIG_USB_GADGET | USB gadget 驱动 |
| MMC/SDHCI | CONFIG_MMC | SD/eMMC 控制器 |
| Video Engine | CONFIG_VIDEO_ASPEED | 视频编解码 |
| KCS | CONFIG_IPMI_KCS | IPMI KCS 接口 |
| eSPI | CONFIG_ESPI | eSPI 主机接口 |

## 4. 内核配置 (defconfig)

### 4.1 基础配置文件

- **defconfig**: `aspeed_g7_defconfig`
- **Kernel config fragments**:

```bash
# recipes-kernel/linux/linux-aspeed/
ipmi_ssif.cfg          # IPMI SSIF 驱动
mtd_test.cfg           # MTD 测试模块
crpyto_manager.cfg     # 加密管理器
jffs2_writebuffer.cfg  # JFFS2 写缓冲
```

### 4.2 平台特定配置

```bash
# AMD Kenya DCSCM 配置 (ast2700-amd-dcscm.cfg)
CONFIG_I3C_HUB=y
CONFIG_I2C_MUX_PCA954x=y
CONFIG_REGULATOR=n                    # 禁用 regulator (无 SDHCI)
CONFIG_REGULATOR_FIXED_VOLTAGE=n
CONFIG_REGULATOR_GPIO=n
```

## 5. Bootloader 相关

### 5.1 U-Boot 版本

| 版本 | 适用平台 | 配方 |
|------|----------|------|
| 2019.04 | AST2500/2600 | `u-boot-aspeed-sdk_2019.04.bb` |
| 2023.10 | AST2700 | `u-boot-aspeed-sdk_2023.10.bb` |

### 5.2 U-Boot 配置

```bash
# AST2700 配置
UBOOT_MACHINE = "evb-ast2700_defconfig"
UBOOT_DEVICETREE = "ast2700-evb"
```

### 5.3 FIT 镜像组件

```
UBOOT_FIT_UBOOT_ENTRYPOINT = "0x80000000"
UBOOT_FIT_ARM_TRUSTED_FIRMWARE_LOADADDRESS = "0xb0000000"
UBOOT_FIT_TEE_LOADADDRESS = "0xb0080000"
UBOOT_FIT_SSP_LOADADDRESS = "0xac000000"
UBOOT_FIT_TSP_LOADADDRESS = "0xae000000"
```

## 6. 驱动配方 (recipes)

### 6.1 核心驱动配方

| 配方 | 路径 | 说明 |
|------|------|------|
| `linux-aspeed_*.bb` | `recipes-kernel/linux/` | Linux 内核 |
| `aspeed-app_git.bb` | `recipes-aspeed/aspeed-app/` | Aspeed 测试应用 |
| `aspeed-secure-config.bb` | `recipes-aspeed/security/` | 安全配置 |

### 6.2 aspeed-app 配方

```bash
SRC_URI = "gitsm://github.com/AspeedTech-BMC/aspeed_app.git;protocol=https;branch=master"
SRCREV = "4cb20ccffccb818e2458d069148329189368aaa0"  # Tag v00.01.22

# AST2700 (G7) 特定选项
EXTRA_OEMESON:append:aspeed-g7 = " \
    -Dotp-platform='ast2700' \
"
```

### 6.3 udev 规则

```bash
# MTD 分区规则
udev-aspeed-mtd-partitions.bb  -> 76-aspeed-mtd-partitions.rules

# 虚拟串口规则
udev-aspeed-vuart.bb
```

## 7. 机器配置 (MACHINE)

### 7.1 AST2700 机器变体

| 机器 | 内核 | 说明 |
|------|------|------|
| `ast2700-default` | 6.12 | 默认配置 |
| `ast2700-a1-612` | 6.12 | A1 硅片 |
| `ast2700-a1-66` | 6.6 | A1 硅片 |
| `ast2700-a1-emmc` | - | eMMC 启动 |
| `ast2700-a1-ufs` | - | UFS 启动 |
| `ast2700-a1-ncsi` | - | NCSI 支持 |

### 7.2 机器配置继承

```bash
# ast2700-a1.conf
require conf/machine/include/ast2700-sdk.inc
require conf/machine/include/ast2700-a1.inc
require conf/machine/include/ast-ssp.inc
require conf/machine/include/ast-tsp.inc
require conf/machine/include/ast2700-secure-customize-gen.inc
require conf/machine/include/obmc-bsp-common.inc
```

## 8. SOC 家族配置

```bash
SOC_FAMILY = "aspeed-g7"
DEFAULTTUNE = "cortexa35"
COMPATIBLE_MACHINE:aspeed-g7 = "aspeed-g7"
```

## 9. 驱动开发注意事项

### 9.1 编译环境

- 编译器: Zephyr 工具链 (for RTOS)
- 构建系统: Meson (for aspeed-app)
- 内核构建: Yocto/OpenEmbedded

### 9.2 设备树开发

```bash
# 设备树编译
make ARCH=arm64 aspeed/ast2700a1-evb.dtb

# 内核配置
make ARCH=arm64 aspeed_g7_defconfig
make ARCH=arm64 menuconfig
```

### 9.3 调试工具

| 工具 | 用途 |
|------|------|
| `pdbg` | JTAG 调试 |
| `ipmitool` | IPMI 通信测试 |
| `aspeed-app` | Aspeed 应用测试 |

## 10. 参考资料

- 内核源码: `git://github.com/AspeedTech-BMC/linux.git`
- 设备树绑定: `<kernel>/Documentation/devicetree/bindings/`
- Aspeed 驱动: `drivers/soc/aspeed/`