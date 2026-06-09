# AST2700 外设驱动配置详解

## 1. 外设概览

AST2700 芯片集成丰富的外设接口，支持 BMC 应用的各种场景。

### 1.1 外设列表

| 外设类型 | 数量 | 说明 |
|----------|------|------|
| I2C | 16+ | 主/从模式 |
| SPI | 4 | FMC + SPI0-2 |
| UART | 14 | 串口 |
| USB 2.0 | 2 | Host/Device |
| USB 3.0 | 1 | Gen1 xHCI |
| PCIe | 2 | Gen2 x4 |
| Ethernet | 2 | MAC + PHY |
| GPIO | 160+ | 多功能 GPIO |
| I3C | 8 | 混合 I2C/I3C |
| eMMC/SD | 1 | SDHCI |
| ADC | 8 通道 | 10-bit |
| PWM/Fan | 8 | PWM 输出 |
| Video Engine | 1 | H.264 解码 |
| KCS | 4 | IPMI 接口 |
| eSPI | 1 | 增强型 SPI |
| JTAG | 2 | 调试接口 |
| LPC | 1 | 传统接口 |
| Watchdog | 2 | 双看门狗 |
| Timer | 多路 | 系统定时器 |

## 2. 设备树配置

### 2.1 基础设备树

AMD Kenya PRB 主板设备树: `aspeed-bmc-amd-kenya.dts`

```dts
/dts-v1/;
#include "aspeed-g7.dtsi"
#include "dt-bindings/gpio/aspeed-gpio.h"

/ {
    model = "AMD Kenya PRB";
    compatible = "amd,kenya-bmc", "aspeed,ast2700";

    chosen {
        stdout-path = "serial12:115200n8";
    };
};
```

### 2.2 保留内存区域

```dts
reserved-memory {
    #address-cells = <2>;
    #size-cells = <2>;
    ranges;

    video_engine_memory0: video0 {
        size = <0x0 0x02000000>;
        alignment = <0x0 0x00010000>;
        compatible = "shared-dma-pool";
        reusable;
    };
};
```

## 3. 串口配置 (UART)

### 3.1 BMC 控制台

```dts
&uart12 {
    status = "okay";
};
```

### 3.2 主机串口 (通过 LTPI0)

```dts
&ltpi0 {
    status = "okay";
};

&ltpi0_gpio {
    status = "okay";
};

&uart13 {
    /delete-property/ pinctrl-names;
    /delete-property/ pinctrl-0;
    status = "okay";
};
```

### 3.3 虚拟串口 (eSPI VUART)

```dts
&vuart0 {
    status = "okay";
    virtual;
    port = <0x3f8>;
    sirq = <4>;
    sirq-polarity = <0>;
};
```

## 4. 以太网配置

### 4.1 MAC0 (RGMII)

```dts
&mdio0 {
    status = "okay";
    #address-cells = <1>;
    #size-cells = <0>;

    ethphy0: ethernet-phy@0 {
        compatible = "ethernet-phy-ieee802.3-c22";
        reg = <0>;
    };
};

&pinctrl1 {
    pinctrl_rgmii0_driving: rgmii0_driving {
        pins = "C20", "C19", "A8", "R14", "A7", "P14",
               "D20", "A6", "B6", "N14", "B7", "B8";
        drive-strength = <1>;
    };
};

&mac0 {
    status = "okay";
    phy-mode = "rgmii-id";
    phy-handle = <&ethphy0>;
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_rgmii0_default &pinctrl_rgmii0_driving>;
};
```

### 4.2 MAC1 (RMII/NCSI)

```dts
&mac1 {
    status = "okay";
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_rmii1_default>;
    clock-names = "MACCLK", "RCLK";
    use-ncsi;
    phy-mode = "rmii";
};
```

## 5. SPI Flash 配置

### 5.1 FMC (主 SPI Flash)

