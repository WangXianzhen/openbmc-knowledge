# AST2700 BMC 状态机设计

## 1. 状态机概述

AST2700 的状态管理系统实现了三个独立但相互关联的状态机：
- BMC 状态机
- Chassis（机箱）状态机
- Host（主机）状态机

这些状态机通过 D-Bus 信号和 systemd 目标依赖进行协调。

## 2. BMC 状态机

### 2.1 BMC 状态值

| 状态 | D-Bus 值 | 说明 |
|------|----------|------|
| Starting | `xyz.openbmc_project.State.BMC.BMCState.Starting` | BMC 正在启动 |
| Ready | `xyz.openbmc_project.State.BMC.BMCState.Ready` | BMC 就绪，可接受命令 |
| NotReady | `xyz.openbmc_project.State.BMC.BMCState.NotReady` | BMC 未就绪 |
| Quiesce | `xyz.openbmc_project.State.BMC.BMCState.Quiesce` | BMC 进入静默状态 |

### 2.2 BMC 状态转换

```
Starting --> Ready --> Quiesce --> Starting (重启)
                |
                v
            NotReady (错误状态)
```

### 2.3 BMC 服务文件

路径: `/mnt/d/code/aspped-github/openbmc/meta-phosphor/recipes-phosphor/state/phosphor-state-manager_git.bb`

```bash
FILES:${PN}-bmc = "${bindir}/phosphor-bmc-state-manager"
FILES:${PN}-bmc += "${sysconfdir}/phosphor-systemd-target-monitor/phosphor-service-monitor-default.json"
FILES:${PN}-bmc += "${bindir}/obmcutil"
DBUS_SERVICE:${PN}-bmc += "xyz.openbmc_project.State.BMC.service"
DBUS_SERVICE:${PN}-bmc += "obmc-bmc-service-quiesce@.target"
SYSTEMD_SERVICE:${PN}-bmc += "phosphor-bmc-quiesce-reboot.service"
```

### 2.4 BMC 自动重启特性

当启用 `auto-reboot-on-bmc-quiesce` 配置时：
- BMC 进入 Quiesce 状态后自动触发重启
- 使用 `obmc-bmc-service-quiesce@.target` 目标

## 3. Chassis（机箱）状态机

### 3.1 机箱电源状态

| 状态 | D-Bus 值 | 说明 |
|------|----------|------|
| Off | `xyz.openbmc_project.State.Chassis.PowerState.Off` | 机箱电源关闭 |
| On | `xyz.openbmc_project.State.Chassis.PowerState.On` | 机箱电源开启 |

### 3.2 机箱状态转换图

```
                    +-----------------+
                    |                 |
                    v                 |
+------------+   +------+   +------+  |   +------------+
|  Off       |<--| on   |-->| Off  |--+   |  (其他)    |
|            |   |      |   |      |      |            |
+------------+   +------+   +------+      +------------+
     ^              |           ^
     |              v           |
     |         +---------+      |
     +---------|  On    |------+
               +---------+
```

### 3.3 systemd 目标系统

#### 3.3.1 机箱同步目标 (CHASSIS_SYNCH_TARGETS)

```bash
CHASSIS_SYNCH_TARGETS = "start-pre start on stop-pre stop off reset-on"
```

| 目标 | 说明 |
|------|------|
| `obmc-chassis-start-pre@.target` | 机箱开机前准备 |
| `obmc-chassis-start@.target` | 机箱开机 |
| `obmc-chassis-on@.target` | 机箱电源已开启 |
| `obmc-chassis-stop-pre@.target` | 机箱关机前准备 |
| `obmc-chassis-stop@.target` | 机箱关机 |
| `obmc-chassis-off@.target` | 机箱电源已关闭 |
| `obmc-chassis-reset-on@.target` | BMC 复位后检查机箱状态 |

#### 3.3.2 机箱动作目标 (CHASSIS_ACTION_TARGETS)

```bash
CHASSIS_ACTION_TARGETS = "poweron poweroff powercycle powered-off powerreset hard-poweroff blackout"
```

| 目标 | 说明 |
|------|------|
| `obmc-chassis-poweron@.target` | 机箱上电 |
| `obmc-chassis-poweroff@.target` | 机箱下电 |
| `obmc-chassis-powercycle@.target` | 机箱电源循环 |
| `obmc-chassis-powered-off@.target` | 等待机箱断电完成 |
| `obmc-chassis-powerreset@.target` | 机箱复位检查 |
| `obmc-chassis-hard-poweroff@.target` | 强制立即下电 |
| `obmc-chassis-blackout@.target` | 电源中断进入的状态 |

### 3.4 Facebook/Yosemite5 机箱服务

