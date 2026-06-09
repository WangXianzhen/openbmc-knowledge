# AST2700 设备树 (Device Tree) 配置

## 1. 设备树概述

### 1.1 设备树源文件位置

设备树源文件 (`.dts` 和 `.dtsi`) 位于 Linux 内核源码中：

```
linux-aspeed 源码/
├── arch/
│   └── arm64/
│       └── boot/
│           └── dts/
│               └── aspeed/
│                   ├── ast2700-a0.dtsi      # A0 芯片通用
│                   ├── ast2700-a1.dtsi      # A1 芯片通用
│                   ├── ast2700-a2.dtsi      # A2 芯片通用
│                   ├── ast2700-evb.dts      # EVB 板 (A2)
│                   ├── ast2700a1-evb.dts    # EVB 板 (A1)
│                   ├── ast2700-irot.dts     # iROT 变体
│                   └── ...
```

### 1.2 OpenBMC 层设备树覆盖

在 OpenBMC 构建系统中，vendor 层可以提供自定义的设备树：

| 路径 | 用途 |
|------|------|
| `meta-aspeed-sdk/meta-ast2700-sdk/recipes-kernel/linux-aspeed/` | AST2700 SDK 专用 |
| `meta-aspeed-sdk/meta-aspeed-pfr/meta-ast2700-pfr/.../*.dts` | PFR 专用设备树 |
| `meta-vendor/*/recipes-kernel/linux/linux-aspeed/*.dts` | 厂商定制 |

### 1.3 设备树文件列表 (AST2700)

```bash
# AST2700 相关设备树源文件
ast2700-a0.dtsi          # A0 芯片基础定义 (如果存在)
ast2700-a1.dtsi          # A1 芯片通用定义
ast2700-a2.dtsi          # A2 芯片通用定义
ast2700-evb.dts          # EVB 开发板 (默认 A2)
ast2700a1-evb.dts        # EVB 开发板 (A1)
ast2700-irot.dts         # iROT 变体
ast2700-dcscm-mctp-socket.dts  # DCSCM MCTP Socket
```

## 2. 设备树配置绑定

### 2.1 Machine 配置中的设备树

在 `meta-aspeed-sdk` 的 machine 配置文件中指定：

```bitbake
# ast2700-default.conf
KERNEL_DEVICETREE = "aspeed/ast2700-evb.dtb"

# ast2700-a1.conf
KERNEL_DEVICETREE = "aspeed/ast2700a1-evb.dtb"

# ast2700-irot.conf
KERNEL_DEVICETREE = "aspeed/ast2700-irot.dtb"
```

### 2.2 内核版本特定的设备树

| 内核版本 | 设备树目录 | 说明 |
|----------|------------|------|
| 6.18 | `arch/arm64/boot/dts/aspeed/` | 最新支持 |
| 6.12 | `arch/arm64/boot/dts/aspeed/` | 稳定版本 |
| 6.6 | `arch/arm64/boot/dts/aspeed/` | LTS 版本 |
| 5.15 | `arch/arm/boot/dts/` | 旧版本 (ARM32) |

## 3. 设备树结构分析

### 3.1 AST2700 芯片级 .dtsi

典型的 `ast2700-a1.dtsi` 结构：

```dts
/dts-v1/;

/ {
    model = "Aspeed AST2700 EVB";
    compatible = "aspeed,ast2700", "aspeed,ast2700a1";

    #address-cells = <2>;
    #size-cells = <2>;

    interrupt-parent = <&gic>;
    #interrupt-cells = <3>;

    // 时钟定义
    clock: oscillator {
        compatible = "fixed-clock";
        clock-frequency = <48000000>;
        #clock-cells = <0>;
    };

    // 内存节点
    memory@4_00000000 {
        device_type = "memory";
        reg = <0x4 0x00000000 0x4 0x00000000>;
    };

    // SoC 外设节点
    soc {
        compatible = "simple-bus";
        #address-cells = <1>;
        #size-cells = <1>;
        ranges;

        // UART 控制器
        uart5: serial@1e784000 {
            compatible = "aspeed,ast2500-uart";
            reg = <0x1e784000 0x1000>;
            interrupts = <GIC_SPI 34 IRQ_TYPE_LEVEL_HIGH>;
            clocks = <&clock>;
            status = "okay";
        };

        // I2C 控制器
        i2c: i2c@1e78a000 {
            compatible = "aspeed,ast2700-i2c";
            reg = <0x1e78a000 0x40>;
            interrupts = <GIC_SPI 12 IRQ_TYPE_LEVEL_HIGH>;
            #address-cells = <1>;
            #size-cells = <0>;
            status = "okay";
        };

        // GPIO 控制器
        gpio: gpio@1e780000 {
            compatible = "aspeed,gpio-aspeed";
            reg = <0x1e780000 0x400>;
            gpio-controller;
            #gpio-cells = <2>;
            status = "okay";
        };
    };
};
```

