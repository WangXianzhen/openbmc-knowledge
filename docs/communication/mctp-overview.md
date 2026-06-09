# MCTP (Management Component Transport Protocol) 协议概述

## 1. 协议简介

MCTP 是 DMTF (Distributed Management Task Force) 定义的开放式通信协议 (DSP0236)，用于在系统管理控制器 (如 BMC) 与被管理组件之间传输管理消息。

**核心特性：**
- 传输介质无关：支持 PCIe、SMBus/I2C、I3C 等多种物理层
- 消息类型可扩展：支持控制消息、Vendor Defined Messages 等
- 基于 EID (Endpoint ID) 的端点寻址
- 请求/响应模式的消息交换

## 2. AST2700 实现架构

AST2700 芯片的 MCTP 实现基于 Intel 的 libmctp 库，包含三个传输层绑定：

```
+------------------+
|  MCTP Core Stack |
+------------------+
        |
   +----+----+
   |         |
+--------+ +--------+ +--------+
| PCIe   | | SMBus  | | I3C    |
|binding | |binding | |binding |
+--------+ +--------+ +--------+
```

**源码位置：** `/meta-aspeed-sdk/recipes-phosphor/pmci/`

## 3. 消息类型

MCTP 定义了标准消息类型，AST2700 实现中支持：

| 类型值 | 名称 | 说明 |
|--------|------|------|
| 0x00 | MCTP Control Message | MCTP 标准控制消息 |
| 0x7c | ASPEED Echo Test | Aspeed 专用测试消息 |

### 3.1 控制消息结构

```c
struct mctp_ctrl_msg_hdr {
    uint8_t ic_msg_type;      // 内部消息类型
    uint8_t rq_dgram_inst;    // 请求/响应 + 数据报/消息 + 实例ID
};
```

### 3.2 ASPEED Echo 消息

Aspeed 定制的测试消息类型 (0x7c)：

```c
#define MCTP_MESSAGE_TYPE_ASPEED_ECHO_TEST 0x7c
#define MCTP_ASPEED_CTRL_CMD_ECHO 0x00       // 标准回显
#define MCTP_ASPEED_CTRL_CMD_ECHO_LARGE 0x01 // 大数据回显
```

## 4. EID (Endpoint ID) 机制

EID 是 MCTP 中用于标识端点的 8 位地址：

- **静态 EID**：由系统分配，固定不变
- **动态 EID**：由 EID 分配协议动态分配

**测试配置：**
- Requester EID: 8
- Responder EID: 9

```c
#define REQUESTER_EID 8
#define RESPONDER_EID 9
```

## 5. Tag 和 Message Tag Owner

MCTP 使用 3 位 Tag 字段配合 TO (Tag Owner) 位区分请求/响应：

```c
#define MCTP_HDR_FLAG_TO      0x08  // Tag Owner 位
#define MCTP_HDR_GET_TAG(x)   ((x) & 0x07)

// 消息方向：
// - TO=1: Requester 发送请求，Tag 由 Requester 设置
// - TO=0: Responder 返回响应，Tag 与请求保持一致
```

**NVIDIA 定义的 Tag 值：**

```c
typedef enum {
    MCTP_TAG_PLDM = 0,    // PLDM 协议
    MCTP_TAG_SPDM = 1,    // SPDM 协议
    MCTP_TAG_VDM = 2,     // Vendor Defined
    MCTP_TAG_NSM = 3,     // NSM 协议
    MCTP_TAG_NVME = 5,    // NVMe 协议
    MCTP_TAG_NCSI = 6     // NCSI 协议
} mctp_tag_t;
```

## 6. MCTP Core API

### 6.1 初始化和销毁

```c
struct mctp *mctp_init(void);
void mctp_destroy(struct mctp *mctp);
```

### 6.2 总线注册

```c
// 动态 EID 注册
int mctp_register_bus_dynamic_eid(struct mctp *mctp, struct mctp_binding *binding);

// 设置 EID
int mctp_dynamic_eid_set(struct mctp_binding *binding, uint8_t eid);
```

### 6.3 消息收发

```c
// 发送消息
int mctp_message_tx(struct mctp *mctp, uint8_t eid, void *msg, size_t len,
                    bool tag_owner, uint8_t tag, void *prv);

// 注册接收回调
void mctp_set_rx_all(mctp, rx_request_handler, ctx);   // 普通消息
void mctp_set_rx_ctrl(mctp, rx_request_control_handler, ctx); // 控制消息
```

### 6.4 绑定操作

```c
void mctp_binding_set_tx_enabled(struct mctp_binding *binding, bool enable);
```

## 7. 消息缓冲区

MCTP 标准定义最大传输单元：

```c
#define MCTP_BTU 64  // 最大单元传输大小

// 缓冲区大小配置 (测试用)
#define TEST_BUFF_SIZE 2048
#define TEST_TX_BUFF_SIZE (TEST_BUFF_SIZE + sizeof(struct mctp_ctrl_msg_hdr))
#define TEST_RX_BUFF_SIZE (TEST_BUFF_SIZE + sizeof(struct mctp_ctrl_msg_hdr) + 1)
```

## 8. 测试工具

### 8.1 测试上下文结构

```c
struct test_mctp_ctx {
    struct mctp_binding *astpcie_binding;  // PCIe 绑定
    struct mctp *mctp;                      // MCTP 核心栈
    uint16_t len;                           // 接收数据长度
    void *rx_buf;                           // 接收缓冲区
    void *port;                             // 端口句柄
};
```

### 8.2 回调函数

```c
// 普通消息请求处理
void rx_request_handler(mctp_eid_t src, void *data, void *msg, size_t len,
                        bool tag_owner, uint8_t tag, void *msg_binding_private);

// 控制消息请求处理
void rx_request_control_handler(mctp_eid_t src, void *data, void *msg, size_t len,
                                bool tag_owner, uint8_t tag, void *msg_binding_private);

// 响应处理
void rx_response_handler(uint8_t eid, void *data, void *msg, size_t len,
                         bool tag_owner, uint8_t tag, void *prv);
```

## 9. PEC (Packet Error Code) 支持

SMBus/I2C 传输支持 PEC 错误检测：

**Aspeed 扩展：**
- `append_pec`: 启用 PEC 添加/验证
- `is_target`: 区分主机/目标模式

```c
struct mctp_asti3c_pkt_private {
    int fd;
    bool append_pec;
    bool is_target;
};
```

## 10. 参考文档

- DMTF DSP0236: MCTP Specification
- DMTF DSP0237: MCTP over PCIe Transport Binding
- DMTF DSP0238: MCTP over SMBus/I2C Transport Binding