路径: `/mnt/d/code/aspped-github/openbmc/meta-facebook/meta-yosemite5/recipes-phosphor/state/phosphor-state-manager/`

#### 3.4.1 机箱上电服务

**chassis-poweron@.service**
```ini
[Unit]
Description=Chassis Power On: %i

[Service]
Type=oneshot
ExecStart=/usr/libexec/phosphor-state-manager/chassis-poweron %i

[Install]
WantedBy=obmc-chassis-poweron@%i.target
```

**chassis-poweron** (脚本)
```bash
#!/bin/bash
busctl set-property \
xyz.openbmc_project.State.Chassis1 \
/xyz/openbmc_project/state/chassis1 \
xyz.openbmc_project.State.Chassis \
CurrentPowerState s \
xyz.openbmc_project.State.Chassis.PowerState.On
```

#### 3.4.2 机箱下电服务

**chassis-poweroff@.service**
```ini
[Unit]
Description=Chassis Power Off: %i

[Service]
Type=oneshot
ExecStart=/usr/libexec/phosphor-state-manager/chassis-poweroff %i

[Install]
WantedBy=obmc-chassis-hard-poweroff@%i.target
```

## 4. Host（主机）状态机

### 4.1 主机状态值

| 状态 | D-Bus 值 | 说明 |
|------|----------|------|
| Off | `xyz.openbmc_project.State.Host.HostState.Off` | 主机关闭 |
| On | `xyz.openbmc_project.State.Host.HostState.On` | 主机开启 |
| Quiesce | `xyz.openbmc_project.State.Host.HostState.Quiesce` | 主机进入静默 |
| Transitioning | `xyz.openbmc_project.State.Host.HostState.Transitioning` | 状态转换中 |

### 4.2 主机运行状态

| 状态 | D-Bus 值 | 说明 |
|------|----------|------|
| Off | `xyz.openbmc_project.State.Host.HostRunningState.Off` | 主机未运行 |
| Running | `xyz.openbmc_project.State.Host.HostRunningState.Running` | 主机运行中 |
| Quiesced | `xyz.openbmc_project.State.Host.HostRunningState.Quiesced` | 主机已静默 |

### 4.3 主机状态转换图

```
+------------+     +--------------+
|    Off     |<----|  (Boot)      |
+------------+     +--------------+
      ^                   |
      |                   v
+------------+     +--------------+
|  Quiesced  |<----|   Running    |
+------------+     +--------------+
                         ^
                         |
                   +------------+
                   |Transitioning|
                   +------------+
```

### 4.4 systemd 目标系统

#### 4.4.1 主机同步目标 (HOST_SYNCH_TARGETS)

```bash
HOST_SYNCH_TARGETS = "start-pre starting started stop-pre stopping stopped reset-running"
```

| 目标 | 说明 |
|------|------|
| `obmc-host-start-pre@.target` | 主机启动前准备 |
| `obmc-host-starting@.target` | 主机启动中 |
| `obmc-host-started@.target` | 主机已启动 |
| `obmc-host-stop-pre@.target` | 主机停止前准备 |
| `obmc-host-stopping@.target` | 主机停止中 |
| `obmc-host-stopped@.target` | 主机已停止 |
| `obmc-host-reset-running@.target` | BMC 复位后检查主机状态 |

#### 4.4.2 主机动作目标 (HOST_ACTION_TARGETS)

```bash
HOST_ACTION_TARGETS = "start startmin stop quiesce graceful-quiesce shutdown crash timeout reboot warm-reboot force-warm-reboot diagnostic-mode"
```

| 目标 | 说明 |
|------|------|
| `obmc-host-start@.target` | 主机开机 |
| `obmc-host-startmin@.target` | 最小启动要求 |
| `obmc-host-stop@.target` | 主机关机 |
| `obmc-host-quiesce@.target` | 主机静默 (引导失败) |
| `obmc-host-graceful-quiesce@.target` | 优雅静默 (允许优雅关闭) |
| `obmc-host-shutdown@.target` | 主机关闭后停止 |
| `obmc-host-crash@.target` | 主机崩溃 |
| `obmc-host-timeout@.target` | 看门狗超时 |
| `obmc-host-reboot@.target` | 主机重启 (含电源循环) |
| `obmc-host-warm-reboot@.target` | 主机热重启 (无电源循环) |
| `obmc-host-force-warm-reboot@.target` | 强制热重启 |
| `obmc-host-diagnostic-mode@.target` | 诊断模式 |

### 4.5 Facebook/Yosemite5 主机服务

#### 4.5.1 主机上电服务

