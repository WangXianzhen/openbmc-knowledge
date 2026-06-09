# AST2700 PFR 安全特性

## 1. 安全架构概述

PFR (Platform Firmware Resilience) 为 AST2700 BMC 提供多层次的安全保护，确保固件完整性、启动信任链和防篡改能力。

### 1.1 信任链

```
+-----------------+
|   BootROM       |  不可变根信任
+--------+--------+
         |
         v
+--------+--------+
|   FMC/BootMCU  |  首次可变代码 (OTP 根密钥验证)
+--------+--------+
         |
         v
+--------+--------+
|   BL31 (TF-A)  |  Trusted Firmware-A (Caliptra Manifest 验证)
+--------+--------+
         |
         v
+--------+--------+
|   OP-TEE       |  可信执行环境 (Caliptra Manifest 验证)
+--------+--------+
         |
         v
+--------+--------+
|   U-Boot       |  引导加载器 (FIT 签名验证)
+--------+--------+
         |
         v
+--------+--------+
|   Linux        |  内核 (签名验证)
+--------+--------+
         |
         v
+--------+--------+
|   OpenBMC      |  应用层 (PFR 保护)
+--------+--------+
```

### 1.2 PFR 安全层级

| 层级 | 组件 | 保护机制 |
|------|------|----------|
| L0 | BootROM | 硬件不可变根 |
| L1 | FMC | OTP 根密钥验证 |
| L2 | CPLD RoT | 固件签名验证 |
| L3 | 应用 | SPDM 认证 |

## 2. 根密钥和密钥管理

### 2.1 根密钥类型

PFR 支持两种根密钥方案:

| 类型 | 算法 | 说明 |
|------|------|------|
| ECDSA | P-256/P-384 | 椭圆曲线签名 |
| LMS | LMS-256/LMS-384 | 哈希签名 (抗量子) |

### 2.2 根密钥哈希计算

```c
// 从公钥文件提取 QX 和 QY 坐标
int extractQxQyFromPubkey(const char *file, uint8_t *qx, uint8_t *qy, int *len);

// 计算根密钥哈希
int getRootKeyHash(const char *file, uint8_t *hash, int *len);
```

**计算流程**:

```
1. 从 PEM 文件读取公钥
2. 提取公钥的 QX 和 QY 坐标
3. 合并 QX + QY (小端序)
4. 计算 SHA-256/SHA-384 哈希
5. 写入 UFM
```

### 2.3 LMS 根密钥支持

```c
int getLMSRootKeyHash(const char *file, HashAlg type, uint8_t *hash, int *len);
```

LMS (Leighton-Micali Signatures) 是基于哈希的签名算法，具有抗量子计算攻击能力。

**支持的参数**:

| 参数 | 哈希算法 | 签名长度 |
|------|----------|----------|
| `--lms 256` | SHA-256 | LMS-256 |
| `--lms 384` | SHA-384 | LMS-384 |

## 3. PIT (Platform Initialization Timeline)

PIT 是 PFR 的关键安全特性,提供渐进式的信任建立过程。

### 3.1 PIT Level-1 (L1)

**目的**: 建立初步信任,锁定配置

**触发条件**:
- 根密钥已配置
- 所有固件区域已验证
- 检测到合法启动序列

**效果**:
- UFM 锁定后无法修改根密钥
- 启用防回滚保护
- 记录首次测量值

**寄存器状态**:
```
Bit[6] = 1: PIT Level-1 enforced
```

### 3.2 PIT Level-2 (L2)

**目的**: 完整信任建立,密封固件

**触发条件**:
- PIT L1 已启用
- 所有固件哈希已记录
- 完成完整启动流程

**效果**:
- 创建固件密封记录
- 锁定所有固件区域
- 任何固件变更都会触发恢复

**寄存器状态**:
```
Bit[7] = 1: PIT Level-2 has been completed successfully
```

### 3.3 PIT 错误处理

| 场景 | PIT L1 | PIT L2 | 结果 |
|------|--------|--------|------|
| 正常启动 | 已启用 | 已完成 | 正常启动 |
| 认证失败 | 已启用 | 未完成 | 锁定 + 恢复 |
| 哈希不匹配 | 未启用 | 未完成 | 锁定 |
| 恢复尝试 | 已启用 | 未完成 | 恢复固件 |

