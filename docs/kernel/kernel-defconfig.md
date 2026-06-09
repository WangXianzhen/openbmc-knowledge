# AST2700 Kernel defconfig 详细分析

## 1. 配置文件位置

### 1.1 主要 defconfig 文件

| 文件路径 | 对应芯片 | 说明 |
|----------|----------|------|
| `meta-aspeed/recipes-kernel/linux/linux-aspeed/aspeed-g4/defconfig` | AST2400 | 第一代 |
| `meta-aspeed/recipes-kernel/linux/linux-aspeed/aspeed-g5/defconfig` | AST2500 | 第二代 |
| `meta-aspeed/recipes-kernel/linux/linux-aspeed/aspeed-g6/defconfig` | AST2600 | 第三代 |
| `meta-aspeed/recipes-kernel/linux/linux-aspeed/aspeed-g7/defconfig` | AST2700 | 第四代 (当前) |
| `meta-aspeed/recipes-kernel/linux/linux-aspeed/defconfig` | 通用 | 基础配置 |

### 1.2 Machine 配置引用

在 `ast2700-default.conf` 和相关配置中:

```bitbake
KBUILD_DEFCONFIG = "aspeed_g7_defconfig"
```

## 2. aspeed_g7_defconfig 详细分析

### 2.1 架构配置 (Architecture)

```bash
# 基础架构支持
CONFIG_ARCH_ASPEED=y
CONFIG_MACH_ASPEED_G7=y

# 缓存配置 - AST2700 使用系统级缓存 (SLC)
# CONFIG_CACHE_L2X0 is not set

# 多核配置
CONFIG_SMP=y
CONFIG_NR_CPUS=2

# ARM CPU 拓扑 - 未启用
# CONFIG_ARM_CPU_TOPOLOGY is not set

# 虚拟地址分割 - 2G/2G
CONFIG_VMSPLIT_2G=y

# 高内存支持
CONFIG_HIGHMEM=y

# 用户空间访问优化
CONFIG_UACCESS_WITH_MEMCPY=y

# 废弃标签格式 - 未启用
# CONFIG_ATAGS is not set
```

### 2.2 引导选项

```bash
# Kexec 支持
CONFIG_KEXEC=y

# VFP/NEON 矢量浮点支持
CONFIG_VFP=y
CONFIG_NEON=y
CONFIG_KERNEL_MODE_NEON=y
```

### 2.3 内核特性

```bash
# 压缩格式 - XZ
CONFIG_KERNEL_XZ=y

# 交换 - 未启用
# CONFIG_SWAP is not set

# 高分辨率定时器
CONFIG_HIGH_RES_TIMERS=y

# BPF 系统调用
CONFIG_BPF_SYSCALL=y

# PSI 压力停滞信息
CONFIG_PSI=y
CONFIG_PSI_DEFAULT_DISABLED=y

# 内核配置导出
CONFIG_IKCONFIG=y
CONFIG_IKCONFIG_PROC=y

# 日志缓冲
CONFIG_LOG_BUF_SHIFT=16

# Cgroups 和 namespaces
CONFIG_CGROUPS=y
CONFIG_CGROUP_BPF=y
CONFIG_NAMESPACES=y
CONFIG_USER_NS=y

# Initrd 支持
CONFIG_BLK_DEV_INITRD=y

# 压缩算法 (仅 XZ)
# CONFIG_RD_GZIP is not set
# CONFIG_RD_BZIP2 is not set
# CONFIG_RD_LZMA is not set
# CONFIG_RD_LZO is not set
# CONFIG_RD_LZ4 is not set

# 专家模式
CONFIG_EXPERT=y

# 性能事件
CONFIG_PERF_EVENTS=y

# 堆栈保护
CONFIG_SLAB_FREELIST_RANDOM=y
CONFIG_SLAB_FREELIST_HARDENED=y
```

### 2.4 网络配置

```bash
# 基础网络
CONFIG_NET=y
CONFIG_PACKET=y
CONFIG_PACKET_DIAG=y
CONFIG_UNIX=y
CONFIG_UNIX_DIAG=y
CONFIG_INET=y

# IP 多播和高级路由
CONFIG_IP_MULTICAST=y
CONFIG_IP_ADVANCED_ROUTER=y
CONFIG_IP_MULTIPLE_TABLES=y
CONFIG_IP_ROUTE_MULTIPATH=y
CONFIG_IP_ROUTE_VERBOSE=y
CONFIG_SYN_COOKIES=y

# IPv6 支持
CONFIG_IPV6_ROUTER_PREF=y
CONFIG_IPV6_ROUTE_INFO=y
CONFIG_IPV6_OPTIMISTIC_DAD=y
# CONFIG_IPV6_SIT is not set
CONFIG_IPV6_MULTIPLE_TABLES=y

# Netfilter
CONFIG_NETFILTER=y
# CONFIG_NETFILTER_ADVANCED is not set

# VLAN
CONFIG_VLAN_8021Q=y

# NCSI 网络接口
CONFIG_NET_NCSI=y

# 无线 - 未启用
# CONFIG_WIRELESS is not set
```

