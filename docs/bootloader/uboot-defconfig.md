# U-Boot defconfig 分析

## 1. 概述

本文档分析 AST2700 平台的 U-Boot 配置文件 (defconfig)。defconfig 是 U-Boot 构建系统的核心配置文件，包含所有编译选项和功能开关。

### 1.1 配置文件对应关系

| 平台 | defconfig | 设备树 |
|------|-----------|--------|
| AST2500 | evb-ast2500_defconfig | ast2500-evb.dts |
| AST2600 | evb-ast2600_defconfig | ast2600-evb.dts |
| AST2600 (ECC) | evb-ast2600-ecc_defconfig | ast2600-evb-ecc.dts |
| AST2600 (eMMC) | evb-ast2600-emmc_defconfig | ast2600-evb.dts |
| AST2600 (NCSI) | evb-ast2600-ncsi_defconfig | ast2600-ncsi.dts |
| **AST2700** | **evb-ast2700_defconfig** | **ast2700-evb.dts** |

### 1.2 AST2700 defconfig 状态

当前 AST2700 的 defconfig 尚未在 U-Boot 源码中创建:

```
/mnt/d/code/aspped-github/u-boot/configs/evb-ast2700_defconfig  # 不存在
/mnt/d/code/aspped-github/u-boot/arch/arm/dts/ast2700-evb.dts   # 不存在
```

这意味着 AST2700 支持仍在开发中，配置可能需要从现有 AST2600 配置派生。

## 2. 现有 AST 配置文件分析

### 2.1 AST2600 defconfig 结构

通过分析 AST2600 配置，可以推断 AST2700 的配置结构:

```bash
# 查看 AST2600 defconfig
cat /mnt/d/code/aspped-github/u-boot/configs/evb-ast2600_defconfig
```

### 2.2 典型 defconfig 结构

```makefile
CONFIG_ARM=y
CONFIG_TARGET_AST2500=y
CONFIG_ARCH_ASTRO=y
CONFIG_DEFAULT_DEVICE_TREE="ast2600-evb"
CONFIG_BOOTARGS="console=ttyS4,115200 earlycon"
CONFIG_BOOTCOMMAND="run bootcmd"
# ... 更多配置
```

### 2.3 关键配置项

#### 2.3.1 架构和目标

```makefile
CONFIG_ARM=y
CONFIG_ARM64=y                    # AST2700 使用 ARM64
CONFIG_ARCH_CPU_INIT=y
CONFIG_ARCH_ASPEED=y
CONFIG_TARGET_EVB_AST2700=y       # AST2700 特定目标
```

#### 2.3.2 设备树配置

```makefile
CONFIG_DEFAULT_DEVICE_TREE="ast2700-evb"
CONFIG_OF_SYSTEM_SETUP=y
CONFIG_OF_BOARD_SETUP=y
CONFIG_OF_STDOLE_VIA_ETHOC=y
```

#### 2.3.3 引导配置

```makefile
CONFIG_FIT=y                      # 启用 FIT 镜像支持
CONFIG_FIT_SIGNATURE=y            # FIT 签名验证
CONFIG_FIT_BEST_MATCH=y
CONFIG_FIT_VERBOSE=y
CONFIG_IMAGE_SPARSE=y
```

#### 2.3.4 存储配置

```makefile
CONFIG_MTD=y                      # MTD 支持
CONFIG_MTD_NOR_FLASH=y
CONFIG_MTD_RAW_NAND=y
CONFIG_DM_MMC=y                   # MMC/SD 控制器
CONFIG_ASPEED_SDHC=y
CONFIG_DM_SPI_FLASH=y             # SPI Flash
CONFIG_SPI_FLASH_WINBOND=y
CONFIG_UFS=y                      # UFS 支持
```

#### 2.3.5 网络配置

```makefile
CONFIG_DM_ETH=y                   # 以太网驱动
CONFIG_ASPEED_MAC=y
CONFIG_PHY=y
CONFIG_MII=y
CONFIG_RGMII=y
CONFIG_GMAC_DTLK_PHY=y
```

#### 2.3.6 安全配置