**host-poweron@.service**
```ini
[Unit]
Description=Power on host:%i
After=obmc-chassis-poweron@%i.target
Wants=obmc-chassis-poweron@%i.target
OnFailure=host-poweron-failure@%i.service

[Service]
Restart=no
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/libexec/phosphor-state-manager/host-poweron %i

[Install]
WantedBy=obmc-host-start@%i.target
```

**host-poweron** (脚本)
```bash
#!/bin/bash
source /usr/libexec/phosphor-state-manager/power-cmd
echo "Starting Power on"
power_on
st=$?
if [ "$st" -ne 0 ]; then
   exit 1
fi
exit 0
```

#### 4.5.2 主机优雅关机服务

**host-graceful-poweroff@.service**
```ini
[Unit]
Description=power off host:%i
Wants=obmc-host-stop-pre@%i.target
Before=obmc-host-stop-pre@%i.target
Conflicts=obmc-host-start@%i.target
ConditionPathExists=!/run/openbmc/host@%i-request
OnFailure=host-graceful-poweroff-failure@%i.service

[Service]
Restart=no
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/libexec/phosphor-state-manager/host-graceful-poweroff %i

[Install]
WantedBy=obmc-host-warm-reboot@%i.target
```

**host-graceful-poweroff** (脚本)
```bash
#!/bin/bash
source /usr/libexec/phosphor-state-manager/power-cmd
echo "Starting Graceful Power off"
if ! graceful_power_off; then
    echo "Graceful Power off failed."
    exit 1
fi
```

#### 4.5.3 主机强制关机服务

**host-force-poweroff@.service**
```ini
[Unit]
Description=Force power off host:%i
After=obmc-chassis-poweroff@%i.target
Conflicts=obmc-host-start@%i.target

[Service]
Type=oneshot
ExecStart=/usr/libexec/phosphor-state-manager/host-force-poweroff %i

[Install]
WantedBy=obmc-host-stop@%i.target
```

## 5. 状态转换依赖关系

### 5.1 关键依赖规则

| 规则 | 源目标 | 依赖目标 | 说明 |
|------|--------|----------|------|
| 主机启动需要机箱上电 | `obmc-host-startmin@.target` | `obmc-chassis-poweron@.target` | 机箱电源未开时不能启动主机 |
| 机箱关闭需要主机先关闭 | `obmc-chassis-poweroff@.target` | `obmc-host-stop@.target` | 保护关机流程 |
| 强制关机需要机箱先关闭 | `obmc-chassis-hard-poweroff@.target` | `obmc-chassis-poweroff@.target` | 确保安全关机 |

### 5.2 bbappend 中的依赖定义

路径: `/mnt/d/code/aspped-github/openbmc/meta-facebook/recipes-phosphor/state/phosphor-state-manager_%.bbappend`

```bash
# 机箱上电触发主机电源开启
CHASSIS_DEFAULT_TARGETS:append = " \
    obmc-chassis-poweron@{}.target.wants/chassis-poweron@{}.service \
    obmc-chassis-hard-poweroff@{}.target.wants/chassis-poweroff@{}.service \
    obmc-chassis-powercycle@{}.target.wants/chassis-powercycle@{}.service \
"

# 主机关机关联机箱关机
CHASSIS_DEFAULT_TARGETS:remove = " \
    obmc-chassis-poweroff@{}.target.requires/obmc-powered-off@{}.service \
"
```

## 6. 自动电源恢复 (APR)

### 6.1 配置选项

| 选项 | 说明 |
|------|------|
| `only-run-apr-on-power-loss` | 仅在电源中断时运行 APR |
| `run-apr-on-software-reset` | BMC 软件复位时运行 APR (默认启用) |
| `run-apr-on-watchdog-reset` | 看门狗复位时运行 APR |
| `run-apr-on-pinhole-reset` | 针孔复位时运行 APR |

### 6.2 APR 触发条件

```
电源恢复 --> 检查上次关机原因 --> 如果是电源中断则自动开机
```

## 7. 状态监控

### 7.1 phosphor-systemd-target-monitor

- 二进制: `${bindir}/phosphor-systemd-target-monitor`
- 配置: `${sysconfdir}/phosphor-systemd-target-monitor/phosphor-target-monitor-default.json`
- 服务: `phosphor-systemd-target-monitor.service`

### 7.2 phosphor-chassis-check-power-status

- 二进制: `${bindir}/phosphor-chassis-check-power-status`
- 服务: `phosphor-chassis-check-power-status@.service`
- 功能: 检查机箱电源状态

### 7.3 phosphor-host-check

- 二进制: `${bindir}/phosphor-host-check`
- 服务: `phosphor-reset-host-running@.service`
- 功能: BMC 复位后检查主机是否在运行