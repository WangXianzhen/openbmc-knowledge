# AST2700 BMC 状态管理架构

## 1. 概述

AST2700 的 BMC 状态管理服务基于 OpenBMC 的 Phosphor State Manager 实现，采用分层架构管理 BMC、Chassis（机箱）和 Host（主机）的状态。

## 2. 核心组件

### 2.1 配方文件位置

| 组件 | 路径 |
|------|------|
| 主配方 | `/mnt/d/code/aspped-github/openbmc/meta-phosphor/recipes-phosphor/state/phosphor-state-manager_git.bb` |
| systemd 链接配置 | `/mnt/d/code/aspped-github/openbmc/meta-phosphor/recipes-phosphor/state/phosphor-state-manager-systemd-links.inc` |
| 平台定制 | `/mnt/d/code/aspped-github/openbmc/meta-facebook/recipes-phosphor/state/phosphor-state-manager_%.bbappend` |

### 2.2 包结构

```
phosphor-state-manager (主包)
├── phosphor-state-manager-host      # 主机状态管理
├── phosphor-state-manager-chassis   # 机箱状态管理
├── phosphor-state-manager-bmc       # BMC 状态管理
├── phosphor-state-manager-hypervisor
├── phosphor-state-manager-discover  # 系统状态发现
├── phosphor-state-manager-host-check
├── phosphor-state-manager-reset-sensor-states
├── phosphor-state-manager-systemd-target-monitor
├── phosphor-state-manager-obmc-targets
├── phosphor-state-manager-scheduled-host-transition
├── phosphor-state-manager-chassis-check-power-status
├── phosphor-state-manager-secure-check
└── phosphor-state-manager-chassis-poweron-log
```

## 3. AST2700 特定配置

### 3.1 机器配置文件

路径: `/mnt/d/code/aspped-github/openbmc/meta-aspeed-sdk/meta-ast2700-sdk/conf/machine/ast2700-default.conf`

```bash
MACHINE_FEATURES += "\
        obmc-phosphor-fan-mgmt \
        obmc-phosphor-chassis-mgmt \
        obmc-phosphor-flash-mgmt \
        obmc-host-ipmi \
        obmc-host-state-mgmt \
        obmc-chassis-state-mgmt \
        obmc-bmc-state-mgmt \
        "

VIRTUAL-RUNTIME_obmc-host-state-manager ?= "x86-power-control"
VIRTUAL-RUNTIME_obmc-chassis-state-manager ?= "x86-power-control"
```

### 3.2 状态管理服务映射

| MACHINE_FEATURE | Package Group | Virtual Runtime |
|-----------------|---------------|-----------------|
| `obmc-bmc-state-mgmt` | `packagegroup-obmc-apps-bmc-state-mgmt` | - |
| `obmc-chassis-state-mgmt` | `packagegroup-obmc-apps-chassis-state-mgmt` | `${VIRTUAL-RUNTIME_obmc-chassis-state-manager}` |
| `obmc-host-state-mgmt` | `packagegroup-obmc-apps-host-state-mgmt` | `${VIRTUAL-RUNTIME_obmc-host-state-manager}` |

### 3.3 Facebook/Yosemite5 平台定制

路径: `/mnt/d/code/aspped-github/openbmc/meta-facebook/meta-yosemite5/conf/machine/yosemite5.conf`

```bash
VIRTUAL-RUNTIME_obmc-host-state-manager = "phosphor-state-manager-host"
VIRTUAL-RUNTIME_obmc-chassis-state-manager = "phosphor-state-manager-chassis"
```

## 4. 系统架构图

```
+------------------+     +------------------+     +------------------+
|   BMC State      |     | Chassis State    |     |   Host State     |
|   Manager        |     |   Manager        |     |   Manager        |
| (phosphor-bmc)   |<--->| (phosphor-       |<--->| (phosphor-host)  |
|                  |     |  chassis)        |     |                  |
+--------+---------+     +--------+---------+     +--------+---------+
         |                        |                        |
         v                        v                        v
+------------------+     +------------------+     +------------------+
| xyz.openbmc_     |     | xyz.openbmc_     |     | xyz.openbmc_     |
| project.State.   |     | project.State.   |     | project.State.   |
| BMC              |     | Chassis          |     | Host             |
+------------------+     +------------------+     +------------------+
```

## 5. D-Bus 接口定义

### 5.1 BMC 状态接口
- 总线名称: `xyz.openbmc_project.State.BMC`
- 服务文件: `xyz.openbmc_project.State.BMC.service`

### 5.2 Chassis 状态接口
- 总线名称: `xyz.openbmc_project.State.Chassis`
- 实例化: `xyz.openbmc_project.State.Chassis0`, `xyz.openbmc_project.State.Chassis1`
- 服务文件: `xyz.openbmc_project.State.Chassis@.service`

### 5.3 Host 状态接口
- 总线名称: `xyz.openbmc_project.State.Host`
- 实例化: `xyz.openbmc_project.State.Host0`
- 服务文件: `xyz.openbmc_project.State.Host@.service`

