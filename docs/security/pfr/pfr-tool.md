# aspeed-pfr-tool 工具分析

## 1. 工具概述

`aspeed-pfr-tool` 是 Aspeed 提供的 PFR 配置和管理工具，用于与 BMC RoT CPLD 通信，执行根密钥配置、状态查询、固件版本获取等操作。

### 1.1 源码位置

```
/mnt/d/code/aspped-github/openbmc/meta-aspeed-sdk/meta-aspeed-pfr/recipes-aspeed/aspeed-pfr-tool/aspeed-pfr-tool/
```

### 1.2 编译系统

使用 Meson 构建系统:

- `meson.build` - 构建配置
- `meson_options.txt` - 构建选项

## 2. 核心模块

### 2.1 main.c - 主程序

**功能**: 命令行解析和程序入口

**主要功能**:

```c
// 命令行参数结构
static const char short_options[] = "hvb:a:c:p:uk:w:r:dsiS:l:ED:t:n:";
static const struct option long_options[] = {
    { "help", no_argument, NULL, 'h' },
    { "version", no_argument, NULL, 'v' },
    { "bus", required_argument, NULL, 'b' },
    { "address", required_argument, NULL, 'a' },
    { "pfrtoolconf", required_argument, NULL, 'c' },
    { "provision", required_argument, NULL, 'p' },
    { "unprovision", no_argument, NULL, 'u' },
    { "checkpoint", required_argument, NULL, 'k' },
    { "write_reg", required_argument, NULL, 'w' },
    { "read_reg", required_argument, NULL, 'r' },
    { "debug", no_argument, NULL, 'd' },
    { "status", no_argument, NULL, 's' },
    { "info", no_argument, NULL, 'i' },
    { "spdm", required_argument, NULL, 'S' },
    { "lms", required_argument, NULL, 'l' },
    { "secure", no_argument, NULL, 'E' },
    { "dest_id", required_argument, NULL, 'D' },
    { "test_case", required_argument, NULL, 't' },
    { "mctp_network", required_argument, NULL, 'n' },
};
```

**关键函数**:

| 函数名 | 功能 |
|--------|------|
| `main()` | 程序入口，解析参数，调用相应功能 |
| `parseConfigElements()` | 解析配置文件 |
| `printArguments()` | 打印参数调试信息 |

### 2.2 provision.c - 配置管理

**功能**: 根密钥配置和 UFM 编程

#### 2.2.1 根密钥处理

```c
// 从公钥文件提取 QX 和 QY 坐标
int extractQxQyFromPubkey(const char *file, uint8_t *qx, uint8_t *qy, int *len);

// 计算根密钥哈希
int getRootKeyHash(const char *file, uint8_t *hash, int *len);

// 计算 LMS 根密钥哈希
int getLMSRootKeyHash(const char *file, HashAlg type, uint8_t *hash, int *len);
```

**支持算法**:
- SHA-256
- SHA-384
- SHA-512

#### 2.2.2 UFM 命令接口

```c
// 等待 UFM 命令触发执行
int waitUntilUfmCmdTriggerExec(ARGUMENTS args);

// 等待配置命令完成
int waitUntilUfmProvStatusCmdDone(ARGUMENTS args);

// 写入 UFM 配置 FIFO 命令
int writeUfmProvFifoCmd(ARGUMENTS args, MB_UFM_PROV_CMD_ENUM cmd, 
                        uint8_t *buf, int len);

// 读取 UFM 配置 FIFO 命令
int readUfmProvFifoCmd(ARGUMENTS args, MB_UFM_PROV_CMD_ENUM cmd, 
                       uint8_t *buf, int len);
```

#### 2.2.3 配置操作

```c
// 执行配置 (写入根密钥和偏移量)
int doProvision(ARGUMENTS args);

// 配置锁定
int provisionLock(ARGUMENTS args);

// 取消配置
int unprovision(ARGUMENTS args);

// 显示当前配置
int provisionShow(ARGUMENTS args);

// 主配置函数
int provision(ARGUMENTS args);
```

**配置命令**:

| 命令 | 功能 |
|------|------|
| `provision <key_file>` | 配置根密钥 |
| `provision show` | 显示当前配置 |
| `provision lock` | 锁定 UFM |
| `unprovision` | 清除 UFM 配置 |

#### 2.2.4 偏移量配置

```c
// 写入区域偏移量
int writeUfmProvRegionOffset(ARGUMENTS args);
```

**配置的偏移量**:
- BMC Active PFM Offset
- BMC Recovery Offset
- BMC Staging Offset
- PCH Active PFM Offset
- PCH Recovery Offset
- PCH Staging Offset
- AFM Staging Offset (可选)

### 2.3 spdm.c - SPDM 协议

**功能**: SPDM (Security Protocol and Data Model) 认证和通信

#### 2.3.1 MCTP 通信

```c
// 初始化普通 Socket
int init_socket(ARGUMENTS *args);

// 初始化安全 Socket
int init_secure_socket(ARGUMENTS *args);

// 设置安全连接
int setupSecureConnect(ARGUMENTS *args);
```

#### 2.3.2 安全连接

```c
// 创建 SPDM 会话
libspdm_return_t create_session_via_spdm(bool use_psk);

// 关闭安全会话
int close_secure_session(ARGUMENTS *args);

// 处理安全消息
int process_secure_msg(vendor_def_msg *msg, size_t data_size, 
                       uint8_t *rsp, size_t *rsp_size);
```

#### 2.3.3 SPDM 配置

```c
// 启用/禁用 SPDM 功能
void setSPDMFunction(ARGUMENTS args, int enabled);
```

**支持的 SPDM 功能**:
- `spdm enable` - 启用 SPDM 认证
- `spdm disable` - 禁用 SPDM 认证

#### 2.3.4 SPDM 能力

```c
m_use_requester_capability_flags = 
    SPDM_GET_CAPABILITIES_REQUEST_FLAGS_CERT_CAP |        // 证书支持
    SPDM_GET_CAPABILITIES_REQUEST_FLAGS_CHAL_CAP |       // 挑战支持
    SPDM_GET_CAPABILITIES_REQUEST_FLAGS_MAC_CAP |        // MAC 支持
    SPDM_GET_CAPABILITIES_REQUEST_FLAGS_ENCRYPT_CAP |    // 加密支持
    SPDM_GET_CAPABILITIES_REQUEST_FLAGS_MUT_AUTH_CAP |   // 双向认证
    SPDM_GET_CAPABILITIES_REQUEST_FLAGS_KEY_EX_CAP |     // 密钥交换
    SPDM_GET_CAPABILITIES_REQUEST_FLAGS_ENCAP_CAP |      // 封装支持
    SPDM_GET_CAPABILITIES_REQUEST_FLAGS_HBEAT_CAP |      // 心跳支持
    SPDM_GET_CAPABILITIES_REQUEST_FLAGS_KEY_UPD_CAP |    // 密钥更新
    SPDM_GET_CAPABILITIES_REQUEST_FLAGS_HANDSHAKE_IN_THE_CLEAR_CAP;
```

### 2.4 status.c - 状态查询

**功能**: 查询和显示 PFR 系统状态

#### 2.4.1 状态读取函数

| 函数名 | 功能 |
|--------|------|
| `get_cpld_id()` | 获取 CPLD 静态 ID |
| `get_cpld_ver()` | 获取 CPLD 版本 |
| `get_cpld_svn()` | 获取 CPLD SVN |
| `get_plat_state()` | 获取平台状态 |
| `get_recovery_count()` | 获取恢复计数 |
| `get_last_recovery_reason()` | 获取上次恢复原因 |
| `get_panic_event_count()` | 获取 Panic 事件计数 |
| `get_last_panic_reason()` | 获取上次 Panic 原因 |
| `get_major_err()` | 获取主要错误代码 |
| `get_minor_auth_err()` | 获取次要认证错误 |
| `get_minor_update_err()` | 获取次要更新错误 |
| `get_ufm_provisioning_status()` | 获取 UFM 配置状态 |

#### 2.4.2 主要输出

```c
void show_status(ARGUMENTS args);
```