```makefile
CONFIG_HASH=y
CONFIG_SHA384=y
CONFIG_SHA512=y
CONFIG_XZ=y
CONFIG_LZO=y
CONFIG_RSA=y                      # RSA 签名
CONFIG_RSA2048=y
CONFIG_RSA4096=y
CONFIG_ECDSA=y                    # ECDSA 签名
CONFIG_ECCSECP384R1=y             # P-384 曲线
```

#### 2.3.7 串口控制台

```makefile
CONFIG_DEBUG_UART=y
CONFIG_DEBUG_UART_ASPEED=y
CONFIG_DEBUG_UART_BASE=0x1E784000  # AST2700 UART 基址
CONFIG_DEBUG_UART_CLOCK=24000000
CONFIG_BAUDRATE=115200
CONFIG_CONS_INDEX=12              # ttyS12
```

## 3. 设备树分析

### 3.1 AST 设备树文件位置

```
u-boot/arch/arm/dts/
├── ast2400-ahe-50dc.dts
├── ast2400-evb.dts
├── ast2400-palmetto.dts
├── ast2500-evb.dts
├── ast2500-romulus.dts
├── ast2600-bletchley.dts
├── ast2600-dcscm.dts
├── ast2600-evb.dts
├── ast2600-fpga.dts
├── ast2600-ncsi-tee.dts
└── ast2700-evb.dts              # 不存在 - 待创建
```

### 3.2 AST2600 设备树结构 (参考)

```dts
// arch/arm/dts/ast2600-evb.dts
/dts-v1/;

/ {
    model = "Aspeed AST2600 EVB";
    compatible = "aspeed,ast2600", "aspeed,ast2500";

    aliases {
        serial0 = &uart1;
        ethernet0 = &mac1;
    };

    chosen {
        stdout-path = &uart1;
        bootargs = "console=ttyS4,115200";
    };

    cpus {
        ...
    };

    soc {
        compatible = "simple-bus";
        #address-cells = <1>;
        #size-cells = <1>;

        uart1: serial@1E784000 {
            compatible = "aspeed,ast2600-uart";
            reg = <0x1E784000 0x1000>;
            interrupts = <GIC_SPI 32 IRQ_TYPE_LEVEL_HIGH>;
        };

        mac1: ethernet@1E660000 {
            compatible = "aspeed,ast2600-mac";
            reg = <0x1E660000 0x180>;
        };

        // 更多外设...
    };
};
```

### 3.3 AST2700 预期差异

| 功能 | AST2600 | AST2700 预期 |
|------|---------|-------------|
| CPU | Dual-core Cortex-A7 | Quad-core Cortex-A35 |
| 架构 | ARMv7 (32-bit) | ARMv8 (64-bit) |
| 最大内存 | 2GB DDR4 | 4GB+ DDR4 |
| USB | USB 2.0 | USB 3.0 |
| PCIe | Gen2 x1 | Gen3 x2 |
| GPU | VGA | HDMI/DisplayPort |

### 3.4 AST2700 设备树关键节点

预期 AST2700 设备树应包含:

```dts
/dts-v1/;

/ {
    model = "Aspeed AST2700 EVB";
    compatible = "aspeed,ast2700", "aspeed,ast2600", "simple-bus";

    // 内存配置
    memory@40000000 {
        device_type = "memory";
        reg = <0x0 0x40000000 0 0x80000000>;  /* 2GB - 4GB */
    };

    // SOC 节点
    soc@10000000 {
        compatible = "aspeed,ast2700-soc", "simple-bus";
        ranges;
        #address-cells = <1>;
        #size-cells = <1>;

        // UART - 可能的地址变化
        uart1: serial@1E784000 {
            compatible = "aspeed,ast2700-uart";
            reg = <0x1E784000 0x1000>;
        };

        // MAC - 双千兆以太网
        mac1: ethernet@1E660000 {
            compatible = "aspeed,ast2700-mac";
            reg = <0x1E660000 0x180>;
        };

        mac2: ethernet@1E680000 {
            compatible = "aspeed,ast2700-mac";
            reg = <0x1E680000 0x180>;
        };

        // USB 3.0 控制器
        usb@1E6A0000 {
            compatible = "aspeed,ast2700-usb3";
            reg = <0x1E6A0000 0x1000>;
        };

        // PCIe 控制器
        pcie@1E700000 {
            compatible = "aspeed,ast2700-pcie";
            reg = <0x1E700000 0x10000>;
        };

        // eMMC/UFS 控制器
        sdhci@1E650000 {
            compatible = "aspeed,ast2700-sdhci";
            reg = <0x1E650000 0x400>;
        };
    };

    // 签名节点 (安全启动)
    signature {
        compatible = "aspeed,signature";
        ecc_region {
            // 用于 FIT 签名验证的 ECDSA 公钥
        };
    };
};
```