## 6. 编译配置选项

### 6.1 PACKAGECONFIG 选项

| 选项 | 默认 | 说明 |
|------|------|------|
| `only-run-apr-on-power-loss` | enabled | 仅在电源丢失时运行自动电源恢复 |
| `only-allow-boot-when-bmc-ready` | enabled | BMC 未就绪时禁止启动操作 |
| `run-apr-on-software-reset` | enabled | BMC 软件复位时运行 APR |
| `run-apr-on-watchdog-reset` | 可选 | 看门狗复位时运行 APR |
| `run-apr-on-pinhole-reset` | 可选 | 针孔复位时运行 APR |
| `host-gpio` | 可选 | 启用主机状态 GPIO |
| `check-fwupdate-before-do-transition` | 可选 | 固件更新前检查状态转换 |
| `no-warm-reboot` | 可选 | 禁用主机热重启 |
| `auto-reboot-on-bmc-quiesce` | 可选 | BMC 静默时自动重启 |

### 6.2 依赖项

```
DEPENDS += "sdbusplus sdeventplus phosphor-logging phosphor-dbus-interfaces libcereal nlohmann-json cli11 libgpiod"
```

## 7. systemd 目标系统

### 7.1 主机同步目标
```
HOST_SYNCH_TARGETS = "start-pre starting started stop-pre stopping stopped reset-running"
```

### 7.2 主机动作目标
```
HOST_ACTION_TARGETS = "start startmin stop quiesce graceful-quiesce shutdown crash timeout reboot warm-reboot force-warm-reboot diagnostic-mode"
```

### 7.3 机箱同步目标
```
CHASSIS_SYNCH_TARGETS = "start-pre start on stop-pre stop off reset-on"
```

### 7.4 机箱动作目标
```
CHASSIS_ACTION_TARGETS = "poweron poweroff powercycle powered-off powerreset hard-poweroff blackout"
```

## 8. 目标依赖关系

### 8.1 关键依赖链
- 主机启动需要机箱电源开启
- 机箱关闭需要主机先关闭
- 强制关机需要机箱先关闭

### 8.2 符号链接生成

在 `phosphor-state-manager-systemd-links.inc` 中定义的 postinst 脚本会自动创建 systemd 依赖链接。

## 9. 包组定义

路径: `/mnt/d/code/aspped-github/openbmc/meta-phosphor/recipes-phosphor/packagegroups/packagegroup-obmc-apps.bb`

```bash
SUMMARY:${PN}-bmc-state-mgmt = "BMC state management"
RDEPENDS:${PN}-bmc-state-mgmt = " \
        ${VIRTUAL-RUNTIME_obmc-bmc-state-manager} \
        phosphor-state-manager-systemd-target-monitor \
        "

SUMMARY:${PN}-chassis-state-mgmt = "Chassis state management"
RDEPENDS:${PN}-chassis-state-mgmt = " \
        ${VIRTUAL-RUNTIME_obmc-chassis-state-manager} \
        obmc-phosphor-power \
        "

SUMMARY:${PN}-host-state-mgmt = "Host state management"
RDEPENDS:${PN}-host-state-mgmt = " \
        ${VIRTUAL-RUNTIME_obmc-host-state-manager} \
        ${VIRTUAL-RUNTIME_obmc-discover-system-state} \
        "
```

## 10. 平台特定初始化

### 10.1 AST2600 初始化脚本
路径: `/mnt/d/code/aspped-github/openbmc/meta-facebook/meta-yosemite5/recipes-phosphor/state/phosphor-state-manager/ast2600/phosphor-state-manager-init`

```bash
#!/bin/bash
# Create /dev/mem
if [ ! -c /dev/mem ]; then
    /bin/mknod /dev/mem c 1 1
fi
# eSPI init
echo "AST2600 eSPI init"
devmem 0x1e6ee000 32 0xff00ba55
devmem 0x1e6e2454 32 0xaa000000
devmem 0x1e6e2094 32 0x00000003
```

### 10.2 AST2700 初始化脚本
路径: `/mnt/d/code/aspped-github/openbmc/meta-facebook/meta-yosemite5/recipes-phosphor/state/phosphor-state-manager/ast2700/phosphor-state-manager-init`

```bash
#!/bin/bash
# All AST2700 based devmem hacks
#echo "AST2700 eSPI init"
```

## 11. 构建输出

编译后的二进制和配置文件位于:
- `${bindir}/phosphor-host-state-manager`
- `${bindir}/phosphor-chassis-state-manager`
- `${bindir}/phosphor-bmc-state-manager`
- `${sysconfdir}/phosphor-systemd-target-monitor/`

## 12. 安全特性

### 12.1 phosphor-secure-check
- 二进制: `${bindir}/phosphor-secure-boot-check`
- 服务: `phosphor-bmc-security-check.service`

### 12.2 BMC 静默重启
启用 `auto-reboot-on-bmc-quiesce` 后:
- 服务: `phosphor-bmc-quiesce-reboot.service`
- 目标: `obmc-bmc-service-quiesce@.target`