**输出内容**:
- CPLD RoT Static Identifier
- CPLD RoT Release Version
- CPLD RoT SVN
- CPLD RoT Hash
- Platform State (状态码和描述)
- Recovery Count
- Last Recovery Reason
- Panic Event Count
- Last Panic Reason
- Major Error Code
- Minor Error Code
- PFR Activity Info 1/2
- UFM/Provisioning Status

### 2.5 info.c - 版本信息

**功能**: 查询 PFM 版本信息

```c
void show_info(ARGUMENTS args);
```

**输出内容**:
- PCH/CPU PFM Active (SVN, Major, Minor)
- BMC PFM Active (SVN, Major, Minor)
- PCH/CPU PFM Recovery (SVN, Major, Minor)
- BMC PFM Recovery (SVN, Major, Minor)
- AFM Active/Recovery (可选)

### 2.6 checkpoint.c - 检查点控制

**功能**: 控制固件启动检查点

**检查点命令**:
- `start` - 开始执行块
- `auth_pass` - 认证通过
- `auth_fail` - 认证失败
- `exit` - 退出制造商权限
- `pause` - 暂停执行块
- `resume` - 恢复执行块
- `complete` - 完成执行块

### 2.7 i2c_utils.c - I2C 通信

**功能**: I2C/SMBus 通信接口

**主要函数**:
- `i2cOpenDev()` - 打开 I2C 设备
- `ReadByteData()` - 读取单字节
- `ReadBlockData()` - 读取数据块
- `WriteByteData()` - 写入单字节
- `WriteBlockData()` - 写入数据块

### 2.8 utils.c - 工具函数

**功能**: 通用工具函数

**主要函数**:
- `printRawData()` - 打印原始数据
- `hashBuffer()` - 计算哈希值
- 其他辅助函数

## 3. 邮箱寄存器

### 3.1 寄存器定义 (mailbox_enums.h)

| 地址 | 名称 | 说明 |
|------|------|------|
| 0x00 | MB_CPLD_STATIC_ID | CPLD 静态 ID |
| 0x01 | MB_CPLD_RELEASE_VERSION | 版本号 |
| 0x02 | MB_CPLD_SVN | SVN |
| 0x03 | MB_PLATFORM_STATE | 平台状态 |
| 0x04 | MB_RECOVERY_COUNT | 恢复计数 |
| 0x05 | MB_LAST_RECOVERY_REASON | 上次恢复原因 |
| 0x06 | MB_PANIC_EVENT_COUNT | Panic 事件计数 |
| 0x07 | MB_LAST_PANIC_REASON | 上次 Panic 原因 |
| 0x08 | MB_MAJOR_ERROR_CODE | 主要错误码 |
| 0x09 | MB_MINOR_ERROR_CODE | 次要错误码 |
| 0x0A | MB_PROVISION_STATUS | 配置状态 |
| 0x0B | MB_PROVISION_CMD | 配置命令 |
| 0x0C | MB_UFM_CMD_TRIGGER | 命令触发器 |
| 0x0D | MB_UFM_WRITE_FIFO | 写 FIFO |
| 0x0E | MB_UFM_READ_FIFO | 读 FIFO |
| 0x0F | MB_MCTP_PACKET_WRITE_RXFIFO | MCTP 数据包 |
| 0x60 | MB_BMC_CHECKPOINT | BMC 检查点 |
| 0x7E | MB_PFR_ACTIVITY_INFO_1 | 活动信息 1 |
| 0x7F | MB_PFR_ACTIVITY_INFO_2 | 活动信息 2 |

## 4. 使用示例

### 4.1 基本操作

```bash
# 显示帮助
aspeed-pfr-tool --help

# 显示版本
aspeed-pfr-tool --version

# 读取寄存器
aspeed-pfr-tool --bus 8 --address 0x40 --read_reg 0x03

# 写入寄存器
aspeed-pfr-tool --bus 8 --address 0x40 --write_reg 0x60 0x01
```

### 4.2 配置操作

```bash
# 显示当前配置
aspeed-pfr-tool --bus 8 --address 0x40 --provision show

# 配置根密钥
aspeed-pfr-tool --bus 8 --address 0x40 --provision /path/to/rk_pub.pem

# 锁定 UFM
aspeed-pfr-tool --bus 8 --address 0x40 --provision lock

# 清除配置
aspeed-pfr-tool --bus 8 --address 0x40 --unprovision
```