## 4. ARMv8 迁移注意事项

### 4.1 架构差异

AST2700 迁移到 ARM64 架构，需要注意以下配置:

```makefile
# ARMv8 特定配置
CONFIG_ARM64=y
CONFIG_TARGET_EVB_AST2700=y
CONFIG_POSITION_INDEPENDENT=y
CONFIG_REMAKE_ELF=y

# 内存管理
CONFIG_SYS_MEM_RSVD_BASE=0x00000000
CONFIG_SYS_MEM_RSVD_SIZE=0x00100000
CONFIG_SYS_MEM_BASE=0x40000000
CONFIG_SYS_MEM_SIZE=0x80000000

# 异常级别
CONFIG_ARM_GICV3=y
CONFIG_PSCI=y
CONFIG_ARMV8_SWITCH_TO_EL2=y
```

### 4.2 启动要求

ARM64 U-Boot 需要:

1. **PIE (Position Independent Executable)**: 位置无关代码
2. **ARM Trusted Firmware 集成**: BL31 固件
3. **内存布局**: 符合 ARM64 内存映射
4. **异常级别切换**: EL2 (Hypervisor) 或 EL1 (OS)

### 4.3 链接器脚本注意事项

```makefile
# 链接脚本配置
CONFIG_SYS_INIT_SP_BSS_OFFSET=y
CONFIG_TEXT_BASE=0x80000000
CONFIG_TPL_TEXT_BASE=0x80000000
```

## 5. FIT 镜像配置

### 5.1 FIT 配置要求

```makefile
CONFIG_FIT=y
CONFIG_FIT_SIGNATURE=y
CONFIG_FIT_VERIFICATION=y
CONFIG_RSA=y
CONFIG_SHA384=y
CONFIG_HAS_SHA384=y
CONFIG_ECDSAPKR=y
```

### 5.2 FIT 镜像结构

AST2700 FIT 镜像包含:

```
/ {
    description = "AST2700 OpenBMC Firmware";
    #address-cells = <2>;
    #size-cells = <2>;

    images {
        atf {
            description = "ARM Trusted Firmware";
            type = "firmware";
            os = "arm-trusted-firmware";
            arch = "arm64";
            compression = "none";
            load = <0xb0000000>;
            entry = <0xb0000000>;
            data = <...>;
        };

        tee {
            description = "OP-TEE OS";
            type = "firmware";
            os = "op-tee";
            arch = "arm64";
            compression = "none";
            load = <0xb0080000>;
            entry = <0xb0080000>;
            data = <...>;
        };

        uboot {
            description = "U-Boot";
            type = "standalone";
            os = "u-boot";
            arch = "arm64";
            compression = "none";
            load = <0x80000000>;
            entry = <0x80000000>;
            data = <...>;
        };

        kernel {
            description = "Linux Kernel";
            type = "kernel";
            os = "linux";
            arch = "arm64";
            compression = "lzma";
            load = <...>;
            entry = <...>;
            data = <...>;
        };

        fdt-ast2700-evb {
            description = "Flattened Device Tree";
            type = "flat_dt";
            arch = "arm64";
            compression = "none";
            data = <...>;
        };
    };

    configurations {
        default = "conf-ast2700-evb";

        conf-ast2700-evb {
            description = "AST2700 EVB Configuration";
            firmware = "atf";
            loadables = "tee", "uboot";
            fdt = "fdt-ast2700-evb";
            kernel = "kernel";
        };
    };
};
```

## 6. 安全启动配置

### 6.1 签名配置

```makefile
# 签名使能
CONFIG_FIT_SIGNATURE=y
CONFIG_FIT_VERIFY_PSIGNATURE=y

# 算法配置
CONFIG_SHA384=y
CONFIG_HAS_SHA384=y
CONFIG_RSA=y
CONFIG_RSA2048=y
CONFIG_RSA4096=y
CONFIG_ECDSA=y
CONFIG_ECCSECP384R1=y

# 密钥配置
CONFIG_OF_BOARD_SETUP=y
CONFIG_EXTRA_ENV_SETTINGS=y
```

