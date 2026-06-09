# MCTP 传输层实现

## 1. PCIe 传输绑定 (mctp-astpcie)

### 1.1 概述

AST2700 通过 PCIe 实现 MCTP 传输，适用于高速、高带宽的管理通信场景。

**源码：** `libmctp-intel-test/mctp-astpcie-test.c`

### 1.2 关键结构

```c
struct mctp_binding_astpcie {
    struct mctp_binding binding;  // 基类
    uint16_t bdf;                 // Bus:Device:Function
    uint8_t medium_id;            // 介质ID
    int fd;                       // 文件描述符
};

struct mctp_astpcie_pkt_private {
    uint8_t routing;              // 路由类型
    uint16_t remote_id;           // 远程设备 ID
};
```

### 1.3 PCIe 路由类型

MCTP over PCIe 支持三种路由方式：

| 值 | 名称 | 说明 |
|----|------|------|
| 0 | PCIE_ROUTE_TO_RC | 路由到 Root Complex |
| 2 | PCIE_ROUTE_BY_ID | 按 ID 直接路由 |
| 3 | PCIE_BROADCAST_FROM_RC | 从 Root Complex 广播 |

```c
#define PCIE_ROUTE_TO_RC     0
#define PCIE_ROUTE_BY_ID     2
#define PCIE_BROADCAST_FROM_RC 3
```

### 1.4 设备初始化

```c
struct test_mctp_ctx *test_mctp_astpcie_init(
    char *mctp_dev,       // 设备节点 (如 /dev/aspeed-mctp)
    uint8_t bus,          // 目标总线号
    uint8_t routing,      // 路由类型
    uint8_t dst_dev,      // 目标设备号
    uint8_t dst_func,     // 目标功能号
    uint8_t dst_eid,      // 目标 EID
    uint8_t src_eid       // 源 EID
);
```

**初始化流程：**

```c
// 1. 初始化 MCTP 核心栈
mctp = mctp_init();

// 2. 初始化 PCIe 绑定
astpcie = mctp_astpcie_init();

// 3. 设置设备名称
mctp_astpcie_mctp_dev_name(astpcie, mctp_dev);

// 4. 获取核心绑定
astpcie_binding = mctp_astpcie_core(astpcie);

// 5. 注册总线 (动态 EID)
mctp_register_bus_dynamic_eid(mctp, astpcie_binding);

// 6. 设置源 EID
mctp_dynamic_eid_set(astpcie_binding, src_eid);

// 7. 注册默认处理器
mctp_astpcie_register_default_handler(astpcie);
```

### 1.5 BDF 信息获取

```c
int test_mctp_astpcie_get_bdf(
    char *mctp_dev,
    uint8_t *src_bus,
    uint8_t *src_dev,
    uint8_t *src_func
);
```

BDF 编码格式：`bus[7:0] << 8 | dev[2:0] << 3 | func[2:0]`

### 1.6 消息发送

```c
int test_mctp_astpcie_send_data(
    struct test_mctp_ctx *ctx,
    uint8_t dst,           // 目标 EID
    uint8_t flag_tag,      // Tag 和 TO 标志
    void *req,             // 发送数据
    size_t size            // 数据大小
);
```

**发送示例：**

```c
uint8_t tag = 0;
tag |= MCTP_HDR_FLAG_TO;  // 设置 Tag Owner

ret = mctp_message_tx(mctp, dst_eid, req, size,
                      tag_owner, tag, astpcie_extra_params);
```

### 1.7 消息接收

**轮询方式接收：**

```c
int test_mctp_astpcie_recv_data_timeout_raw(
    struct test_mctp_ctx *ctx,
    uint8_t dst,
    int TOsec  // 超时秒数
);
```

**接收流程：**

```c
struct pollfd pfd = { 0 };
pfd.fd = astpcie->fd;
pfd.events = POLLIN;

// 注册响应回调
mctp_set_rx_all(mctp, rx_response_handler, ctx);

while (retry < 500) {
    r = poll(&pfd, 1, 10);  // 10ms 超时
    
    if (r > 0 && (pfd.revents & POLLIN)) {
        if (mctp_astpcie_rx(astpcie) < 0) {
            // 处理错误
        }
        if (p->len > 0) {
            return p->len;  // 返回接收长度
        }
    }
    retry++;
}
```

