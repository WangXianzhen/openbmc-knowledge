# AST2700 图形架构分析

## 概述

AST2700 平台的图形服务主要通过 **obmc-ikvm** 实现，提供基于 VNC 的远程 KVM 功能。系统采用简化的显示架构，不使用传统的 X11/Weston 窗口管理器，而是依赖 framebuffer 和 V4L2 设备实现视频捕获与远程显示。

## 核心组件

### 1. obmc-ikvm (主要图形服务)

**描述**: OpenBMC VNC 服务器和 ipKVM 守护进程

**配方位置**: 
- 主配方: `meta-phosphor/recipes-graphics/obmc-ikvm/obmc-ikvm_git.bb`
- Aspeed 定制: `meta-aspeed-sdk/recipes-graphics/obmc-ikvm/`

**依赖项**:
- libvncserver
- systemd
- sdbusplus
- phosphor-logging
- phosphor-dbus-interfaces

**构建系统**: Meson

**服务**: `obmc-ikvm.service`

### 2. framebuffer 服务

**组件**: fbterm

**配方位置**: `meta-phosphor/recipes-phosphor/video/fbterm_git.bb`

**用途**: Framebuffer 终端，提供基于帧缓冲的文本控制台

**依赖项**:
- freetype
- fontconfig

**配置**: `/etc/fb.modes`

**服务**: `fbterm.service`

### 3. UART Render Controller

**配方位置**: `meta-phosphor/recipes-phosphor/video/uart-render-controller_git.bb`

**用途**: 通过 UART 渲染控制器管理显示输出

**依赖项**: fbterm

**服务**: `uart-render-controller.service`

### 4. Web UI

**配方**: `meta-phosphor/recipes-phosphor/webui/webui-vue_git.bb`

**用途**: 基于 Vue.js 的 Web 界面，通过 bmcweb 提供 REST API 访问

**构建**: Node.js + NPM

**部署路径**: `/usr/share/www/`

## AST2700 特定的图形配置

### USB HID Gadget 配置

AST2700 使用 USB Gadget HID 实现远程键盘鼠标功能:

```bash
# AST2700/AST2750 USB vHUB 设备路径
AST2700:   /sys/bus/platform/devices/12060000.usb-vhub
AST2750 A1: /sys/bus/platform/devices/12021000.usb-vhub
AST2750 A2: /sys/bus/platform/devices/12062000.usb-vhub
```

### 视频设备

```
/dev/video1  # V4L2 视频捕获设备 (KVM 主视频流)
/dev/hidg2   # HID gadget 键盘设备
/dev/hidg3   # HID gadget 鼠标设备
```

### 补丁文件 (meta-aspeed-sdk)

| 补丁文件 | 功能 |
|---------|------|
| `0001-Add-control-for-aspeed-format.patch` | 添加 Aspeed 格式控制 |
| `0002-Avoid-frame-drop.patch` | 避免帧丢失 |
| `0003-Add-support-of-partial-jpeg.patch` | 支持部分 JPEG |
| `0004-Improve-video-quality.patch` | 改进视频质量 |
| `0004-obmc-ikvm-support-ast2750-A2-dual-nodes.patch` | AST2750 A2 双节点支持 |
| `0005-obmc-ikvm-support-ast2700-A1.patch` | AST2700 A1 支持 |

## 显示架构流程

```
+----------------+     +------------------+     +------------------+
|  主机视频源     | --> |  V4L2 捕获设备    | --> |  obmc-ikvm       |
| (BMC 视频输入)  |     |  (/dev/video1)   |     |  (JPEG 压缩)     |
+----------------+     +------------------+     +--------+---------+
                                                        |
                                                        v
+----------------+     +------------------+     +------------------+
|  USB HID       | <-- |  HID Gadget      | <-- |  VNC 客户端      |
|  (键盘/鼠标)    |     |  (/dev/hidg2/3)  |     |  (远程浏览器)    |
+----------------+     +------------------+     +------------------+
```

## 与 X11/Weston 的对比

| 特性 | OpenBMC (AST2700) | 传统桌面 |
|------|------------------|----------|
| 窗口管理器 | 无 (无 GUI 桌面) | X11/Weston |
| 显示服务 | Framebuffer + V4L2 | DRM/KMS |
| 远程访问 | VNC/RFB 协议 | VNC/X11 forwarding |
| 用途 | BMC 管理界面 | 通用桌面 |

## 安全考虑

1. **USB Gadget HID**: 通过 USB Composite Gadget 提供虚拟键盘鼠标
2. **VNC 服务**: 基于 libvncserver 实现
3. **Web UI**: 通过 bmcweb 的 REST API 访问

## 启动流程

```
1. systemd 启动 obmc-ikvm.service
2. 创建 USB HID Gadget (create_usbhid.sh)
3. 初始化 V4L2 视频捕获
4. 启动 VNC 服务器监听连接
```

## 相关文件路径

| 路径 | 说明 |
|------|------|
| `/usr/bin/obmc-ikvm` | KVM 主程序 |
| `/usr/bin/create_usbhid.sh` | USB HID 配置脚本 |
| `/etc/fb.modes` | Framebuffer 模式配置 |
| `/usr/share/www/` | Web UI 文件 |
| `/etc/systemd/system/obmc-ikvm.service` | KVM 服务单元 |