### 3.2 板级 .dts 文件

```dts
// ast2700-evb.dts
/dts-v1/;
#include "ast2700-a1.dtsi"

/ {
    model = "Aspeed AST2700 EVB (A2 Silicon)";
    compatible = "aspeed,ast2700-evb", "aspeed,ast2700", "aspeed,ast2700a1";

    chosen {
        stdout-path = &uart5;
        bootargs = "console=ttyS12,115200 earlycon";
    };

    // 扩展板特定外设
    &i2c {
        // 连接的温度传感器
        temperature-sensor@4a {
            compatible = "national,lm75";
            reg = <0x4a>;
        };
    };

    // 以太网 PHY
    &ftgmac200 {
        phy-handle = <&phy0>;
        status = "okay";
    };
};
```

## 4. 关键硬件节点

### 4.1 KCS (Keyboard Controller Style) IPMI

```dts
&kcs1 {
    status = "okay";
    aspeed,lpc-interrupts = <3>;
};

&kcs2 {
    status = "okay";
    aspeed,lpc-interrupts = <4>;
};
```

### 4.2 以太网控制器

```dts
&ftgmac200 {
    status = "okay";
    compatible = "aspeed,ast2700-ftgmac100";
    reg = <0x1e650000 0x2000>;
    interrupts = <GIC_SPI 8 IRQ_TYPE_LEVEL_HIGH>;

    phy-handle = <&phy0>;

    mdio {
        phy0: ethernet-phy@0 {
            compatible = "ethernet-phy-id0022.1622";
            reg = <0>;
        };
    };
};
```

### 4.3 UART 串口

```dts
&uart5 {
    status = "okay";
    // BMC 控制台
};

&uart12 {
    status = "okay";
    // 主机 UART (KCS 辅助)
};
```

### 4.4 eMMC/UFS 控制器

```dts
// eMMC
&mmc {
    status = "okay";
    max-frequency = <200000000>;
    broken-cd;
    bus-width = <8>;
};

// UFS (如果支持)
&ufs {
    status = "okay";
};
```

### 4.5 看门狗

```dts
&wdt1 {
    status = "okay";
};

&wdt2 {
    status = "okay";
    aspeed,watchdog-sclken;
};
```

## 5. 芯片变体差异

### 5.1 A1 vs A2 硅芯片

| 功能 | AST2700 A1 | AST2700 A2 | 说明 |
|------|------------|------------|------|
| 设备树 | `ast2700a1-evb.dtb` | `ast2700-evb.dtb` | 不同 DTB |
| BMC MCU | Zephyr (BootMCU) | Zephyr (FMC) | 启动固件不同 |
| Caliptra | v1.0 | v1.1+ | 固件版本差异 |
| eMMC | 支持 | 支持 | - |
| UFS | 不支持 | 支持 | A2 新增 |

### 5.2 配置差异示例

```dts
// ast2700a1.dtsi 特有
&bootmcu {
    compatible = "aspeed,ast2700-a1-bootmcu";
    // A1 特定的 BootMCU 配置
};

// ast2700-a2.dtsi 特有
&ufs {
    compatible = "aspeed,ast2700-a2-ufs";
    // A2 特定的 UFS 配置
};
```

## 6. 设备树编译

### 6.1 Yocto/BitBake 编译