```dts
&fmc {
    status = "okay";
    pinctrl-0 = <&pinctrl_fwspi_quad_default>;
    pinctrl-names = "default";

    flash@0 {
        status = "okay";
        m25p,fast-read;
        label = "bmc";
        spi-max-frequency = <50000000>;
        spi-tx-bus-width = <4>;
        spi-rx-bus-width = <4>;
        partitions {
            compatible = "fixed-partitions";
            #address-cells = <1>;
            #size-cells = <1>;
            u-boot@0 {
                reg = <0x0 0x400000>;        // 4MB
                label = "u-boot";
            };
            u-boot-env@400000 {
                reg = <0x400000 0x20000>;    // 128KB
                label = "u-boot-env";
            };
            kernel@420000 {
                reg = <0x420000 0x900000>;   // 9MB
                label = "kernel";
            };
            rofs@d20000 {
                reg = <0xd20000 0x24a0000>;  // 36.625MB
                label = "rofs";
            };
            rwfs@31c0000 {
                reg = <0x31c0000 0xD40000>;  // 13.25MB
                label = "rwfs";
            };
        };
    };

    flash@1 {
        status = "okay";
        m25p,fast-read;
        label = "mpflash";
        spi-max-frequency = <50000000>;
        spi-tx-bus-width = <4>;
        spi-rx-bus-width = <4>;
    };
};
```

### 5.2 SPI0/SPI1 (PNOR)

```dts
&spi0 {
    status = "okay";
    pinctrl-0 = <&pinctrl_spi0_default &pinctrl_spi0_cs1_default>;
    pinctrl-names = "default";

    flash@0 {
        status = "okay";
        m25p,fast-read;
        label = "pnor";
        spi-max-frequency = <33000000>;
    };
};

&spi1 {
    status = "okay";
    pinctrl-0 = <&pinctrl_spi1_default &pinctrl_spi1_cs1_default>;
    pinctrl-names = "default";

    flash@0 {
        status = "okay";
        m25p,fast-read;
        label = "pnor";
        spi-max-frequency = <33000000>;
    };
};
```

### 5.3 SPI2 (OLED 显示屏)

```dts
&spi2 {
    status = "okay";
    pinctrl-0 = <&pinctrl_spi2_default &pinctrl_spi2_cs1_default>;
    pinctrl-names = "default";
    compatible = "aspeed,ast2700-spi-txrx";

    oled@0 {
        reg = <0>;
        compatible = "ssd,ssd1322";
        spi-max-frequency = <1000000>;
        label = "ssd1322";
        status = "okay";
        spi-tx-bus-width = <1>;
        spi-rx-bus-width = <1>;
    };
};
```

## 6. I2C 配置

### 6.1 基础 I2C 总线

```dts
&i2c0 {
    status = "okay";

    i2cswitch@70 {
        compatible = "nxp,pca9548";
        reg = <0x70>;
        #address-cells = <1>;
        #size-cells = <0>;

        fan_board: i2c@6 {
            reg = <6>;
            nct7363@20 {
                compatible = "nct,nct7363";
                reg = <0x20>;
                fan_sel_gpio = <3>;
            };
        };
    };
};
```

### 6.2 I2C 别名 (aliases)

```dts
aliases {
    i2c108 = &mcio_1;
    i2c109 = &mcio_2;
    i2c110 = &mcio_3;
    i2c111 = &mcio_4;
    i2c112 = &mcio_5;
    i2c113 = &mcio_6;
    i2c114 = &p0_ps;
    i2c115 = &NC_1;
    i2c116 = &P0_id;
    i2c117 = &P0_clk;
    i2c118 = &P0_vr;
    // ...
};
```

### 6.3 P0-SEC I2C (MCTP)

```dts
&i2c15 {
    status = "okay";
    pinctrl-0 = <&pinctrl_di2c15_default>;
    clock-frequency = <400000>;
    multi-master;
    mctp-controller;
    mctp@10 {
        compatible = "mctp-i2c-controller";
        reg = <(0x10 | I2C_OWN_SLAVE_ADDRESS)>;
    };
};
```

### 6.4 I2C 设备示例

```dts
// EEPROM
&i2c7 {
    status = "okay";
    scmeeprom@50 {
        compatible = "atmel,24c08";
        reg = <0x50>;
    };
};

&i2c8 {
    status = "okay";
    hpmeeprom@50 {
        compatible = "microchip,24lc256","atmel,24c256";
        reg = <0x50>;
    };
};
```

### 6.5 VR 设备

