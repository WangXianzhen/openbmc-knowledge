# AST2700 传感器配置说明

## 概述

AST2700 传感器配置通过多层机制实现，包括 entity-manager JSON 配置、IPMI YAML 配置和 BitBake 配方配置。

## 配置文件清单

| 文件类型 | 位置 | 用途 |
|---------|------|------|
| entity-manager JSON | `meta-aspeed-sdk/meta-ast2700-sdk/recipes-phosphor/configuration/entity-manager/` | 动态创建设备对象 |
| IPMI 传感器 YAML | `meta-phosphor/recipes-phosphor/ipmi/` | IPMI SDR 映射 |
| hwmon 配置 | `build/*/tmp/work/*/phosphor-hwmon/*/hwmon/` | 内核 hwmon 参数 |
| BitBake 配方 | `meta-*/recipes-phosphor/sensors/` | 构建配置 |

## 1. Entity-Manager 配置

### 主配置文件

```
/mnt/d/code/aspped-github/openbmc/meta-aspeed-sdk/meta-ast2700-sdk/recipes-phosphor/configuration/entity-manager/
    ast2700-evb.json    <- 总线配置
    blacklist.json      <- 传感器/设备黑名单
```

### 总线配置 (ast2700-evb.json)

```json
{
    "buses": [0, 16, 17, 18, 19, 20, 21, 22, 23]
}
```

定义 entity-manager 需要扫描的 I2C 总线。

### 设备配置 (blacklist.json)

定义传感器和外设的配置:

```json
{
  "Exposes": [
    {
      "Address": "0x50",
      "Bus": 4,
      "Name": "AST2700 FRU",
      "Type": "EEPROM"
    },
    {
      "Address": "0x4d",
      "Bus": 0,
      "Name": "Ambient_Temp",
      "Type": "LM75A",
      "Thresholds": [...]
    }
  ]
}
```

### 配置参数说明

| 参数 | 说明 | 示例 |
|------|------|------|
| `Name` | 设备/传感器名称 | "Ambient_Temp" |
| `Type` | 设备类型 | "LM75A", "ADC", "AspeedFan" |
| `Address` | I2C 地址 (十六进制) | "0x50" |
| `Bus` | I2C 总线号 | 0, 4 |
| `Index` | ADC 通道号 | 0, 7, 8 |
| `ScaleFactor` | 电压分压系数 | 0.1515 |
| `PollRate` | 轮询间隔 (秒) | 43200 |
| `Thresholds` | 告警阈值配置 | 见下方 |

### 阈值配置

```json
{
  "Direction": "greater than | less than",
  "Name": "upper critical | upper non critical | lower critical | lower non critical",
  "Severity": 0 | 1,
  "Value": 数值
}
```

- `Severity`: 0 = Warning, 1 = Critical
- `Direction`: 阈值方向

### 风扇配置

```json
{
  "Connector": {
    "Name": "PWM 0 connector",
    "Pwm": 0,
    "PwmName": "Pwm_0",
    "Tachs": [0]
  },
  "Name": "Fan 0",
  "Index": 0,
  "Type": "AspeedFan",
  "PowerState": "Always",
  "Thresholds": [
    {"Direction": "less than", "Name": "lower critical", "Value": 360},
    {"Direction": "less than", "Name": "lower non critical", "Value": 480}
  ]
}
```

## 2. IPMI 传感器配置

### 配置文件

```
meta-phosphor/recipes-phosphor/ipmi/phosphor-ipmi-sensor-inventory/
    config.yaml      <- 通用传感器配置

meta-phosphor/recipes-phosphor/ipmi/phosphor-ipmi-sensor-inventory-mrw/
    merge_sensor_config.py   <- YAML 合并脚本
```

### 配置格式 (config.yaml)

```yaml
0x03:
  entityID: 0x22              # 实体 ID
  entityInstance: 1           # 实体实例
  sensorType: 0x0F            # 传感器类型
  path: /xyz/openbmc_project/state/host0
  sensorReadingType: 0x6F     # 读数类型
  serviceInterface: org.freedesktop.DBus.Properties
  readingType: eventdata2
  mutability: Mutability::Write|Mutability::Read
  sensorNamePattern: nameProperty
  interfaces:
    xyz.openbmc_project.State.Boot.Progress:
      BootProgress:
        Offsets:
          0x13:
            type: string
            set: xyz.openbmc_project.State.Boot.Progress.ProgressStages.OSStart
```

### IPMI 传感器类型代码

| 类型代码 | 说明 |
|---------|------|
| 0x01 | 温度 |
| 0x02 | 电压 |
| 0x04 | 风扇 |
| 0x07 | 实体存在 |
| 0x0C | 实体特定 |
| 0x0F | 启动进度 |
| 0x1F | OS 状态 |
| 0xC3 | 重启尝试 |
| 0xCA | 电源冗余 |

## 3. dbus-sensors 配方配置

### 文件位置

```
meta-aspeed-sdk/recipes-phosphor/sensors/
    dbus-sensors_%.bbappend    <- Aspeed 特定配置
    dbus-sensors/
        0001-change-pre-sensor-scaling-to-2.5v.patch
        0003-fansensor-update-regular-expression-to-find-pwm.patch
```

### bbappend 配置