### 4.3 状态查询

```bash
# 查询 PFR 状态
aspeed-pfr-tool --bus 8 --address 0x40 --status

# 查询固件版本信息
aspeed-pfr-tool --bus 8 --address 0x40 --info

# 调试模式
aspeed-pfr-tool --bus 8 --address 0x40 --status --debug
```

### 4.4 检查点控制

```bash
# 发送检查点命令
aspeed-pfr-tool --bus 8 --address 0x40 --checkpoint start
aspeed-pfr-tool --bus 8 --address 0x40 --checkpoint auth_pass
aspeed-pfr-tool --bus 8 --address 0x40 --checkpoint complete
```

### 4.5 SPDM 配置

```bash
# 启用 SPDM
aspeed-pfr-tool --bus 8 --address 0x40 --spdm enable

# 禁用 SPDM
aspeed-pfr-tool --bus 8 --address 0x40 --spdm disable
```

### 4.6 安全连接

```bash
# 使用安全连接
aspeed-pfr-tool --bus 8 --address 0x40 --secure --status

# 指定目标 EID
aspeed-pfr-tool --bus 8 --address 0x40 --secure --dest_id 0x8 --status
```

### 4.7 LMS 模式

```bash
# 使用 LMS-256 签名
aspeed-pfr-tool --bus 8 --address 0x40 --lms 256 --provision key.pem

# 使用 LMS-384 签名
aspeed-pfr-tool --bus 8 --address 0x40 --lms 384 --provision key.pem
```

## 5. 配置文件

### 5.1 默认配置文件

默认路径: `/usr/share/pfrconfig/aspeed-pfr-tool.conf`

### 5.2 配置格式

```
I2C_BUS=8
ROT_ADDRESS=0x40
BMC_ACTIVE_PFM_OFFSET=0x100000
BMC_STAGING_OFFSET=0x200000
BMC_RECOVERY_OFFSET=0x300000
PCH_ACTIVE_PFM_OFFSET=0x400000
PCH_STAGING_OFFSET=0x500000
PCH_RECOVERY_OFFSET=0x600000
AFM_STAGING_OFFSET=0x700000
```

## 6. 构建和部署

### 6.1 BitBake 配方

```bitbake
# aspeed-pfr-tool.bb
SUMMARY = "Aspeed PFR tool"
LICENSE = "MIT"
SRC_URI = "file://aspeed-pfr-tool/"

DEPENDS = "openssl libpfr-native"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${S}/aspeed-pfr-tool ${D}${bindir}/
}
```

### 6.2 平台配置

- AST2700: `meta-ast2700-pfr/conf/machine/`
- AST2600: `meta-ast2600-pfr/conf/machine/`

## 7. 架构图

```
                    aspeed-pfr-tool
                           |
         +-----------------+-----------------+
         |                 |                 |
    命令行解析          配置管理           通信接口
         |                 |                 |
    main.c            provision.c       i2c_utils.c
         |                 |                 |
    +----v----+      +-----+-----+      +----v----+
    | 参数    |      | 根密钥   |      | I2C/SMBus|
    | 解析   |      | UFM     |      | 读写     |
    +---------+      +---------+      +----------+
         |                 |                 |
    +----v----+      +-----+-----+      +----v----+
    | 状态    |      | 哈希    |      | MCTP    |
    | 查询   |      | 计算    |      | Socket  |
    +---------+      +---------+      +----------+
```

## 8. 相关文件

| 文件 | 说明 |
|------|------|
| `main.c` | 主程序和命令行解析 |
| `provision.c` | 根密钥配置和 UFM 编程 |
| `spdm.c` | SPDM 协议实现 |
| `status.c` | PFR 状态查询 |
| `info.c` | PFM 版本信息 |
| `checkpoint.c` | 检查点控制 |
| `i2c_utils.c` | I2C 通信 |
| `utils.c` | 工具函数 |
| `include/mailbox_enums.h` | 邮箱寄存器定义 |
| `include/spdm.h` | SPDM 定义 |