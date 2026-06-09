# AST2700 BMC 事件处理

## 1. 事件处理概述

AST2700 的事件处理系统通过 D-Bus 信号、systemd 单元和 shell 脚本实现状态变化的响应和处理。

## 2. D-Bus 事件信号

### 2.1 BMC 状态事件

| 信号 | 接口 | 说明 |
|------|------|------|
| `CurrentBMCState` | `xyz.openbmc_project.State.BMC` | BMC 状态变化信号 |
| `BMCReady` | `xyz.openbmc_project.State.BMC` | BMC 就绪事件 |

### 2.2 Chassis 状态事件

| 信号 | 接口 | 说明 |
|------|------|------|
| `CurrentPowerState` | `xyz.openbmc_project.State.Chassis` | 电源状态变化 |
| `RequestedPowerTransition` | `xyz.openbmc_project.State.Chassis` | 电源转换请求 |

### 2.3 Host 状态事件

| 信号 | 接口 | 说明 |
|------|------|------|
| `CurrentHostState` | `xyz.openbmc_project.State.Host` | 主机状态变化 |
| `CurrentHostState` | `xyz.openbmc_project.State.Host` | 主机运行状态变化 |
| `TransitionResult` | `xyz.openbmc_project.State.Host` | 状态转换结果 |

### 2.4 事件订阅示例

```bash
# 订阅主机状态变化
busctl subscribe xyz.openbmc_project.State.Host

# 订阅机箱电源状态变化
busctl subscribe xyz.openbmc_project.State.Chassis

# 订阅 BMC 状态变化
busctl subscribe xyz.openbmc_project.State.BMC
```

## 3. systemd 事件触发

### 3.1 主机事件目标

| 事件目标 | 触发条件 | 相关服务 |
|----------|----------|----------|
| `obmc-host-start@.target` | 用户请求开机 | `host-poweron@{i}.service` |
| `obmc-host-stop@.target` | 用户请求关机 | `host-graceful-poweroff@{i}.service` |
| `obmc-host-quiesce@.target` | 主机引导失败 | 主机静默处理 |
| `obmc-host-timeout@.target` | 看门狗超时 | 超时处理服务 |
| `obmc-host-reboot@.target` | 主机重启请求 | 电源循环重启 |
| `obmc-host-warm-reboot@.target` | 热重启请求 | 无断电重启 |

### 3.2 机箱事件目标

| 事件目标 | 触发条件 | 相关服务 |
|----------|----------|----------|
| `obmc-chassis-poweron@.target` | 机箱上电请求 | `chassis-poweron@{i}.service` |
| `obmc-chassis-poweroff@.target` | 机箱下电请求 | `chassis-poweroff@{i}.service` |
| `obmc-chassis-powercycle@.target` | 电源循环请求 | `chassis-powercycle@{i}.service` |
| `obmc-chassis-blackout@.target` | 电源中断事件 | 断电恢复处理 |
| `obmc-chassis-reset-on@.target` | BMC 复位后检查 | 状态恢复服务 |

### 3.3 事件服务依赖

#### 3.3.1 主机启动事件链

```
obmc-host-start@.target
    |
    +---> obmc-host-startmin@.target (requires)
    |           |
    |           +---> phosphor-set-host-transition-to-running@{i}.service
    |           +---> phosphor-reset-host-reboot-attempts@{i}.service
    |
    +---> host-poweron@{i}.service (wants)
    |           |
    |           +---> 调用 power-cmd 中的 power_on 函数
    |
    +---> phosphor-discover-system-state@{i}.service (wants)
```

#### 3.3.2 主机关机事件链

```
obmc-host-stop@.target
    |
    +---> obmc-host-stop-pre@.target
    |           |
    |           +---> phosphor-reset-sensor-states@{i}.service
    |
    +---> host-graceful-poweroff@{i}.service (wants)
    |           |
    |           +---> 调用 power-cmd 中的 graceful_power_off 函数
    |
    +---> phosphor-clear-one-time@{i}.service
```

#### 3.3.3 主机重启事件链

```
obmc-host-reboot@.target
    |
    +---> obmc-host-shutdown@.target (requires)
    |           |
    |           +---> obmc-host-stop@.target (requires)
    |
    +---> phosphor-reboot-host@{i}.service (requires)
```

#### 3.3.4 主机热重启事件链

```
obmc-host-warm-reboot@.target
    |
    +---> xyz.openbmc_project.Ipmi.Internal.SoftPowerOff.service (requires)
    |
    +---> obmc-host-stop@.target (requires)
    |
    +---> phosphor-reboot-host@{i}.service (requires)
    |
    +---> obmc-host-force-warm-reboot@.target (requires)
            |
            +---> host-graceful-poweroff@{i}.service (wants)
```

