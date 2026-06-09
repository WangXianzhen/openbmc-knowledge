# FMC Design - First Mutable Code 设计说明

## 1. FMC 概述

FMC (First Mutable Code) 是 AST2700 安全启动架构中的关键概念。它代表芯片 BootROM 之后第一个可以被更新的代码组件，是信任链中的第一个可验证环节。

### 1.1 FMC 在信任链中的位置

```
┌─────────────────────────────────────────────────────────────────┐
│                        BootROM (ROM)                            │
│                   不可变的硬件信任根                              │
│                   存储在芯片内部 OTP                             │
└────────────────────────────┬────────────────────────────────────┘
                             │ 验证并执行
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                        FMC (First Mutable Code)                 │
│              BootMCU 或 Caliptra Manifest                        │
│              信任链中第一个可更新组件                             │
│              由 OTP 中的 Root Key Hash 验证                      │
└────────────────────────────┬────────────────────────────────────┘
                             │ 验证并执行
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                         BL31 (TF-A)                             │
│                   Trusted Firmware-A                            │
└─────────────────────────────────────────────────────────────────┘
```

## 2. FMC 镜像格式

### 2.1 FMCv2 头结构

FMC 镜像使用版本 2 头格式，提供更丰富的元数据和签名支持:

```c
// fmc_imgtool/hdr_v2.py

struct FmcHdrV2 {
    uint32_t magic;              // FMC_MAGIC_V2 = 0x43464D32 ("CFM2")
    uint16_t hdr_version;        // 头版本号
    uint16_t hdr_size;           // 头大小
    uint32_t fmc_size;           // FMC 固件大小
    uint32_t fmc_svn;            // 安全版本号
    uint8_t  fmc_dgst[48];       // SHA-384 FMC 摘要
    uint8_t  fmc_sig[96];        // ECDSA384 签名
    uint16_t num_prebuilts;      // 预构建组件数量
    PrebuiltEntry prebuilts[];   // 预构建条目列表
    uint8_t  padding[];          // 对齐填充
};
```

### 2.2 预构建组件条目

每个预构建组件在 FMC 头中有一个条目:

```c
struct PrebuiltEntry {
    uint16_t type;               // 组件类型 (PrebuiltType)
    uint16_t reserved;
    uint32_t size;               // 组件大小
    uint8_t  dgst[48];           // SHA-384 摘要
    uint8_t  sig[96];            // ECDSA384 签名
};
```

### 2.3 预构建组件类型

| 类型值 | 名称 | 说明 |
|--------|------|------|
| 0 | CALIPTRA_FW | Caliptra 固件 |
| 1 | MCU_RUNTIME | MCU 运行时固件 |
| 2 | SOC_MANIFEST | SoC Manifest |
| 3 | BL31 | ARM Trusted Firmware |
| 4 | OP_TEE | OP-TEE OS |
| 5 | BL33 (UBOOT) | U-Boot |
| 6 | DDR_PREBUILT | DDR 初始化固件 |
| 7 | SSP_FW | SSP 固件 |
| 8 | TSP_FW | TSP 固件 |

## 3. FMC 生成流程

### 3.1 整体流程

```
┌─────────────────┐
│   原始固件      │
│ zephyr.bin      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   计算摘要      │
│ SHA-384         │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   计算签名      │
│ ECDSA384/SHA384 │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  构建 FMC 头    │
│  版本 2 格式    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  添加预构建     │
│  组件引用       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   FMC 镜像      │
│ ast2700-        │
│ mcu-runtime.bin │
└─────────────────┘
```

### 3.2 Python 实现分析

**文件**: `fmc_imgtool/main.py`