### 1.8 请求处理 (Responder 模式)

```c
void wait_for_request(struct test_mctp_ctx *ctx)
{
    // 注册请求处理器
    mctp_set_rx_all(mctp, rx_request_handler, ctx);
    mctp_set_rx_ctrl(mctp, rx_request_control_handler, ctx);
    
    while (1) {
        r = poll(&pfd, 1, 5000);
        if (mctp_astpcie_rx(astpcie) < 0) {
            break;
        }
    }
}
```

### 1.9 请求处理器实现

```c
void rx_request_handler(mctp_eid_t src, void *data, void *msg, size_t len,
                        bool tag_owner, uint8_t tag, void *msg_binding_private)
{
    struct mctp_ctrl_req *req = (struct mctp_ctrl_req *)msg;
    uint8_t mctp_type = req->hdr.ic_msg_type;
    uint8_t cmd = req->hdr.command_code;
    
    // 构建响应
    struct mctp_echo_resp resp = { 0 };
    memcpy(&resp.hdr, &req->hdr, msg_hdr_len);
    resp.hdr.rq_dgram_inst &= ~(MCTP_CTRL_HDR_FLAG_REQUEST);
    
    // 处理命令
    switch (cmd) {
    case MCTP_ASPEED_CTRL_CMD_ECHO_LARGE:
    case MCTP_ASPEED_CTRL_CMD_ECHO:
        resp.completion_code = MCTP_CTRL_CC_SUCCESS;
        memcpy(&resp.data, &req->data, len - msg_hdr_len);
        resp_len = len + 1;
        break;
    default:
        resp.completion_code = MCTP_CTRL_CC_ERROR_UNSUPPORTED_CMD;
        break;
    }
    
    // 发送响应
    mctp_message_tx(ctx->mctp, src, &resp, resp_len, false, tag, pkt_prv);
}
```

## 2. SMBus/I2C 传输绑定

### 2.1 概述

SMBus 传输适用于低速率、低复杂度的管理通信。

**源码：** `libmctp-intel-test/mctp-smbus-test.c`

**设备节点：** `/dev/i2c-<bus>` 和 `/sys/bus/i2c/devices/<bus>-00<addr>/slave-mqueue`

### 2.2 关键结构

```c
struct mctp_binding_smbus {
    struct mctp_binding binding;
    int in_fd;    // 接收文件描述符 (slave-mqueue)
    int out_fd;   // 发送文件描述符 (i2c-dev)
    uint8_t src_addr;
    uint8_t rxbuf[MCTP_SMBUS_BUFFER_SIZE];
};

struct mctp_smbus_pkt_private {
    int fd;
    uint8_t slave_addr;
    uint8_t mux_flags;
    uint16_t mux_hold_timeout;
};
```

### 2.3 SMBus 初始化

```c
struct test_mctp_ctx *test_mctp_smbus_init(
    uint8_t bus,       // I2C 总线号
    uint8_t src_addr,  // 源地址 (7-bit)
    uint8_t dst_addr,  // 目标地址 (7-bit)
    uint8_t src_eid    // 源 EID
);
```

**初始化流程：**

```c
// 1. 初始化
mctp = mctp_init();
smbus = mctp_smbus_init();

// 2. 设置源地址
mctp_smbus_set_src_slave_addr(smbus, src_addr);

// 3. 打开 I2C 设备
fd = open("/dev/i2c-<bus>", O_RDWR | O_NONBLOCK);
mctp_smbus_set_out_fd(smbus, fd);

// 4. 打开 slave-mqueue
snprintf(slave_queue, sizeof(slave_queue),
         "/sys/bus/i2c/devices/%d-00%02x/slave-mqueue", bus, src_addr >> 1);
fd = open(slave_queue, O_RDONLY | O_NONBLOCK);
mctp_smbus_set_in_fd(smbus, fd);

// 5. 注册总线
mctp_smbus_register_bus(smbus, mctp, src_eid);
```