```dts
// VR 电源管理芯片
p0_vr: i2c@2 {
    reg = <2>;
    pvddcr_cpu0_p0@61 {
        compatible = "renesas,raa229639";
        reg = <0x61>;
    };
    pvddcr_cpu1_p0@62 {
        compatible = "renesas,raa229639";
        reg = <0x62>;
    };
    pvddio_p0@63 {
        compatible = "renesas,raa229641";
        reg = <0x63>;
    };
};
```

## 7. I3C 配置

### 7.1 I3C 总线

```dts
&i3c4 {
    status = "okay";
    initial-role = "primary";
    internal-pullup = <2>;
    i3c-scl-hz = <12500000>;
    i2c-scl-hz = <1000000>;
    mctp-controller;
};
```

### 7.2 I3C Hub 配置 (JESD300)

```dts
#ifdef I3C_HUB
&i3c8 {
    status = "okay";
    initial-role = "primary";
    bus-context = /bits/ 8 <I3C_BUS_CONTEXT_JESD403>;
    i3c-scl-hz = <10000000>;
    i2c-scl-hz = <1000000>;

    i3c_hub0: i3chub0@70,4CC00000000 {
        reg = <0x70 0x4CC 0x00000000>;
        assigned-address = <0x70>;
    };

    i3c_hub1: i3chub1@71,4CC00000001 {
        reg = <0x71 0x4CC 0x00000001>;
        assigned-address = <0x71>;
    };
};
#endif
```

## 8. GPIO 配置

### 8.1 GPIO 控制器

```dts
&gpio1 {
    status = "okay";

    p0_sec_i2c {
        gpio-hog;
        gpios = <8 GPIO_ACTIVE_HIGH>;
        output-high;
        line-name = "SEL_P0_SEC_I2C_ROT_BMC";
    };
};
```

### 8.2 GPIO 行名 (LTPi0)

```dts
&ltpi0_gpio {
    status = "okay";
    gpio-line-names =
        /*00-07*/ "","","",
            "P0_MGMT_ASSERT_CLR_CMOS","P0_MGMT_MON_PROCHOT_L","P0_MGMT_ASSERT_PROCHOT_L",
            "P0_MGMT_MON_RSMRST_L","P0_ASSERT_RSMRST",
        /*08-15*/ "P0_MGMT_MON_THERMTRIP_L","P0_MGMT_ASSERT_THERMTRIP_L","P0_PRESENT_L",
            "","P1_PRESENT_L","","P0_MGMT_MON_POST_COMPLETE","",
        // ... 更多 GPIO 行名
        /*128-135*/ "P0_MGMT_MON_RST_BTN_L","P0_MGMT_ASSERT_RST_BTN_L","P0_MGMT_MON_PWR_BTN_L",
             "P0_MGMT_ASSERT_PWR_BTN_L","","","","";
};
```

## 9. USB 配置

### 9.1 USB 3.0 xHCI

```dts
&vhuba0 {
    status = "okay";
    pinctrl-0 = <&pinctrl_usb2ahpd0_default>;
};

&usb3ahp {
    status = "okay";
    pinctrl-0 = <&pinctrl_usb3axhp_default &pinctrl_usb2axhp_default>;
};
```

### 9.2 USB Gadget

| 配置 | 说明 |
|------|------|
| `aspeed-g7` | AMD Kenya PRB USB Gadget 配置 |

## 10. PCIe 配置

```dts
// 配置项
#define DUAL_NODE 0    // 1: DUAL_NODE, 0: SINGLE_NODE
#define PCIE0_EP 1     // 1: EP, 0: RC
#define PCIE1_EP 1     // 1: EP, 0: RC
```

## 11. 视频引擎配置

```dts
&video0 {
    status = "okay";
    memory-region = <&video_engine_memory0>;
};
```

## 12. eSPI 配置

```dts
&espi0 {
    status = "okay";
    perif-dma-mode;
    perif-mmbi-enable;
    perif-mmbi-src-addr = <0x0 0xa8000000>;
    perif-mmbi-tgt-memory = <&espi0_mmbi_memory>;
    perif-mmbi-instance-num = <0x1>;
    perif-mcyc-enable;
    perif-mcyc-src-addr = <0x0 0x98000000>;
    perif-mcyc-size = <0x0 0x10000>;
    oob-dma-mode;
    flash-dma-mode;
};

&lpc0_pcc {
    status = "okay";
    pcc-ports = <0x80>;
};
```

## 13. IPMI KCS 配置