### 6.2 环境变量签名

```makefile
CONFIG_ENV_IS_IN_SPI_FLASH=y
CONFIG_ENV_SIZE=0x20000
CONFIG_ENV_OFFSET=0x1000
CONFIG_ENV_SECT_SIZE=0x10000
```

### 6.3 安全引导环境

```
bootcmd=run distro_bootcmd
bootcmd_fit=run fit_boot
fit_boot=bootm ${fitaddr}#conf-${fdtfile}
```

## 7. 驱动配置

### 7.1 存储驱动

```makefile
# SPI Flash
CONFIG_DM_SPI_FLASH=y
CONFIG_SPI_FLASH=y
CONFIG_SPI_FLASH_BAR=y
CONFIG_SPI_FLASH_EON=y
CONFIG_SPI_FLASH_GIGADEVICE=y
CONFIG_SPI_FLASH_MACRONIX=y
CONFIG_SPI_FLASH_SPANSION=y
CONFIG_SPI_FLASH_STMICRO=y
CONFIG_SPI_FLASH_WINBOND=y
CONFIG_SPI_MUX=y

# eMMC/SD
CONFIG_DM_MMC=y
CONFIG_MMC=y
CONFIG_GENERIC_ATMEL_MCI=y
CONFIG_ASPEED_SDHC=y

# UFS
CONFIG_UFS=y
CONFIG_UFS_BUILTIN=y
```

### 7.2 网络驱动

```makefile
CONFIG_DM_ETH=y
CONFIG_ETHPRIME="eqos0"
CONFIG_PHY_GIGE=y
CONFIG_ASPEED_MAC=y
CONFIG_ASPEED_DWMAC=y
CONFIG_PHY_ADDR_RESET=y
CONFIG_PHY_BROADCOM=y
```

### 7.3 显示驱动

```makefile
CONFIG_DM_VIDEO=y
CONFIG_VIDEO_ASPEED=y
CONFIG_VIDEO_ASPEED_GUARD=y
CONFIG_VIDEO_BPP=16
CONFIG_VIDEO_LOGO=y
```

## 8. 调试配置

### 8.1 调试 UART

```makefile
CONFIG_DEBUG_UART=y
CONFIG_DEBUG_UART_ASPEED=y
CONFIG_DEBUG_UART_BASE=0x1E784000
CONFIG_DEBUG_UART_CLOCK=24000000
CONFIG_DEBUG_UART_SKIP_INIT=y
```

### 8.2 调试功能

```makefile
CONFIG_DEBUG=y
CONFIG_LOG=y
CONFIG_LOGF_FUNC=y
CONFIG_LOG_MAX_LEVEL=7
CONFIG_DEBUG_LL=y
CONFIG_SEMIHOSTING=y
```

## 9. 创建 AST2700 defconfig 的步骤

### 9.1 从 AST2600 派生

```bash
cd /mnt/d/code/aspped-github/u-boot
cp configs/evb-ast2600_defconfig configs/evb-ast2700_defconfig
```

### 9.2 必要修改

1. **架构**: ARM32 -> ARM64
2. **目标芯片**: AST2600 -> AST2700
3. **设备树**: ast2600-evb -> ast2700-evb
4. **内存布局**: 适配 ARM64
5. **串口基址**: 根据 AST2700 手册调整

### 9.3 配置验证

```bash
make evb-ast2700_defconfig
make -j$(nproc)
```

## 10. 配置文件参考

### 10.1 主要参考文件

- `/mnt/d/code/aspped-github/u-boot/configs/evb-ast2600_defconfig`
- `/mnt/d/code/aspped-github/u-boot/configs/evb-ast2600-ecc_defconfig`
- `/mnt/d/code/aspped-github/u-boot/configs/evb-ast2500_defconfig`
- `/mnt/d/code/aspped-github/u-boot/arch/arm/dts/ast2600-evb.dts`
- `/mnt/d/code/aspped-github/u-boot/arch/arm/dts/ast2600.dtsi`

### 10.2 相关文档

- U-Boot 官方文档: `doc/README.aspeed`
- ARM64 启动要求: `doc/README.armv8`
- FIT 镜像格式: `doc/uImage.FIT/`