```python
def gen_fmc_info(fmc_path, fmc_svn) -> FmcInfo:
    """生成 FMC 信息结构"""
    f = open(fmc_path, "rb")
    fmc_info = FmcInfo()
    fmc_info.svn = fmc_svn
    fmc_info.data = f.read()
    fmc_info.size = f.tell()

    # 强制 4 字节对齐
    padding = b'\x00' * ((4 - (fmc_info.size & 3)) & 3)
    fmc_info.data += padding
    fmc_info.size += len(padding)

    # 计算 SHA-384 摘要
    fmc_info.dgst = hashlib.sha384(fmc_info.data).digest()
    f.close()
    return fmc_info

def gen_prebuilt_info(pb_dir, pb_bin) -> List[PrebuiltInfo]:
    """生成预构建组件信息"""
    pbs_info = []
    for pb_name in pb_bin:
        pb_path = pb_dir + pb_name
        f = open(pb_path, "rb")
        pbi = PrebuiltInfo()
        pbi.name = pb_name
        pbi.type = pb_bin[pb_name].value
        pbi.data = f.read()
        pbi.size = f.tell()
        pbi.dgst = hashlib.sha384(pbi.data).digest()
        pbs_info.append(pbi)
        f.close()
    return pbs_info
```

## 4. FMC 验证流程

### 4.1 BootROM 验证流程

```
BootROM 启动
    │
    ▼
读取 OTP 中的 Root Key Hash
    │
    ▼
从 Flash FMC 分区读取 FMC 镜像头
    │
    ▼
使用 Root Key Hash 中的公钥验证 FMC 签名
    │
    ├─── 验证失败 ───▶ 停止启动，显示错误
    │
    ▼
验证通过，提取 FMC 摘要
    │
    ▼
计算 FMC 固件实际摘要并比对
    │
    ├─── 摘要不匹配 ──▶ 停止启动，显示错误
    │
    ▼
加载并执行 FMC 固件
```

### 4.2 密钥槽位

OTP 区域支持 16 个 DSS 公钥槽位 (索引 0-15):

| 槽位 | 用途 | 说明 |
|------|------|------|
| 0-7 | Vendor DSS 密钥 | 厂商固件签名 |
| 8-15 | Owner DSS 密钥 | 所有者固件签名 |

## 5. AST2700 A1 vs A2 FMC 差异

### 5.1 架构对比

| 特性 | AST2700 A1 | AST2700 A2 |
|------|------------|------------|
| **FMC 实现** | BootMCU 固件 | 集成在 Caliptra Manifest |
| **FMC 签名** | 必须签名 | 不需要签名 |
| **预构建组件** | 独立管理 | 打包在 Manifest 中 |
| **恢复方式** | 单独更新 BootMCU | 更新整个 Caliptra |

### 5.2 A1 FMC 镜像结构

```
┌─────────────────────────────────────────────────────────────────┐
│                      FMC 镜像文件                                │
├──────────┬──────────────┬───────────────┬───────────────────────┤
│ FMC 头   │ BootMCU 固件 │  预构建组件 1 │  预构建组件 N         │
│ (V2)     │ (Zephyr)     │  (Caliptra?)  │                       │
├──────────┴──────────────┴───────────────┴───────────────────────┤
│                                                                │
│  预构建组件列表 (在 FMC 头中引用):                              │
│  - CALIPTRA_FW (可选)                                          │
│  - SOC_MANIFEST                                                │
│  - BL31                                                        │
│  - OP_TEE                                                      │
│  - BL33 (UBOOT)                                                │
│  - DDR_PREBUILT                                                │
│                                                                │
└─────────────────────────────────────────────────────────────────┘
```

### 5.3 A2 Caliptra Manifest 结构

```
┌─────────────────────────────────────────────────────────────────┐
│                  Caliptra Manifest Flash 镜像                    │
├──────────────┬──────────────┬──────────────────────────────────┤
│  Manifest    │ Caliptra FW  │  其他组件 (打包在一起)            │
│  Header      │              │                                  │
├──────────────┴──────────────┴──────────────────────────────────┤
│                                                                │
│  包含的组件:                                                   │
│  - MCU Runtime (原 BootMCU FMC)                                │
│  - Caliptra SoC Manifest                                       │
│  - ARM Trusted Firmware (BL31)                                 │
│  - OP-TEE OS                                                   │
│  - U-Boot Raw Image                                            │
│  - DDR4/DDR5 Pre-built Images                                  │
│  - SSP/TSP Firmware (可选)                                     │
│                                                                │
└─────────────────────────────────────────────────────────────────┘
```

## 6. fmc-imgtool 使用

### 6.1 基础用法