```bash
# 仅启用必要的传感器类型
PACKAGECONFIG = "adcsensor"
PACKAGECONFIG:append = " fansensor"
PACKAGECONFIG:append = " hwmontempsensor"
PACKAGECONFIG:append = " intrusionsensor"
```

### 支持的 PACKAGECONFIG 选项

| 选项 | 说明 |
|------|------|
| `adcsensor` | ADC 传感器 |
| `fansensor` | 风扇传感器 |
| `hwmontempsensor` | HWMON 温度传感器 |
| `intrusionsensor` | 入侵检测 |
| `psusensor` | 电源单元传感器 |
| `nvmesensor` | NVMe 传感器 |
| `external` | 外部传感器 |
| `mcutempsensor` | MCU 温度传感器 |

## 4. phosphor-hwmon 配置

### 配方文件

```
meta-phosphor/recipes-phosphor/sensors/
    phosphor-hwmon_git.bb
    phosphor-hwmon-config-mrw.bb
```

### 配置生成

`phosphor-hwmon-config-mrw.bb` 从 MRW XML 生成 hwmon 配置文件:

```bash
${STAGING_BINDIR_NATIVE}/perl-native/perl \
    ${STAGING_BINDIR_NATIVE}/hwmon.pl \
    -x ${mrw_datadir}/${MRW_XML} \
    -d ${WORKDIR}/mrw-config-files
```

### 输出配置位置

```
/etc/default/obmc/hwmon/
    <hwmon-path>/
        *.conf
```

## 5. 修改配置的方法

### 添加新传感器

1. 编辑 `blacklist.json` 添加设备定义:

```bash
cd /mnt/d/code/aspped-github/openbmc
vim meta-aspeed-sdk/meta-ast2700-sdk/recipes-phosphor/configuration/entity-manager/blacklist.json
```

2. 添加对应的 IPMI 配置 (如需要):

```bash
vim meta-phosphor/recipes-phosphor/ipmi/phosphor-ipmi-sensor-inventory/config.yaml
```

3. 重新构建:

```bash
bitbake obmc-phosphor-image -c compile
```

### 修改阈值

在 `blacklist.json` 中修改 `Thresholds` 数组:

```json
{
  "Direction": "greater than",
  "Name": "upper critical",
  "Severity": 1,
  "Value": 45
}
```

### 添加 Aspeed 特定补丁

1. 创建补丁文件:

```bash
cd meta-aspeed-sdk/recipes-phosphor/sensors/dbus-sensors/
git diff > 000x-description.patch
```

2. 更新 bbappend:

```bash
vim dbus-sensors_%.bbappend
SRC_URI:append:aspeed-g7 = " file://000x-description.patch"
```

## 6. 调试配置

### 查看已加载的配置

```bash
# 查看 entity-manager 日志
journalctl -u entity-manager -f

# 查看传感器服务状态
systemctl status xyz.openbmc_project.adcsensor
systemctl status xyz.openbmc_project.fansensor

# 查看 D-Bus 对象
busctl tree xyz.openbmc_project | grep sensor
```

### 验证配置加载

```bash
# 检查 hwmon 配置
cat /etc/default/obmc/hwmon/*/conf

# 列出可用传感器
ls /sys/class/hwmon/
```

## 7. 配方依赖关系

```
dbus-sensors_git.bb
    |
    +-- depends: boost, i2c-tools, libgpiod, nlohmann-json, sdbusplus
    |
    +-- provides: 
    |       xyz.openbmc_project.adcsensor.service
    |       xyz.openbmc_project.fansensor.service
    |       xyz.openbmc_project.hwmontempsensor.service
    |
    +-- recommended-by:
            phosphor-hwmon (hwmon 轮询)

phosphor-hwmon_git.bb
    |
    +-- depends: sdbusplus, sdeventplus, stdplus
    |
    +-- provides:
    |       xyz.openbmc_project.Hwmon@.service (模板服务)
    |
    +-- requires:
            phosphor-hwmon-config-mrw (hwmon.conf)
```

## 8. 配置文件路径汇总

| 功能 | 绝对路径 |
|------|---------|
| AST2700 总线配置 | `/mnt/d/code/aspped-github/openbmc/meta-aspeed-sdk/meta-ast2700-sdk/recipes-phosphor/configuration/entity-manager/ast2700-evb.json` |
| AST2700 传感器配置 | `/mnt/d/code/aspped-github/openbmc/meta-aspeed-sdk/meta-ast2700-sdk/recipes-phosphor/configuration/entity-manager/blacklist.json` |
| IPMI 通用配置 | `/mnt/d/code/aspped-github/openbmc/meta-phosphor/recipes-phosphor/ipmi/phosphor-ipmi-sensor-inventory/config.yaml` |
| dbus-sensors 配方 | `/mnt/d/code/aspped-github/openbmc/meta-phosphor/recipes-phosphor/sensors/dbus-sensors_git.bb` |
| Aspeed bbappend | `/mnt/d/code/aspped-github/openbmc/meta-aspeed-sdk/recipes-phosphor/sensors/dbus-sensors_%.bbappend` |
| phosphor-hwmon 配方 | `/mnt/d/code/aspped-github/openbmc/meta-phosphor/recipes-phosphor/sensors/phosphor-hwmon_git.bb` |