## 4. 事件处理脚本

### 4.1 电源控制脚本

路径: `/mnt/d/code/aspped-github/openbmc/meta-facebook/meta-yosemite5/recipes-phosphor/state/phosphor-state-manager/power-cmd`

#### 4.1.1 电源状态检查

```bash
# Power Good Status
power_status() {
    if [ "$(get_gpio "PWRGD_CPU_PWROK_1")" = "1" ]; then
        echo "on"
    else
        echo "off"
    fi
}
```

#### 4.1.2 强制断电

```bash
# Force DC off
force_power_off() {
    if [ "$(power_status)" == "on" ]; then
        set_gpio SYS_BMC_PWRBTN_N     0
        sleep 6
        set_gpio SYS_BMC_PWRBTN_N     1
    fi
}
```

#### 4.1.3 优雅关机

```bash
# Graceful DC off
graceful_power_off() {
    if [ "$(power_status)" == "on" ]; then
        set_gpio SYS_BMC_PWRBTN_N     0
        sleep 1
        set_gpio SYS_BMC_PWRBTN_N     1
        sleep 1

        # wait host power off (最多 20 秒)
        for i in $(seq 1 20)
        do
            sleep 1
            if [ "$(power_status)" == "off" ]; then
                return 0
            fi
        done

        # host power off fail
        if [ "$(power_status)" == "on" ]; then
            return 1
        fi
    fi
}
```

#### 4.1.4 上电

```bash
# DC on
power_on() {
    if [ "$(power_status)" == "off" ]; then
        set_gpio SYS_BMC_PWRBTN_N 0
        sleep 1
        set_gpio SYS_BMC_PWRBTN_N 1
        sleep 1

        # 等待电源开启 (最多 10 秒)
        for i in $(seq 1 10)
        do
            sleep 1
            if [ "$(power_status)" == "on" ]; then
                return 0
            fi

            if [ "$i" -eq 10 ]; then
                return 1
            fi
        done
    fi
    return 0
}
```

#### 4.1.5 主机复位

```bash
# Host reset
power_reset() {
    set_gpio SGPIO_RSTBTN_OUT 1
    sleep 1
    set_gpio SGPIO_RSTBTN_OUT 0
    sleep 1
    return 0
}
```

### 4.2 机箱状态初始化

路径: `/mnt/d/code/aspped-github/openbmc/meta-facebook/meta-yosemite5/recipes-phosphor/state/phosphor-state-manager/chassis-power-state-init`

```bash
#!/bin/bash

mapper wait /xyz/openbmc_project/state/chassis0
mapper wait /xyz/openbmc_project/state/chassis1

busctl set-property xyz.openbmc_project.State.Chassis0 \
    /xyz/openbmc_project/state/chassis0 \
    xyz.openbmc_project.State.Chassis \
    CurrentPowerState s \
    xyz.openbmc_project.State.Chassis.PowerState.On

busctl set-property xyz.openbmc_project.State.Chassis1 \
    /xyz/openbmc_project/state/chassis1 \
    xyz.openbmc_project.State.Chassis \
    CurrentPowerState s \
    xyz.openbmc_project.State.Chassis.PowerState.On
```

### 4.3 BMC/平台初始化

#### 4.3.1 AST2600 初始化

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

#### 4.3.2 AST2700 初始化

```bash
#!/bin/bash
# All AST2700 based devmem hacks
# (当前为空，占位符)
```

## 5. 自动电源恢复 (APR) 事件

### 5.1 APR 触发条件

| 条件 | 配置选项 | 说明 |
|------|----------|------|
| 电源中断 | `only-run-apr-on-power-loss` | 检测到 AC 电源中断 |
| 软件复位 | `run-apr-on-software-reset` | BMC 软件复位 |
| 看门狗复位 | `run-apr-on-watchdog-reset` | BMC 看门狗超时 |
| 针孔复位 | `run-apr-on-pinhole-reset` | 物理复位按钮 |

### 5.2 APR 事件处理流程

```
1. BMC 检测到复位完成
2. 检查复位原因
3. 如果是支持的 APR 触发条件:
   a. 检查 AutoPowerRestore 设置
   b. 如果启用，执行自动开机
4. 如果不是 APR 触发条件或未启用:
   a. 保持当前状态
```

### 5.3 APR 配置存储

```bash
# 存储位置
/etc/phosphor-settings-manager/config.json

# 设置项
xyz.openbmc_project.Settings.AutoPowerRestore
# 值: AlwaysOn / AlwaysOff / Restore
```