## 4. 固件完整性检查

### 4.1 签名验证

PFR RoT CPLD 在启动过程中验证固件签名:

```
+-------------+     +----------------+     +------------+
| 固件镜像     | --> | 签名验证       | --> | 执行固件   |
+-------------+     +----------------+     +------------+
                          |
                          v
                   +---------------+
                   | 验证失败       |
                   +---------------+
                          |
                          v
                   +---------------+
                   | 加载恢复固件   |
                   +---------------+
```

### 4.2 验证流程

**BMC 固件验证**:

```c
// 1. 读取固件头
// 2. 提取签名
// 3. 使用根密钥验证签名
// 4. 验证固件哈希
// 5. 检查 SVN (防回滚)
```

**区域验证**:

| 区域 | 验证内容 | 失败处理 |
|------|----------|----------|
| Active PFM | 主固件签名 | 加载 Recovery |
| Recovery PFM | 备份固件签名 | 记录错误 |
| Staging | 更新包签名 | 拒绝更新 |

### 4.3 SVN (Security Version Number) 检查

SVN 用于防回滚保护:

```
if (new_firmware.svn < current_firmware.svn) {
    reject_update();
}
```

**寄存器位置**:
- `MB_PCH_PFM_ACTIVE_SVN` (0x14)
- `MB_BMC_PFM_ACTIVE_SVN` (0x17)
- `MB_PCH_PFM_RECOVERY_SVN` (0x1A)
- `MB_BMC_PFM_RECOVERY_SVN` (0x1D)

## 5. 恢复机制

### 5.1 自动恢复流程

```
+-----------------+
| 检测认证失败    |
+--------+--------+
         |
         v
+--------+--------+
| Recovery Count++|  增加恢复计数
+--------+--------+
         |
         v
+--------+--------+
| 记录恢复原因    |  MB_LAST_RECOVERY_REASON
+--------+--------+
         |
         v
+--------+--------+
| 尝试 Recovery   |  从 Recovery PFM 加载
+--------+--------+
         |
    +----+----+
    |         |
    v         v
+---------+ +---------+
| 成功    | | 失败    |
+---------+ +---------+
    |         |
    v         v
+---------+ +---------+
| 正常启动 | | 锁定    |
+---------+ +---------+
```

### 5.2 恢复原因代码

| 代码 | 原因 | 严重程度 |
|------|------|----------|
| 0x01 | PCH/CPU active failure | 高 |
| 0x02 | PCH/CPU recovery failure | 严重 |
| 0x03 | Intel ME launch failure | 高 |
| 0x04 | ACM launch failure | 高 |
| 0x05 | IBB launch failure | 高 |
| 0x06 | OBB launch failure | 高 |
| 0x07 | BMC active failure | 高 |
| 0x08 | BMC recovery failure | 严重 |
| 0x09 | BMC launch failure | 高 |
| 0x0A | CPLD WDT expired | 严重 |
| 0x0B | CPLD active failure | 严重 |

### 5.3 最大恢复尝试

系统限制连续恢复尝试次数,防止无限循环:

```
if (recovery_count > MAX_RECOVERY_ATTEMPTS) {
    enter_lockdown_mode();
}
```

## 6. BMC 防护

### 6.1 BMC 启动保护

**BMC 检查点** (`MB_BMC_CHECKPOINT`):

| 值 | 名称 | 说明 |
|----|------|------|
| 0x01 | MB_CHKPT_START | 启动执行块 |
| 0x02 | MB_CHKPT_AUTH_PASS | 认证通过 |
| 0x03 | MB_CHKPT_AUTH_FAIL | 认证失败 |
| 0x07 | MB_CHKPT_PAUSE | 暂停执行 |
| 0x08 | MB_CHKPT_RESUME | 恢复执行 |
| 0x09 | MB_CHKPT_COMPLETE | 执行完成 |
| 0x0A | MB_CHKPT_ENTER_MGMT | 进入管理模式 |
| 0x0B | MB_CHKPT_EXIT_MGMT | 退出管理模式 |

### 6.2 BMC 更新保护

更新意图寄存器 (`MB_BMC_UPDATE_INTENT`):

**更新流程保护**:

