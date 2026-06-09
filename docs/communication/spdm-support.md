# SPDM (Security Protocols and Data Models) 支持

## 1. SPDM 概述

SPDM 是 DMTF 定义的用于在管理控制器和被管理设备之间进行安全通信的协议，包括设备认证、密钥协商等功能。

**源码位置：** `/meta-aspeed-sdk/recipes-phosphor/spdm/`

## 2. 实现架构

AST2700 使用 NVIDIA 开发的 SPDM 实现：

```
+------------------+
|   SPDM Tool      |
+------------------+
        |
   +----+----+
   |         |
+--------+ +--------+
| SPDMd  | | SPDM   |
| Daemon | | Client |
+--------+ +--------+
        |
+------------------+
|   libmctp        |
+------------------+
        |
   +----+----+
   | PCIe | SMBus |
   +------+-------+
```

## 3. 构建配置

### 3.1 Recipe 文件

**spdmtool_git.bb：**

```bitbake
HOMEPAGE = "https://gitlab-master.nvidia.com/dgx/bmc/spdm"
LICENSE = "Apache-2.0"

SRC_URI = "git://github.com/NVIDIA/spdm;protocol=https;branch=develop"
SRCREV = "66eea8d55a418801673ea107b858abe9bb1a0efe"
```

### 3.2 构建选项

**spdm.inc：**

```bitbake
DEPENDS += "systemd"
DEPENDS += "sdeventplus"
DEPENDS += "phosphor-dbus-interfaces"
DEPENDS += "nlohmann-json"
DEPENDS += "cli11"
DEPENDS += "mbedtls"

EXTRA_OEMESON = " \
    -Dspdmd=disabled \         # 不构建守护进程
    -Dsystemd=disabled \       # 不使用 systemd
    -Dtests=disabled \         # 不构建测试
    -Dfetch_serialnumber_from_responder=26 \
    -Dcsm_service_enabled=disabled \
    -Denable-in-kernel-mctp=enabled \
    "
```

### 3.3 依赖项

| 依赖 | 用途 |
|------|------|
| mbedtls | TLS/加密支持 |
| nlohmann-json | JSON 配置解析 |
| cli11 | 命令行参数解析 |
| sdeventplus | sd-event 封装 |
| phosphor-dbus-interfaces | D-Bus 接口定义 |

## 4. MCTP 集成

### 4.1 Tag 定义

NVIDIA 的 libmctp-externals.h 定义了 SPDM 专用的 Tag 值：

```c
typedef enum {
    MCTP_TAG_PLDM = 0,    // PLDM 协议
    MCTP_TAG_SPDM = 1,    // SPDM 协议 (用于 SPDM 消息)
    MCTP_TAG_VDM = 2,     // 供应商定义消息
    MCTP_TAG_NSM = 3,     // NSM 协议
    MCTP_TAG_NSM_ASYNC = 4,
    MCTP_TAG_NVME = 5,    // NVMe 协议
    MCTP_TAG_NCSI = 6     // NCSI 协议
} mctp_tag_t;

#define LIBMCTP_TAG_OWNER_MASK 0x08
#define LIBMCTP_TAG_MASK       0x07
```

### 4.2 Tag Owner 设置

```c
// SPDM 请求消息使用 MCTP_TAG_SPDM
uint8_t tag = MCTP_TAG_SPDM | MCTP_HDR_FLAG_TO;  // Tag=1, TO=1

// 发送 SPDM 消息
ret = mctp_message_tx(mctp, dst_eid, spdm_msg, len, true, tag, params);
```

### 4.3 内核 MCTP 支持

启用内核级 MCTP 处理：

```bitbake
-Denable-in-kernel-mctp=enabled
```

## 5. MCTP 与 SPDM 消息流

```
+------+     SPDM Request      +------+
|      | --------------------> |      |
| Host |    (MCTP_TAG_SPDM)   |  SPDM |
| BMC  | <-------------------- |Device|
|      |     SPDM Response     |      |
+------+                       +------+
```

**消息序列：**

1. 主机发送 SPDM 请求 (Message Type 由 SPDM 定义)
2. 请求通过 MCTP 传输层发送
3. 目标设备处理请求并返回响应
4. 主机接收响应并验证

## 6. 消息格式

### 6.1 SPDM 消息类型