## 6. 看门狗超时事件

### 6.1 看门狗超时处理

```bash
# 启用看门狗超时目标处理
obmc-host-timeout@{i}.target
    |
    +---> phosphor-reset-sensor-states@{i}.service
    +---> obmc-host-quiesce@{i}.target (wants)
```

### 6.2 超时服务配置

```bash
# 在 bbappend 中启用
PACKAGECONFIG:append = " run-apr-on-watchdog-reset"
```

## 7. 固件更新前状态检查

### 7.1 配置选项

```bash
# 在 bb 中启用
PACKAGECONFIG[check-fwupdate-before-do-transition] = "-Dcheck-fwupdate-before-do-transition=enabled"
```

### 7.2 检查流程

```
固件更新请求 --> 检查 BMC/Chassis/Host 状态 --> 允许则继续 / 拒绝则报错
```

## 8. 安全检查事件

### 8.1 安全引导检查

```bash
# 二进制
${bindir}/phosphor-secure-boot-check

# 服务
phosphor-bmc-security-check.service
```

### 8.2 安全事件处理

- 启动时验证安全策略
- 更新前检查安全状态
- 失败时阻止不安全的操作

## 9. PFR 状态监控 (AST2700 PFR)

### 9.1 MCTP I3C 状态监控

路径: `/mnt/d/code/aspped-github/openbmc/meta-aspeed-sdk/meta-aspeed-pfr/meta-ast2700-pfr/recipes-intel/pfr/pfr-mctp-i3c/mctp-i3c-state-monitor.service`

```ini
[Unit]
Description=Monitor Host Power State for PFR MCTP I3C
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/mctp-i3c-state-monitor.sh
Restart=on-failure
RestartSec=5
SyslogIdentifier=mctp-i3c-state-monitor

[Install]
WantedBy=multi-user.target
```

### 9.2 监控脚本

```bash
# 监控主机电源状态
# 根据主机状态调整 MCTP I3C 配置
```

## 10. 事件日志记录

### 10.1 机箱上电日志

```bash
# 包
${PN}-chassis-poweron-log

# 服务
phosphor-create-chassis-poweron-log@{i}.service

# 默认启用
RRECOMMENDS:${PN}-chassis:append = " ${PN}-chassis-poweron-log"
```

### 10.2 日志事件类型

| 事件 | 日志级别 | 说明 |
|------|----------|------|
| 机箱上电 | INFO | 机箱电源开启 |
| 机箱下电 | INFO | 机箱电源关闭 |
| 主机启动 | INFO | 主机开始启动 |
| 主机停止 | INFO | 主机正常关闭 |
| 主机崩溃 | ERROR | 主机异常终止 |
| 看门狗超时 | ERROR | 主机无响应 |
| 状态转换失败 | ERROR | 操作失败记录 |

## 11. GPIO 事件处理

### 11.1 主机状态 GPIO

当启用 `host-gpios` 配置时:

```bash
PACKAGECONFIG[host-gpio] = "-Dhost-gpios=enabled,-Dhost-gpios=disabled,gpioplus"
```

### 11.2 GPIO 监控服务

```bash
# 服务
phosphor-host-condition-gpio@.service

# 功能
- 监控主机状态 GPIO 引脚
- 根据 GPIO 状态更新主机运行状态
```

## 12. 调度的主机转换事件

### 12.1 定时开机

```bash
# 服务
xyz.openbmc_project.State.ScheduledHostTransition@.service

# 二进制
${bindir}/phosphor-scheduled-host-transition

# D-Bus 接口
xyz.openbmc_project.State.ScheduledHostTransition
```

### 12.2 调度事件处理

```
调度时间到达 --> 检查调度条件 --> 执行主机状态转换
```

## 13. 事件处理最佳实践

### 13.1 状态检查顺序

1. 检查 BMC 状态是否为 Ready
2. 检查 Chassis 电源状态
3. 确认操作不违反安全规则
4. 执行状态转换

### 13.2 错误处理

- 所有脚本应返回明确的退出码
- 失败时应记录日志
- 必要时触发回退操作

### 13.3 并发控制

- 使用 systemd 依赖确保顺序执行
- 避免并发状态转换
- 使用 ConditionPathExists 防止重复执行

### 13.4 超时设置

| 操作 | 默认超时 | 可配置 |
|------|----------|--------|
| 优雅关机 | 20 秒 | 是 |
| 电源开启 | 10 秒 | 是 |
| 主机复位 | 1 秒 | 是 |