### 2.5 块设备和存储

```bash
# MTD 闪存设备
CONFIG_MTD=y
CONFIG_MTD_BLOCK=y
CONFIG_MTD_PARTITIONED_MASTER=y
CONFIG_MTD_SPI_NOR=y
# CONFIG_MTD_SPI_NOR_USE_4K_SECTORS is not set

# Aspeed SMC 控制器
CONFIG_SPI_ASPEED_SMC=y

# 块设备
CONFIG_BLK_DEV_LOOP=y
CONFIG_BLK_DEV_NBD=y

# SCSI 和 MD
CONFIG_SCSI=y
CONFIG_BLK_DEV_SD=y
CONFIG_MD=y
CONFIG_BLK_DEV_DM=y
CONFIG_DM_VERITY=y

# 文件系统
CONFIG_EXT4_FS=y
CONFIG_OVERLAY_FS=y
CONFIG_VFAT_FS=y
CONFIG_TMPFS=y
CONFIG_JFFS2_FS=y
# CONFIG_JFFS2_FS_WRITEBUFFER is not set
CONFIG_JFFS2_SUMMARY=y
CONFIG_JFFS2_FS_XATTR=y
CONFIG_SQUASHFS=y
CONFIG_SQUASHFS_XZ=y
CONFIG_SQUASHFS_ZSTD=y
CONFIG_FANOTIFY=y
# CONFIG_NETWORK_FILESYSTEMS is not set
CONFIG_NLS_CODEPAGE_437=y
CONFIG_NLS_ISO8859_1=y
```

### 2.6 IPMI 和 KCS

```bash
# Aspeed KCS IPMI BMC 驱动
CONFIG_ASPEED_KCS_IPMI_BMC=y
CONFIG_IPMI_KCS_BMC_CDEV_IPMI=y
CONFIG_IPMI_KCS_BMC_SERIO=y

# Aspeed BT IPMI BMC
CONFIG_ASPEED_BT_IPMI_BMC=y
```

### 2.7 I2C 和 GPIO

```bash
# I2C 配置
# CONFIG_I2C_COMPAT is not set
CONFIG_I2C_CHARDEV=y
CONFIG_I2C_MUX_GPIO=y
CONFIG_I2C_MUX_PCA9541=y
CONFIG_I2C_MUX_PCA954x=y
CONFIG_I2C_ASPEED=y
CONFIG_I2C_SLAVE=y

# SPI 支持
CONFIG_SPI=y

# GPIO
CONFIG_GPIOLIB=y
CONFIG_GPIO_SYSFS=y
CONFIG_GPIO_ASPEED=y
CONFIG_GPIO_PCA953X=y
CONFIG_GPIO_PCA953X_IRQ=y

# 1-Wire
CONFIG_W1=y
CONFIG_W1_MASTER_GPIO=y
CONFIG_W1_SLAVE_THERM=y
```

### 2.8 串口控制台

```bash
# 8250 串口
CONFIG_SERIAL_8250=y
# CONFIG_SERIAL_8250_DEPRECATED_OPTIONS is not set
CONFIG_SERIAL_8250_CONSOLE=y
CONFIG_SERIAL_8250_NR_UARTS=6
CONFIG_SERIAL_8250_RUNTIME_UARTS=6
CONFIG_SERIAL_8250_EXTENDED=y
CONFIG_SERIAL_8250_ASPEED_VUART=y
CONFIG_SERIAL_8250_SHARE_IRQ=y
CONFIG_SERIAL_8250_DW=y
CONFIG_SERIAL_OF_PLATFORM=y
```

### 2.9 传感器驱动