```bash
# 生成 FMC 镜像 (无签名)
fmc-imgtool \
    --version 2 \
    --input fmc_raw.bin \
    --output fmc.bin

# 生成带签名的 FMC 镜像
fmc-imgtool \
    --version 2 \
    --input fmc_raw.bin \
    --output fmc.bin \
    --ecc-key pri.pem \
    --ecc-key-index 0

# 生成带预构建组件的 FMC 镜像
fmc-imgtool \
    --version 2 \
    --input fmc_raw.bin \
    --output fmc.bin \
    --prebuilt-dir bmc-pb/ast2700a1/ \
    --ecc-key pri.pem \
    --ecc-key-index 0
```

### 6.2 LMS 签名支持

```bash
# 使用 ECDSA384 + LMS 签名
fmc-imgtool \
    --version 2 \
    --input fmc_raw.bin \
    --output fmc.bin \
    --ecc-key ecc-pri.pem \
    --ecc-key-index 0 \
    --lms-key lms-prv.prv \
    --lms-key-index 0
```

### 6.3 预构建目录结构

```
bmc-pb/ast2700a1/
├── caliptra-fw.bin          # PrebuiltType.CALIPTRA_FW
├── soc-manifest.bin         # PrebuiltType.SOC_MANIFEST
├── bl31.bin                 # PrebuiltType.BL31
├── tee.bin                  # PrebuiltType.OP_TEE
├── u-boot.bin               # PrebuiltType.BL33
├── ddr-prebuilt.bin         # PrebuiltType.DDR_PREBUILT
├── ssp-fw.bin               # PrebuiltType.SSP_FW
└── tsp-fw.bin               # PrebuiltType.TSP_FW
```

## 7. 安全考虑

### 7.1 签名密钥管理

| 密钥类型 | 存储位置 | 用途 |
|----------|----------|------|
| Root Key Hash | OTP | BootROM 验证 FMC |
| ECC 私钥 | 安全存储 | 签名 FMC |
| LMS 私钥 | 安全存储 | 签名 FMC (可选) |

### 7.2 安全版本号 (SVN)

FMC 镜像包含安全版本号，用于防止降级攻击:

```python
fmc_info.svn = fmc_svn  # 安全版本号
```

### 7.3 摘要验证

每个组件的摘要通过 SHA-384 计算:

```python
fmc_info.dgst = hashlib.sha384(fmc_info.data).digest()  # 384-bit
```

## 8. 故障排查

### 8.1 常见错误

| 错误信息 | 原因 | 解决方案 |
|----------|------|----------|
| `cannot find fmc binary` | FMC 文件路径错误 | 检查 `--input` 参数 |
| `cannot find prebuilt binary` | 预构建文件缺失 | 检查 `--prebuilt-dir` |
| `signature verification failed` | 签名不匹配 | 检查密钥和签名 |
| `size exceeds` | 固件过大 | 检查 Flash 分区大小 |

### 8.2 调试方法

```bash
# 启用详细输出
fmc-imgtool --verbose ...

# 验证镜像
fmc-imgtool --verify --input fmc.bin
```

## 9. 参考文件

### 9.1 源代码

| 文件 | 路径 | 说明 |
|------|------|------|
| main.py | `fmc_imgtool/main.py` | FMC 工具主程序 |
| hdr_v2.py | `fmc_imgtool/hdr_v2.py` | FMCv2 头定义 |
| prebuilt.py | `fmc_imgtool/prebuilt.py` | 预构建组件定义 |

### 9.2 配置文件

| 文件 | 路径 | 说明 |
|------|------|------|
| bootmcu-spl.inc | `meta-aspeed-sdk/recipes-bsp/bootmcu/` | BootMCU 构建配置 |
| zephyr-aspeed-bootmcu_git.bb | `meta-aspeed-sdk/dynamic-layers/zephyrcore-layer/` | Zephyr BootMCU |
| image_types_phosphor_aspeed_g7.bbclass | `meta-aspeed-sdk/classes/` | Flash 布局 |

## 10. 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| 1.0 | 2024-12-11 | 初始版本 |
| 2.0 | 2025-06-09 | 更新 A1/A2 差异，添加 fmc-imgtool 详细说明 |