```dts
&lpc0_kcs2 {
    status = "okay";
    kcs-io-addr = <0xca2>;
    kcs-channel = <2>;
};
```

## 14. XDMA 配置

```dts
&xdma0 {
    status = "okay";
    memory-region = <&xdma_memory0>;
};
```

## 15. Watchdog 配置

```dts
&wdt0 {
    status = "okay";
};

&wdt1 {
    status = "okay";
};
```

## 16. OTP 配置

```dts
&otp {
    status = "okay";
};
```

## 17. JTAG 配置

```dts
&jtag1 {
    status = "okay";
};
```

## 18. MCTP 配置

### 18.1 PCIe MCTP

```dts
&mctp0 {
    status = "okay";
    memory-region = <&mctp0_reserved>;
    mctp-controller;
};
```

### 18.2 I3C MCTP

```dts
&i3c4 {
    mctp-controller;
};
```

### 18.3 I2C MCTP

```dts
&i2c15 {
    mctp-controller;
};
```

## 19. 内核配置选项

### 19.1 必需配置

```bash
# DCSCM 平台配置 (ast2700-dcscm.cfg)
CONFIG_REGULATOR=n                 # 禁用 SDHCI regulator
CONFIG_REGULATOR_FIXED_VOLTAGE=n
CONFIG_REGULATOR_GPIO=n

# AMD Kenya 平台额外配置
CONFIG_I3C_HUB=y
CONFIG_I2C_MUX_PCA954x=y
```

### 19.2 IPMI 相关

```bash
# ipmi_ssif.cfg
CONFIG_IPMI_SSIF=y
CONFIG_IPMI_KCS=y
CONFIG_IPMI_BT=y
```

### 19.3 MTD 测试模块

```bash
# mtd_test.cfg
CONFIG_MTD_SPEEDTEST=m
CONFIG_MTD_STRESSTEST=m
```

## 20. 启动相关配置

### 20.1 Flash 布局

| 分区 | 大小 | 说明 |
|------|------|------|
| u-boot | 4MB | 引导加载器 |
| u-boot-env | 128KB | 环境变量 |
| kernel | 9MB | Linux 内核 |
| rofs | 36.625MB | 只读文件系统 |
| rwfs | 13.25MB | 读写文件系统 |
| pfm | 128KB | PFM 区域 |
| pfr-stg | 896KB | PFR 暂存区 |
| rc-image | 64MB | 恢复镜像 |

### 20.2 设备树指定

```bash
# ast2700-a1.conf
KERNEL_DEVICETREE = "aspeed/ast2700a1-evb.dtb"
KBUILD_DEFCONFIG = "aspeed_g7_defconfig"
```

## 21. 安全配置

### 21.1 OTP 配置

```bash
# aspeed-secure-config.bb
EXTRA_OEMESON:append:aspeed-g7 = " \
    -Dotp-platform='ast2700' \
"
```

### 21.2 Secure Boot

- 信任链: BootROM -> FMC -> BL31 -> OP-TEE -> U-Boot -> Kernel
- 验证方式: ECDSA384/SHA384 签名
- OTP 根密钥存储

## 22. 调试配置

### 22.1 调试接口

| 接口 | 用途 |
|------|------|
| JTAG | 芯片级调试 |
| UART12 | BMC 控制台 |
| UART13 | 主机控制台 |
| XDMA | DMA 调试 |

### 22.2 调试工具

```bash
# BSP 工具
RDEPENDS:${PN}-apps = " \
    pdbg \          # JTAG 调试
    ipmitool \      # IPMI 测试
    aspeed-app \    # Aspeed 测试
"
```

## 23. 参考文件

| 文件 | 路径 |
|------|------|
| 设备树 | `meta-aspeed-sdk/meta-vendor/meta-vendor-amd/meta-amd-sp7/recipes-kernel/linux/linux-aspeed/aspeed-bmc-amd-kenya.dts` |
| 内核配置 | `meta-aspeed-sdk/recipes-kernel/linux/linux-aspeed/*.cfg` |
| 机器配置 | `meta-aspeed-sdk/meta-ast2700-sdk/conf/machine/ast2700-a1.conf` |
| 安全配置 | `meta-aspeed-sdk/recipes-aspeed/security/aspeed-secure-config.bb` |