```bash
# Aspeed 传感器
CONFIG_SENSORS_ASPEED=y
CONFIG_SENSORS_IIO_HWMON=y

# 通用传感器
CONFIG_SENSORS_LM75=y
CONFIG_SENSORS_NCT7904=y
CONFIG_SENSORS_TMP421=y
CONFIG_SENSORS_W83773G=y

# OCC 传感器
CONFIG_SENSORS_OCC_P8_I2C=y
CONFIG_SENSORS_OCC_P9_SBE=y

# PMBus 支持
CONFIG_PMBUS=y
CONFIG_SENSORS_ADM1275=y
CONFIG_SENSORS_IBM_CFFPS=y
CONFIG_SENSORS_IR35221=y
CONFIG_SENSORS_IR38064=y
CONFIG_SENSORS_ISL68137=y
CONFIG_SENSORS_LM25066=y
CONFIG_SENSORS_MAX31785=y
CONFIG_SENSORS_UCD9000=y
CONFIG_SENSORS_UCD9200=y
```

### 2.10 视频和显示

```bash
# Video4Linux
CONFIG_MEDIA_SUPPORT=y
CONFIG_MEDIA_SUPPORT_FILTER=y
CONFIG_MEDIA_PLATFORM_SUPPORT=y
CONFIG_V4L_PLATFORM_DRIVERS=y
CONFIG_VIDEO_ASPEED=y

# DRM 显示
CONFIG_DRM=y
CONFIG_DRM_ASPEED_GFX=y
```

### 2.11 USB 支持

```bash
# USB 核心
CONFIG_USB=y
CONFIG_USB_ANNOUNCE_NEW_DEVICES=y
CONFIG_USB_DYNAMIC_MINORS=y
CONFIG_USB_EHCI_HCD=y
CONFIG_USB_EHCI_ROOT_HUB_TT=y
CONFIG_USB_EHCI_HCD_PLATFORM=y
CONFIG_USB_STORAGE=y

# USB Gadget
CONFIG_USB_GADGET=y
CONFIG_USB_ASPEED_VHUB=y
CONFIG_USB_CONFIGFS=y
CONFIG_USB_CONFIGFS_MASS_STORAGE=y
CONFIG_USB_CONFIGFS_F_HID=y
```

### 2.12 MMC/SD 支持

```bash
CONFIG_MMC=y
CONFIG_MMC_SDHCI=y
CONFIG_MMC_SDHCI_PLTFM=y
CONFIG_MMC_SDHCI_OF_ASPEED=y
```

### 2.13 LED 和输入设备

```bash
# LED 支持
CONFIG_NEW_LEDS=y
CONFIG_LEDS_CLASS=y
CONFIG_LEDS_CLASS_FLASH=y
CONFIG_LEDS_GPIO=y
CONFIG_LEDS_PCA955X=y
CONFIG_LEDS_PCA955X_GPIO=y
CONFIG_LEDS_TRIGGERS=y
CONFIG_LEDS_TRIGGER_TIMER=y
CONFIG_LEDS_TRIGGER_HEARTBEAT=y
CONFIG_LEDS_TRIGGER_DEFAULT_ON=y

# 输入设备
CONFIG_INPUT_EVDEV=y
# CONFIG_KEYBOARD_ATKBD is not set
CONFIG_KEYBOARD_GPIO=y
CONFIG_KEYBOARD_GPIO_POLLED=y
# CONFIG_INPUT_MOUSE is not set
CONFIG_INPUT_MISC=y
CONFIG_INPUT_IBM_PANEL=y
CONFIG_SERIO_RAW=y
```

### 2.14 RTC 和看门狗

```bash
# RTC
CONFIG_RTC_CLASS=y
CONFIG_RTC_DRV_DS1307=y
CONFIG_RTC_DRV_PCF8523=y
CONFIG_RTC_DRV_RV8803=y
CONFIG_RTC_DRV_ASPEED=y

# 看门狗
CONFIG_WATCHDOG_SYSFS=y
```

### 2.15 加密和安全

```bash
# 加密算法
CONFIG_CRYPTO_HMAC=y
CONFIG_CRYPTO_SHA256=y
CONFIG_CRYPTO_USER_API_HASH=y
# CONFIG_CRYPTO_HW is not set

# 内存安全
CONFIG_HARDENED_USERCOPY=y
CONFIG_FORTIFY_SOURCE=y
```

### 2.16 调试选项

```bash
# 调试信息
CONFIG_DEBUG_INFO=y
CONFIG_DEBUG_INFO_REDUCED=y
CONFIG_DEBUG_INFO_DWARF4=y
CONFIG_GDB_SCRIPTS=y
CONFIG_STRIP_ASM_SYMS=y
CONFIG_DEBUG_FS=y

# 内存检查
CONFIG_DEBUG_WX=y
CONFIG_SCHED_STACK_END_CHECK=y

# Panic 和 Watchdog
CONFIG_PANIC_ON_OOPS=y
CONFIG_PANIC_TIMEOUT=-1
CONFIG_SOFTLOCKUP_DETECTOR=y
CONFIG_BOOTPARAM_SOFTLOCKUP_PANIC=y
CONFIG_BOOTPARAM_HUNG_TASK_PANIC=y
CONFIG_WQ_WATCHDOG=y

# 函数追踪
CONFIG_FUNCTION_TRACER=y
CONFIG_DEBUG_USER=y

# 内核日志
CONFIG_PRINTK_TIME=y
CONFIG_DYNAMIC_DEBUG=y
```

