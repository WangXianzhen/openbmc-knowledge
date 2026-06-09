# AST2700 传感器 D-Bus 接口

## 概述

AST2700 传感器通过 D-Bus 提供标准化的接口，支持 IPMI 和 Redfish 访问。

## D-Bus 对象层次

```
/xyz/openbmc_project/
    |
    +-- sensing/
    |   +-- <sensor_name>/
    |       +-- Value           (当前值)
    |       +-- MaxValue        (最大值)
    |       +-- MinValue        (最小值)
    |       +-- Unit            (单位)
    |       +-- Scale           (缩放因子)
    |
    +-- sensors/
        +-- temperature/
        |   +-- <sensor_name>/
        |       +-- CriticalHigh
        |       +-- CriticalLow
        |       +-- WarningHigh
        |       +-- WarningLow
        |
        +-- fans/
        |   +-- <fan_name>/
        |       +-- TargetSpeed
        |       +-- SpeedPercent
        |
        +-- voltage/
        |   +-- <sensor_name>/
        |       +-- Value
        |       +-- Thresholds
```

## 核心接口

### xyz.openbmc_project.Sensor.Value

所有传感器都实现此接口:

```cpp
interface xyz.openbmc_project.Sensor.Value {
    property double value;
    property uint64_t timestamp;
};
```

### xyz.openbmc_project.Sensor.Threshold.Critical

阈值告警接口:

```cpp
interface xyz.openbmc_project.Sensor.Threshold.Critical {
    property double criticalHigh;
    property double criticalLow;
};
```

### xyz.openbmc_project.HwmonTempSensor

温度传感器特定接口:

```cpp
interface xyz.openbmc_project.HwmonTempSensor {
    // 继承自 Sensor.Value
    property double value;
};
```

### xyz.openbmc_project.FanSensor

风扇传感器接口:

```cpp
interface xyz.openbmc_project.FanSensor {
    property uint64_t Target;      // 目标转速
    property uint64_t RPM;         // 当前转速
    property double SpeedPercent;  // 速度百分比
};
```

## IPMI 映射

### 传感器编号 (Sensor Number)

| 传感器类型 | 起始编号 | 说明 |
|-----------|----------|------|
| 温度 | 0x01 | 环境/芯片温度 |
| 电压 | 0x10 | ADC 电压 |
| 风扇 | 0x30 | 转速 RPM |
| 入侵检测 | 0x60 | 机箱入侵 |

### IPMI SDR 记录

IPMI 传感器数据记录 (SDR) 定义:

```yaml
sensorID:
  entityID: 0x??        # 实体 ID
  entityInstance: ?     # 实体实例
  sensorType: 0x??      # 传感器类型
  path: /xyz/...        # D-Bus 路径
  sensorReadingType: 0x6F
  serviceInterface: org.freedesktop.DBus.Properties
  readingType: eventdata2  # 或 assertion
```

### 关键 D-Bus 属性映射

| IPMI 属性 | D-Bus 接口 | 属性名 |
|-----------|------------|--------|
| Reading | Sensor.Value | value |
| Upper Critical | Threshold.Critical | criticalHigh |
| Lower Critical | Threshold.Critical | criticalLow |
| Assertion | OperationalStatus | Functional |

## 服务名称

各传感器服务在 D-Bus 上的服务名:

| 服务 | 服务名 |
|------|--------|
| ADC Sensor | xyz.openbmc_project.adcsensor |
| Fan Sensor | xyz.openbmc_project.fansensor |
| Hwmon Temp | xyz.openbmc_project.hwmontempsensor |
| Intrusion | xyz.openbmc_project.intrusionsensor |
| Generic Hwmon | xyz.openbmc_project.Hwmon-* |

## 传感器配置示例

### AST2700 EVB 配置

AST2700 EVB 上的传感器配置 (`blacklist.json`):

```json
{
  "Exposes": [
    {
      "Address": "0x4d",
      "Bus": 0,
      "Name": "Ambient_Temp",
      "Type": "LM75A",
      "Thresholds": [
        {"Direction": "greater than", "Name": "upper critical", "Value": 40},
        {"Direction": "greater than", "Name": "upper non critical", "Value": 38},
        {"Direction": "less than", "Name": "lower non critical", "Value": 5},
        {"Direction": "less than", "Name": "lower critical", "Value": 0}
      ]
    },
    {
      "Index": 0,
      "Name": "ADC0_12V",
      "ScaleFactor": 0.1515,
      "Type": "ADC",
      "Thresholds": [...]
    },
    {
      "Connector": {"Pwm": 0, "Tachs": [0]},
      "Name": "Fan 0",
      "Type": "AspeedFan",
      "Thresholds": [...]
    }
  ]
}
```

## 访问方式

### D-Bus 查询

```bash
# 查看所有传感器
busctl tree xyz.openbmc_project

# 获取传感器值
busctl get-property xyz.openbmc_project.hwmontempsensor \
    /xyz/openbmc_project/sensors/temperature/ambient_temp \
    xyz.openbmc_project.Sensor.Value Value

# 列出传感器支持的方法
busctl introspect xyz.openbmc_project.hwmontempsensor \
    /xyz/openbmc_project/sensors/temperature/ambient_temp
```

### IPMI 命令

```bash
# 读取传感器数据
ipmitool sensor reading "Ambient_Temp"

# 列出所有传感器
ipmitool sensor list

# 获取 SDR 记录
ipmitool sensor get 0x01
```

## 阈值告警流程

```
1. 传感器值更新
   phosphor-hwmon -> 读取 hwmon -> 更新 D-Bus 属性

2. 阈值检查
   dbus-sensors -> 订阅属性变化 -> 检查阈值

3. 告警生成
   触发阈值 -> 发送 D-Bus 信号 -> 记录日志
   -> 触发 IPMI SEL (System Event Log)

4. 事件通知
   phosphor-logging -> 写入 journal
   phosphor-ipmi-sel -> 写入 IPMI SEL
```

## 文件位置

| 文件 | 路径 |
|------|------|
| IPMI 传感器配置 | `/mnt/d/code/aspped-github/openbmc/meta-phosphor/recipes-phosphor/ipmi/phosphor-ipmi-sensor-inventory/config.yaml` |
| D-Bus 接口定义 | `phosphor-dbus-interfaces` |
| AST2700 配置 | `/mnt/d/code/aspped-github/openbmc/meta-aspeed-sdk/meta-ast2700-sdk/recipes-phosphor/configuration/entity-manager/` |