```
1. BMC 发送更新意图
2. PFR 验证意图格式
3. 验证更新包签名
4. 验证 SVN
5. 验证后写入 Staging
6. 重新验证后复制到 Recovery/Active
```

### 6.3 BMC 启动完成保护

```c
// 通知 PFR BMC 启动完成
WriteByteData(args, MB_BMC_CHECKPOINT, MB_CHKPT_COMPLETE);
```

启动完成后:
- BMC 检查点锁定
- 防止 BMC 重置攻击
- 记录启动时间戳

## 7. Panic 事件处理

### 7.1 Panic 原因

| 代码 | 原因 |
|------|------|
| 0x01 | PCH update intent |
| 0x02 | BMC update intent |
| 0x03 | BMC reset detected |
| 0x04 | BMC WDT expired |
| 0x05 | Intel ME WDT expired |
| 0x06 | ACM WDT expired |
| 0x07 | IBB WDT expired |
| 0x08 | OBB WDT expired |
| 0x09 | ACM/IBB/OBB signature authentication failure |
| 0x0A | Attestation failure |

### 7.2 Panic 事件处理

```
+-----------------+
| 检测 Panic 条件 |
+--------+--------+
         |
         v
+--------+--------+
| Panic Count++  |  MB_PANIC_EVENT_COUNT
+--------+--------+
         |
         v
+--------+--------+
| 记录 Panic 原因 |  MB_LAST_PANIC_REASON
+--------+--------+
         |
         v
+--------+--------+
| 触发响应        |
+--------+--------+
```

### 7.3 Watchdog 超时处理

| 组件 | WDT 超时后果 |
|------|-------------|
| BMC | Panic + 恢复尝试 |
| Intel ME | Panic + 锁定 |
| ACM | Panic + 锁定 |
| IBB | Panic + 锁定 |
| OBB | Panic + 锁定 |

## 8. SPDM 认证

### 8.1 SPDM 概述

SPDM (Security Protocol and Data Model) 提供安全的消息认证和设备认证能力。

### 8.2 支持的功能

| 功能 | 标志 | 说明 |
|------|------|------|
| CERT_CAP | 证书支持 | X.509 证书链 |
| CHAL_CAP | 挑战支持 | 质询响应认证 |
| MAC_CAP | MAC 支持 | 消息认证码 |
| ENCRYPT_CAP | 加密支持 | 传输加密 |
| MUT_AUTH_CAP | 双向认证 | 互相认证 |
| KEY_EX_CAP | 密钥交换 | 密钥协商 |
| ENCAP_CAP | 封装支持 | 消息封装 |
| HBEAT_CAP | 心跳支持 | 连接保活 |
| KEY_UPD_CAP | 密钥更新 | 密钥轮换 |

### 8.3 安全连接流程

```c
// 1. 初始化连接
setupSecureConnect();

// 2. 执行 SPDM 认证
do_authentication_via_spdm();

// 3. 创建安全会话
create_session_via_spdm(false);

// 4. 使用安全通信
process_secure_msg();

// 5. 关闭会话
close_secure_session();
```

### 8.4 MCTP 安全传输

**MCTP 消息类型**:
- `MCTP_MESSAGE_TYPE_SPDM` (0x05) - 普通 SPDM 消息
- `MCTP_MESSAGE_TYPE_SECURED_MCTP` (0x07) - 安全 MCTP 消息

**IC (Integrity Check) 标志**:
```c
my_address_secure.smctp_type = MCTP_MESSAGE_TYPE_SECURED_MCTP | MCTP_IC_FLAG;
```

## 9. 锁定模式

### 9.1 锁定条件

| 条件 | 锁定级别 | 说明 |
|------|----------|------|
| 认证失败 (L1 已启用) | 软锁定 | 允许恢复尝试 |
| Recovery 失败 | 硬锁定 | 禁止启动 |
| PIT L2 不匹配 | 永久锁定 | 需要物理干预 |
| 多次恢复尝试失败 | 硬锁定 | 需要重新配置 |

### 9.2 锁定状态码

| 状态码 | 说明 |
|--------|------|
| 0x08 | Lockdown due to authentication failure |
| 0x48 | Lockdown due to PIT L1 |
| 0x49 | PIT L2 firmware sealed |
| 0x4A | Lockdown due to PIT L2 PCH/CPU hash mismatch |
| 0x4B | Lockdown due to PIT L2 BMC hash mismatch |