### 2.17 其他硬件支持

```bash
# 随机数生成器
CONFIG_HW_RANDOM_TIMERIOMEM=y

# 内存设备
CONFIG_EEPROM_AT24=y
CONFIG_EEPROM_AT25=y

# EDAC 错误检测
CONFIG_EDAC=y
CONFIG_EDAC_ASPEED=y

# Aspeed XDMA
CONFIG_ASPEED_XDMA=y

# ADC 支持
CONFIG_IIO=y
CONFIG_ASPEED_ADC=y
CONFIG_MAX1363=y
CONFIG_BMP280=y
CONFIG_DPS310=y

# 可靠性
CONFIG_RAS=y
```

### 2.18 以太网驱动

```bash
# FTMGAC100 以太网控制器
CONFIG_FTGMAC100=y

# PHY 驱动
CONFIG_BROADCOM_PHY=y
CONFIG_REALTEK_PHY=y

# 禁用未使用的网络厂商驱动
# CONFIG_NET_VENDOR_* is not set (多个)
```

## 3. 配置文件对比

### 3.1 各代芯片 defconfig 差异

| 功能 | G4 (AST2400) | G5 (AST2500) | G6 (AST2600) | G7 (AST2700) |
|------|--------------|--------------|--------------|--------------|
| 架构 | ARMv7 | ARMv7 | ARMv8 | ARMv8 |
| 多核 | 否 | 可选 | 是 | 是 (2核) |
| 压缩 | gzip | gzip | gzip/xz | xz |
| DRM | 否 | 否 | 是 | 是 |

### 3.2 AST2700 特有配置

```bash
# AST2700 专有
CONFIG_ARCH_ASPEED=y
CONFIG_MACH_ASPEED_G7=y
CONFIG_ARM_VIRT_EXTENSION=y
CONFIG_NEON=y
CONFIG_KERNEL_MODE_NEON=y
```

## 4. 配置管理

### 4.1 配置文件优先级

```
1. Machine 特定 defconfig (KBUILD_DEFCONFIG)
2. Kernel fragment configs (*.cfg)
3. 内核默认配置
```

### 4.2 配置修改工作流

```bash
# 1. 打开配置界面
bitbake linux-aspeed -c menuconfig

# 2. 保存配置到 local.conf
bitbake linux-aspeed -c diffconfig > meta-aspeed-sdk/recipes-kernel/linux/linux-aspeed/my-config.cfg

# 3. 在配方中添加
# SRC_URI:append = " file://my-config.cfg "
```

## 5. 编译输出

### 5.1 内核镜像位置

```
build/<machine>/tmp/work/<machine>-openbmc-linux/linux-aspeed/<version>/image/
├── boot/
│   ├── zImage              # ARM 内核镜像
│   ├── Image               # ARM64 内核镜像
│   └── aspeed-<board>.dtb  # 设备树二进制
├── lib/modules/
│   └── <version>/
│       └── kernel/         # 内核模块
```

### 5.2 设备树文件

| 文件名 | 说明 |
|--------|------|
| `aspeed-ast2700-evb.dtb` | AST2700 A2 EVB 板 |
| `aspeed-ast2700a1-evb.dtb` | AST2700 A1 EVB 板 |
| `aspeed-ast2700-irot.dtb` | iROT 变体 |

## 6. 快速参考

### 6.1 查看当前配置

```bash
# 方法1: 使用 BitBake
bitbake linux-aspeed -c diffconfig

# 方法2: 直接查看 .config
cat tmp/work/<machine>-*/linux-aspeed-*/.config | grep CONFIG_*

# 方法3: 搜索特定配置
bitbake linux-aspeed -c diffconfig | grep CONFIG_XXX
```

### 6.2 添加新驱动

```bash
# 1. 创建配置片段 my-driver.cfg
CONFIG_MY_DRIVER=m
CONFIG_MY_DRIVER_PHY=y

# 2. 添加到配方
# linux-aspeed_6.18.bb:
SRC_URI:append = " file://my-driver.cfg "

# 3. 重新编译
bitbake linux-aspeed -c compile
```