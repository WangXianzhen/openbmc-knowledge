# AST2700 图形配置说明

## 机器配置

### 主要配置文件

| 文件 | 位置 | 说明 |
|------|------|------|
| `ast2700-default.conf` | `meta-ast2700-sdk/conf/machine/` | AST2700 A2 默认配置 |
| `ast2700-a1.conf` | `meta-ast2700-sdk/conf/machine/` | AST2700 A1 配置 |
| `ast2700-612.conf` | `meta-ast2700-sdk/conf/machine/` | 6.12 内核配置 |
| `ast2700-66.conf` | `meta-ast2700-sdk/conf/machine/` | 6.6 内核配置 |

### 关键 Include 文件

| 文件 | 说明 |
|------|------|
| `ast2700-sdk.inc` | AST2700 SDK 主配置 |
| `ast2700-a1.inc` | AST2700 A1 特定配置 |
| `obmc-bsp-common.inc` | OpenBMC BSP 通用配置 |

### 闪存布局 (ast2700-default.conf)

```
FLASH_SIZE = "131072" (128MB)
+------------------------+----------------+
| 组件                   | 偏移           |
+------------------------+----------------+
| U-Boot                 | 0x000000       |
| U-Boot Env             | 0x001000       |
| Kernel                 | 0x001800 (15MB)|
| ROFS                   | 0x4C8000 (77MB)|
| RWFS                   | 0x1800000      |
+------------------------+----------------+
```

## obmc-ikvm 服务配置

### 服务启动参数

```ini
[Unit]
Description=OpenBMC ipKVM daemon
ConditionPathIsMountPoint=/sys/kernel/config
After=obmc-ikvm.service

[Service]
Restart=always
ExecStartPre=/usr/bin/create_usbhid.sh disconnect 1
ExecStart=/usr/bin/obmc-ikvm -v /dev/video1 -k /dev/hidg2 -p /dev/hidg3

[Install]
WantedBy=multi-user.target
```

### 启动参数说明

| 参数 | 设备 | 说明 |
|------|------|------|
| `-v /dev/video1` | V4L2 视频设备 | KVM 视频捕获 |
| `-k /dev/hidg2` | HID Gadget | 键盘设备节点 |
| `-p /dev/hidg3` | HID Gadget | 鼠标设备节点 |

### AST2700/AST2750 USB 设备映射

```bash
# AST2700 (A2)
hid_conf_directory="/sys/kernel/config/usb_gadget/obmc_hid"
DEV_NAME="12060000.usb-vhub"

# AST2750 A1 (双节点 Node1)
hid_conf_directory="/sys/kernel/config/usb_gadget/obmc_hid1"
DEV_NAME="12021000.usb-vhub"

# AST2750 A2 (双节点 Node1)
hid_conf_directory="/sys/kernel/config/usb_gadget/obmc_hid1"
DEV_NAME="12062000.usb-vhub"
```

## USB HID Gadget 配置

### create_usbhid.sh 脚本

**位置**: `meta-aspeed-sdk/meta-ast2700-sdk/recipes-graphics/obmc-ikvm/obmc-ikvm/create_usbhid.sh`

**功能**: 动态创建 USB HID Gadget 设备

**使用方法**:
```bash
# 断开 HID 设备
/usr/bin/create_usbhid.sh disconnect [node]

# 连接 HID 设备
/usr/bin/create_usbhid.sh connect [node]
```

### HID 描述符

**键盘报告描述符**: 8 字节报告
- 1 字节修饰键 (Ctrl, Shift, Alt, etc.)
- 1 字节保留
- 6 字节 HID 扫描码

**鼠标报告描述符**: 6 字节报告
- 3 字节按钮状态 + X/Y 坐标 (绝对坐标)
- 1 字节滚轮

## Framebuffer 配置

### fbterm 配置

**环境文件**: `fbterm`

**模式文件**: `/etc/fb.modes`

**相关配方**:
- `meta-phosphor/recipes-phosphor/video/fbterm_git.bb`
- `meta-phosphor/recipes-phosphor/video/uart-render-controller_git.bb`

### 依赖关系

```
fbterm
  ├── freetype
  └── fontconfig

uart-render-controller
  └── fbterm
```

## 内核配置 (DRM/显示驱动)

### 相关的内核配置选项

```bash
# DRM 显示驱动
CONFIG_DRM_ASPEED=y
CONFIG_DRM_AST=y

# V4L2 视频捕获
CONFIG_VIDEO_V4L2=y
CONFIG_VIDEO_ASPEED=y

# Framebuffer
CONFIG_FB=y
CONFIG_FB_MODE_HELPERS=y
```

### 设备树节点

**V4L2 视频设备**:
```dt
&vhub0 {
    status = "okay";
};
```

**显示输出**: AST2700 集成显示引擎，支持 HDMI/DP 输出

## Web UI 配置

### webui-vue 配方

**位置**: `meta-phosphor/recipes-phosphor/webui/webui-vue_git.bb`

**构建依赖**:
- nodejs-native

**运行时依赖**:
- bmcweb

**部署路径**: `/usr/share/www/`

### 构建配置

```bash
# NPM 缓存配置
NPM_CONFIG_CACHE ?= "${WORKDIR}/npm-cache"

# 编译命令
npm install
npm run build
```

## 配方构建顺序

```
1. obmc-ikvm
   └── libvncserver
   └── sdbusplus
   └── phosphor-logging

2. fbterm
   └── freetype
   └── fontconfig

3. uart-render-controller
   └── fbterm

4. webui-vue
   └── nodejs-native
   └── bmcweb (runtime)
```

## 调试命令

### 检查视频设备
```bash
# 列出 V4L2 设备
v4l2-ctl --list-devices

# 查看视频格式
v4l2-ctl -d /dev/video1 --all

# 测试视频捕获
v4l2-ctl -d /dev/video1 --set-fmt-video=width=1920,height=1080,pixelformat=MJPG
```

### 检查 USB Gadget
```bash
# 列出 USB Gadget
ls -la /sys/kernel/config/usb_gadget/

# 查看当前 UDC
cat /sys/kernel/config/usb_gadget/obmc_hid/UDC
```

### 检查 Framebuffer
```bash
# 列出 Framebuffer 设备
ls -la /dev/fb*

# 查看 Framebuffer 信息
cat /proc/fb
```

### 检查服务状态
```bash
# 查看 obmc-ikvm 服务状态
systemctl status obmc-ikvm

# 查看日志
journalctl -u obmc-ikvm -f
```

## 常见问题

### 1. VNC 连接无视频

检查视频设备节点是否存在:
```bash
ls -la /dev/video*
```

### 2. 键盘/鼠标无响应

检查 USB Gadget 状态:
```bash
ls -la /sys/kernel/config/usb_gadget/
cat /sys/kernel/config/usb_gadget/obmc_hid/UDC
```

### 3. 视频卡顿

检查系统负载和内存:
```bash
free -h
top
```