### 9.3 锁定恢复

**唯一解锁方式**:
1. 重新配置 UFM
2. 物理复位 (特定条件)

## 10. 错误分类和处理

### 10.1 主要错误 (Major Error)

| 代码 | 错误 | 处理 |
|------|------|------|
| 0x01 | BMC 认证失败 | Recovery 尝试 |
| 0x02 | PCH/CPU 认证失败 | Recovery 尝试 |
| 0x03 | 内外更新失败 | 记录 + 阻止更新 |
| 0x04 | ROT 认证失败 | 硬锁定 |
| 0x05 | 认证测量不匹配 | Recovery 尝试 |
| 0x06 | 认证超时 | 记录 + 警告 |
| 0x07 | SPDM 协议错误 | 通信重试 |
| 0x08 | CPLD 认证失败 | 硬锁定 |

### 10.2 次要错误 - 认证类

| 代码 | 错误 | 影响 |
|------|------|------|
| 0x01 | Active 区域认证失败 | 尝试 Recovery |
| 0x02 | Recovery 区域认证失败 | 硬锁定 |
| 0x03 | Active + Recovery 失败 | 硬锁定 |
| 0x04 | 所有区域失败 | 硬锁定 |
| 0x05-0x08 | AFM 认证失败 | AFM 禁用 |

### 10.3 次要错误 - 更新类

| 代码 | 错误 | 影响 |
|------|------|------|
| 0x01 | 无效更新意图 | 拒绝更新 |
| 0x02 | 无效 SVN | 拒绝更新 |
| 0x03 | 更新包认证失败 | 拒绝更新 |
| 0x04 | 超最大尝试次数 | 临时锁定 |
| 0x05 | Recovery 失败后禁止 Active 更新 | 阻止更新 |

## 11. 安全建议

### 11.1 生产环境

1. **启用 PIT L1 和 L2**
   ```bash
   aspeed-pfr-tool --provision enable_pit_l1
   aspeed-pfr-tool --provision enable_pit_l2
   ```

2. **锁定 UFM**
   ```bash
   aspeed-pfr-tool --provision lock
   ```

3. **定期验证完整性**
   ```bash
   aspeed-pfr-tool --status
   # 检查 Major/Minor Error Codes
   ```

### 11.2 密钥管理

1. **安全存储根密钥**
   - 使用 HSM (Hardware Security Module)
   - 实施密钥分割策略

2. **定期轮换密钥**
   - 制定密钥更新计划
   - 测试密钥更新流程

3. **LMS 迁移准备**
   - 监控量子计算发展
   - 准备 LMS 迁移路径

### 11.3 监控策略

```c
// 定期检查关键状态
void monitor_pfr_status() {
    uint8_t major_err = read_reg(MB_MAJOR_ERROR_CODE);
    uint8_t minor_err = read_reg(MB_MINOR_ERROR_CODE);
    uint8_t plat_state = read_reg(MB_PLATFORM_STATE);
    uint8_t ufm_status = read_reg(MB_PROVISION_STATUS);
    
    if (major_err != 0) {
        log_security_event(major_err, minor_err);
        alert_security_team();
    }
}
```

## 12. 相关文档

- **PFR 概述**: `/mnt/d/code/aspped-github/openbmc/meta-aspeed-sdk/meta-aspeed-pfr/pfr-overview.md`
- **PFR 工具**: `/mnt/d/code/aspped-github/openbmc/meta-aspeed-sdk/meta-aspeed-pfr/pfr-tool.md`
- **安全启动**: `/mnt/d/code/aspped-github/openbmc/docs/AST2700_SecureBoot.md`
- **Caliptra 集成**: `/mnt/d/code/aspped-github/openbmc/meta-aspeed-sdk/recipes-aspeed/security/`

## 13. 总结

AST2700 PFR 系统提供:

| 特性 | 实现 |
|------|------|
| 固件签名验证 | ECDSA P-256/P-384, LMS |
| 防回滚保护 | SVN 检查 |
| 自动恢复 | Recovery PFM 机制 |
| 安全通信 | SPDM + MCTP |
| 信任建立 | PIT L1/L2 渐进式 |
| 锁定保护 | 多层级锁定机制 |
| 审计追踪 | Panic/Recovery 事件记录 |