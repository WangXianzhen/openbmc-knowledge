# Summary

- [介绍](README.md)

---

## 📦 BSP 模块分析

### 启动引导
- [Bootloader 总览](bootloader/README.md)
- [U-Boot BSP 配置](bootloader/uboot-bsp.md)
- [U-Boot 构建配置](bootloader/uboot-build.md)
- [U-Boot defconfig](bootloader/uboot-defconfig.md)

### 固件
- [BootMCU 总览](bootmcu/README.md)
- [BootMCU 固件](bootmcu/bootmcu-firmware.md)
- [FMC 设计](bootmcu/bootmcu-fmc.md)

### 内核
- [Kernel BSP](kernel/README.md)
- [内核 defconfig](kernel/kernel-defconfig.md)
- [设备树配置](kernel/kernel-dtb.md)
- [FIT 镜像](kernel/kernel-fitimage.md)

### 驱动程序
- [驱动架构](drivers/README.md)
- [外设驱动配置](drivers/drivers-overview.md)

---

## 🔒 安全组件

- [Security 总览](security/README.md)
- [PFR 架构](security/pfr/pfr-overview.md)
- [PFR 工具](security/pfr/pfr-tool.md)
- [PFR 安全特性](security/pfr/pfr-security.md)

---

## 🌐 通信协议

- [MCTP 协议](communication/mctp-overview.md)
- [MCTP 传输层](communication/mctp-transport.md)
- [SPDM 支持](communication/spdm-support.md)

---

## 📡 服务

### IPMI
- [IPMI 架构](services/ipmi/ipmi-architecture.md)
- [KCS 通道](services/ipmi/ipmi-kcs.md)
- [命令处理](services/ipmi/ipmi-commands.md)

### 传感器
- [传感器架构](services/sensors/sensor-architecture.md)
- [D-Bus 接口](services/sensors/sensor-dbus.md)
- [传感器配置](services/sensors/sensor-config.md)

### 状态管理
- [状态架构](services/state/state-architecture.md)
- [状态机设计](services/state/state-machine.md)
- [事件处理](services/state/state-events.md)

---

## 🎨 图形与调试

- [图形架构](graphics/graphics-architecture.md)
- [图形配置](graphics/graphics-config.md)
- [PDbg 工具](debug/pdbg-overview.md)
- [PDbg 使用](debug/pdbg-usage.md)

---

## 🤖 协处理器

- [SSP 概述](ssp/ssp-overview.md)
- [RTOS 支持](ssp/rtos-support.md)
- [Ibex 固件](ssp/ibexfw.md)

---

## 🔧 附录

- [仓库结构](../repo-structure.md)
- [持续学习机制](../CONTINUOUS_LEARNING.md)
- [完成报告](completion-report.md)