SPDM 消息通过 MCTP 的 vendor-defined 区域传输：

- **Message Type**: 由 SPDM 规范定义
- **Request Code**: 操作码
- **Response**: 对应响应

### 6.2 MCTP 传输开销

```c
// MCTP 头部
struct mctp_ctrl_msg_hdr {
    uint8_t ic_msg_type;      // SPDM 消息类型
    uint8_t rq_dgram_inst;    // RQ(1) + TO(1) + D(1) + Instance(5)
};
```

## 7. 设备发现和配置

### 7.1 序列号获取

```bitbake
-Dfetch_serialnumber_from_responder=26
```

配置从响应设备获取序列号，长度为 26 字节。

### 7.2 设备标识

通过 EID 和 PCIe BDF/SMBus 地址标识目标设备：

**PCIe:**
```bash
# 获取设备 BDF
mctp-astpcie-test -g
# 输出: src_bus=X, src_dev=Y, src_func=Z
```

**SMBus:**
```bash
# 设备地址格式
dst_addr=0x28  # 7-bit I2C 地址
```

## 8. 安全特性

### 8.1 加密支持

使用 mbedtls 提供加密功能：

- **证书验证**: X.509 证书链验证
- **密钥协商**: 基于 ECDHE 的密钥交换
- **会话加密**: 加密的 SPDM 会话

### 8.2 认证流程

1. **GET_VERSION**: 获取 SPDM 版本
2. **GET_CAPABILITIES**: 获取设备能力
3. **NEGOTIATE_ALGORITHMS**: 协商算法
4. **GET_DIGESTS**: 获取摘要
5. **GET_CERTIFICATE**: 获取证书
6. **CHALLENGE**: 质询响应认证

## 9. 与 libmctp-intel 的关系

### 9.1 库依赖

```
spdmtool
    |
    +-- libspdmcpp (NVIDIA SPDM 库)
    |       |
    |       +-- mbedtls
    |
    +-- libmctp (Intel libmctp)
            |
            +-- mctp-astpcie (PCIe 绑定)
            +-- mctp-smbus (SMBus 绑定)
```

### 9.2 集成头文件

NVIDIA 提供兼容性头文件用于整合 Intel 的 libmctp：

```c
// libmctp-externals.h
/*
 * SPDX-FileCopyrightText: Copyright (c) NVIDIA CORPORATION & AFFILIATES
 * SPDX-License-Identifier: Apache-2.0
 */
#ifndef _LIBMCTP_EXTERNALS_H
#define _LIBMCTP_EXTERNALS_H

typedef enum {
    MCTP_TAG_PLDM = 0,
    MCTP_TAG_SPDM = 1,
    MCTP_TAG_VDM = 2,
    MCTP_TAG_NSM = 3,
    MCTP_TAG_NSM_ASYNC = 4,
    MCTP_TAG_NVME = 5,
    MCTP_TAG_NCSI = 6
} mctp_tag_t;

#define LIBMCTP_TAG_OWNER_MASK 0x08
#define LIBMCTP_TAG_MASK       0x07

#endif
```

该文件被复制到构建目录：

```bitbake
do_configure:prepend() {
    cp ${UNPACKDIR}/libmctp-externals.h ${S}/libspdmcpp/headers_public/
}
```

## 10. 使用场景

### 10.1 设备认证

通过 SPDM 认证可以验证设备真伪：

```bash
# 认证设备
spdmtool authenticate <device_path>
```

### 10.2 密钥协商

建立加密会话：

```bash
# 协商会话密钥
spdmtool key_exchange <device_path>
```

### 10.3 配置更新

安全地更新固件：

```bash
# 安全更新
spdmtool update <device_path> --firmware <fw_file>
```

## 11. 限制和注意事项

### 11.1 已禁用功能

- spdmd 守护进程：未启用
- systemd 集成：未启用
- 单元测试：未启用

### 11.2 已知限制

- 不支持 CSM 服务 (Dell Common Services)
- 序列号长度固定为 26 字节
- 依赖内核 MCTP 支持

## 12. 参考资源

- DMTF DSP0277: Security Protocol and Data Model (SPDM) Specification
- DMTF DSP0236: Management Component Transport Protocol (MCTP) Specification
- NVIDIA SPDM: https://github.com/NVIDIA/spdm
- Intel libmctp: https://github.com/Intel-BMC/libmctp