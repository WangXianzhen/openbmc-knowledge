# AST2700 传感器架构分析

## 概述

AST2700 传感器服务采用分层架构，集成 OpenBMC 标准传感器框架与 Aspeed 硬件特定实现。

## 架构层次

```
+-------------------+
|   Application     |  <- 用户空间应用 (Redfish, IPMI)
+-------------------+
        |
+-------------------+
|  phosphor-ipmi    |  <- IPMI 传感器接口
+-------------------+
        |
+-------------------+
|   dbus-sensors    |  <- D-Bus 传感器服务
|   phosphor-hwmon  |  <- 硬件监控抽象层
+-------------------+
        |
+-------------------+
|   entity-manager  |  <- 实体配置管理
+-------------------+
        |
+-------------------+
|    Linux HWMON    |  <- 内核硬件监控接口
+-------------------+
        |
+-------------------+
|   AST2700 HW      |  <- 硬件传感器 (ADC, PWM, TACH)
+-------------------+
```

## 核心组件

### 1. dbus-sensors

主传感器服务，负责从 D-Bus 配置动态创建传感器对象。

**源码位置**: `meta-phosphor/recipes-phosphor/sensors/dbus-sensors_git.bb`

**AST2700 启用的传感器类型**:
- `adcsensor` - ADC 模数转换器
- `fansensor` - 风扇转速传感器
- `hwmontempsensor` - 温度传感器
- `intrusionsensor` - 入侵检测传感器

### 2. phosphor-hwmon

硬件监控轮询服务，通过 sysfs 读取传感器数据。

**源码位置**: `meta-phosphor/recipes-phosphor/sensors/phosphor-hwmon_git.bb`

**配置生成**: 使用 MRW (Machine Readable Workbook) 从 XML 生成 .conf 文件

### 3. entity-manager

基于 JSON 配置创建 D-Bus 对象和服务。

**AST2700 配置文件**:
- `/mnt/d/code/aspped-github/openbmc/meta-aspeed-sdk/meta-ast2700-sdk/recipes-phosphor/configuration/entity-manager/ast2700-evb.json`
- `/mnt/d/code/aspped-github/openbmc/meta-aspeed-sdk/meta-ast2700-sdk/recipes-phosphor/configuration/entity-manager/blacklist.json`

## AST2700 传感器类型

### ADC 传感器
AST2700 内置多通道 ADC (12-bit, 16 通道):
- `ADC0_12V` - 12V 电源监控
- `Battery` - 电池电压监控 (ADC7)
- `ADC8_12V` - 备用 12V 监控

**ADC 配置参数**:
- `ScaleFactor`: 0.1515 (12V 分压)
- `ScaleFactor`: 0.33333 (电池 3.3V 分压)
- 参考电压: 2.5V (预分压)

### 风扇传感器
AST2700 集成风扇控制器，支持 4 通道 PWM + TACH:

| 风扇 | PWM 通道 | TACH 通道 |
|------|----------|-----------|
| Fan 0 | 0 | 0 |
| Fan 1 | 1 | 1 |
| Fan 2 | 2 | 2 |
| Fan 3 | 3 | 3 |

**阈值配置**:
- Lower Critical: 360 RPM
- Lower Non-Critical: 480 RPM

### 温度传感器
- **LM75A** (I2C 地址 0x4D, 总线 0) - 环境温度
- 内置 ADC 温度通道

### 其他传感器
- **Chassis Intrusion Sensor** - 机箱入侵检测

## 数据流

```
1. 传感器初始化
   entity-manager -> 读取 JSON 配置 -> 创建 D-Bus 对象

2. 数据采集
   phosphor-hwmon -> 读取 /sys/class/hwmon/* -> 发布到 D-Bus
   
3. 数据访问
   IPMI 命令 -> phosphor-ipmi-sensor-inventory -> 读取 D-Bus 属性
```

## 依赖关系

```
dbus-sensors
  |-- boost
  |-- i2c-tools
  |-- libgpiod
  |-- liburing
  |-- nlohmann-json
  |-- phosphor-logging
  |-- sdbusplus

phosphor-hwmon
  |-- sdbusplus
  |-- sdeventplus
  |-- stdplus
  |-- phosphor-dbus-interfaces
  |-- phosphor-logging
  |-- gpioplus
  |-- cli11
```

## Aspeed 特定补丁

AST2700 应用了以下补丁:

1. `0001-change-pre-sensor-scaling-to-2.5v.patch`
   - 将 ADC 预分压从 1.8V 改为 2.5V

2. `0003-fansensor-update-regular-expression-to-find-pwm.patch`
   - 更新正则表达式以识别 PWM 设备