```bash
# 编译所有 AST2700 设备树
bitbake linux-aspeed -c compile_its

# 查看编译产物
ls tmp/work/<machine>-openbmc-linux/linux-aspeed/<version>/image/boot/dtb/

# 编译特定设备树
cd tmp/work-shared/<machine>/linux-aspeed/arch/arm64/boot/dts/aspeed/
make ast2700-evb.dtb
```

### 6.2 手动编译

```bash
# 设置交叉编译环境
export ARCH=arm64
export CROSS_COMPILE=aarch64-openbmc-linux-gnu-

# 编译设备树
cd <linux-source>
make aspeed/ast2700-evb.dtb

# 输出
# arch/arm64/boot/dts/aspeed/ast2700-evb.dtb
```

## 7. 设备树覆盖 (Device Tree Overlay)

### 7.1 Yocto 层覆盖机制

Vendor 层可以在不修改内核源码的情况下提供自定义设备树：

```
meta-vendor/recipes-kernel/linux/linux-aspeed/
└── <vendor>-<board>.dts
```

### 7.2 PFR 设备树示例

位置: `meta-aspeed-sdk/meta-aspeed-pfr/meta-ast2700-pfr/`

```dts
// ast2700-dcscm-mctp-socket.dts
/dts-v1/;
#include "ast2700-evb.dts"

/ {
    // PFR 特定配置
    mctp-socket@0 {
        compatible = "aspeed,ast2700-mctp-socket";
        // MCTP over PCIe 路由
    };

    // DCSCM 组件
    dcscm {
        compatible = "aspeed,dcscm";
        // 组件身份验证
    };
};
```

## 8. 调试和验证

### 8.1 查看已加载的设备树

```bash
# 在目标板上
cat /proc/device-tree/
cat /proc/device-tree/model
cat /proc/device-tree/compatible

# 查看特定节点
hexdump -C /proc/device-tree/serial-number
```

### 8.2 DTC (Device Tree Compiler) 验证

```bash
# 反编译 DTB 为 DTS
dtc -I dtb -O dts -o output.dts input.dtb

# 检查 DTB 语法
dtc -I dtb -O dts input.dtb > /dev/null && echo "OK"

# 显示设备树结构
dtc -I dtb -o - input.dtb | grep -E "^[^\s]"
```

### 8.3 常见问题排查

| 问题 | 解决方法 |
|------|----------|
| 外设不工作 | 检查 `status = "okay"` |
| 中断不触发 | 验证 `interrupts` 属性 |
| 地址不匹配 | 核对 `#address-cells` 和 `reg` |
| 驱动未加载 | 检查 `compatible` 字符串匹配 |

## 9. 快速参考

### 9.1 常用设备树属性

| 属性 | 说明 | 示例 |
|------|------|------|
| `compatible` | 驱动匹配字符串 | `"aspeed,ast2700-i2c"` |
| `reg` | 地址和大小 | `<0x1e78a000 0x40>` |
| `interrupts` | 中断配置 | `<GIC_SPI 12 IRQ_TYPE_LEVEL_HIGH>` |
| `status` | 启用状态 | `"okay"` 或 `"disabled"` |
| `clocks` | 时钟源引用 | `<&clock>` |
| `gpio-controller` | GPIO 控制器标记 | 无值 |
| `#gpio-cells` | GPIO 引用格式 | `<2>` |

### 9.2 添加新外设模板

```dts
// 在 .dts 文件中添加
&soc {
    // 1. 添加外设节点
    new_device: device@ADDRESS {
        compatible = "vendor,device-name";
        reg = <0xADDRESS SIZE>;
        interrupts = <GIC_SPI N IRQ_TYPE_LEVEL_HIGH>;
        clocks = <&clock>;
        status = "okay";  // 默认启用
    };
};

// 2. 或者在根节点
&new_device {
    // 覆盖属性
    status = "disabled";  // 默认禁用
};
```

### 9.3 编译检查命令

```bash
# 完整内核编译 (包含 DTB)
bitbake linux-aspeed

# 仅编译设备树
bitbake linux-aspeed -c compile_its

# 查看设备树差异
diff -u baseline.dts modified.dts | head -50
```