### 2.4 SMBus 消息收发

**接收方式：**

```c
void wait_for_request(struct test_mctp_ctx *ctx)
{
    struct pollfd pfd = { 0 };
    pfd.fd = smbus->in_fd;
    pfd.events = POLLPRI;  // 注意：SMBus 使用 POLLPRI
    
    while (1) {
        r = poll(&pfd, 1, 5000);
        if (mctp_smbus_read(smbus) < 0) {
            // 错误处理
        }
    }
}
```

### 2.5 SMBus vs PCIe 差异

| 特性 | SMBus | PCIe |
|------|-------|------|
| 文件描述符 | in_fd, out_fd | fd |
| 轮询事件 | POLLPRI | POLLIN |
| 设备路径 | /dev/i2c-X | /dev/aspeed-mctp |
| 路由方式 | 地址 | BDF |
| 缓冲区 | slave-mqueue | 直接读写 |

## 3. 命令行工具使用

### 3.1 PCIe 测试工具

```bash
# 获取 BDF 信息
mctp-astpcie-test -g

# 接收模式 (Responder)
mctp-astpcie-test -r <bus> <routing> <dev> <func> <dst_eid> <src_eid>

# 发送模式 (Requester)
mctp-astpcie-test -t <bus> <routing> <dev> <func> <dst_eid> <src_eid> <type> <flags> <cmd>

# 示例：发送 Echo 命令
mctp-astpcie-test -t 10 2 0 0 9 8 0x7c 0x80 0x00 0x01 0x02 0x03 0x04 0x05

# 示例：发送控制消息
mctp-astpcie-test -t 10 2 0 0 9 8 0x00 0x80 0x05
```

### 3.2 SMBus 测试工具

```bash
# 接收模式
mctp-smbus-test -r <bus> <dst_addr> <src_addr> <dst_eid> <src_eid>

# 发送模式
mctp-smbus-test -t <bus> <dst_addr> <src_addr> <dst_eid> <src_eid> <type> <flags> <cmd>

# 示例：发送 Echo 命令
mctp-smbus-test -t 8 0x28 0x24 9 8 0x7c 0x80 0x00 0x01 0x02 0x03 0x04 0x05
```

## 4. 公共测试工具

### 4.1 测试模式生成

```c
void test_pattern_prepare(uint8_t *pattern, int size)
{
    // 生成 0x00, 0x01, 0x02 ... 0xFF 循环模式
    for (int i = 0; i < size; i++) {
        pattern[i] = i % 0x100;
    }
}
```

### 4.2 Echo 命令验证

```c
int verify_mctp_echo_cmd(uint8_t *tbuf, int tlen, uint8_t *rbuf, int rlen)
{
    // 验证请求消息类型
    // 验证响应头
    // 验证完成码 (0x00 = 成功)
    // 验证负载数据
}
```

### 4.3 原始数据打印

```c
void print_raw_data(uint8_t *buf, int len)
{
    for (int i = 0; i < len; ++i)
        printf("%02x ", buf[i]);
    printf("\n");
}
```

## 5. 错误处理和重试

### 5.1 发送重试机制

```c
int retry = 5;
for (int i = 0; i <= retry; i++) {
    ret = mctp_message_tx(mctp, dst, req, size, tag_owner, tag, params);
    if (ret == 0)
        break;
    usleep(10 * 1000);  // 10ms 延迟
}
```

### 5.2 接收超时

```c
// 默认超时：500 * 10ms = 5 秒
while (retry < 500) {
    r = poll(&pfd, 1, 10);
    if (mctp_astpcie_rx(astpcie) < 0)
        break;
    if (p->len > 0)
        return p->len;
    retry++;
}
return -1;  // 超时
```

## 6. 资源释放

```c
void test_mctp_astpcie_free(struct test_mctp_ctx *ctx)
{
    if (ctx->port != NULL)
        mctp_astpcie_free(ctx->port);
    if (ctx->mctp != NULL)
        mctp_destroy(ctx->mctp);
    free(ctx);
    free(astpcie_extra_params);
}
```