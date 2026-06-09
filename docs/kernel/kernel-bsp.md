# AST2700 Linux Kernel BSP 概述

## 1. 内核源码管理

### 1.1 内核源码仓库

| 配置项 | 值 |
|--------|-----|
| 源码仓库 | `git://github.com/AspeedTech-BMC/linux.git` |
| 协议 | HTTPS |
| 分支模式 | `aspeed-master-vX.XX` (版本相关) |

### 1.2 内核版本配置

| 版本 | 分支 | Tag | 配置文件 |
|------|------|-----|----------|
| **6.18** | `aspeed-master-v6.18` | `v00.08.02` | `linux-aspeed_6.18.bb` |
| **6.12** | `aspeed-master-v6.12` | `v00.07.03` | `linux-aspeed_6.12.bb` |
| **6.6** | `aspeed-master-v6.6` | `v00.06.12` | `linux-aspeed_6.6.bb` |
| **5.15** | `aspeed-master-v5.15` | `v00.05.20` | `linux-aspeed_5.15.bb` |

### 1.3 BitBake 配方文件结构

```
meta-aspeed-sdk/recipes-kernel/linux/
├── linux-aspeed.inc           # 共享配置
├── linux-aspeed_5.15.bb       # 5.15 内核配方
├── linux-aspeed_6.6.bb        # 6.6 内核配方
├── linux-aspeed_6.12.bb       # 6.12 内核配方
├── linux-aspeed_6.18.bb       # 6.18 内核配方
└── linux-yocto-fitimage.bbappend  # FIT 镜像配置
```

### 1.4 共享配置 (linux-aspeed.inc)

**关键配置项:**

```bitbake
DESCRIPTION = "Linux kernel for Aspeed"
LICENSE = "GPL-2.0-only"
PROVIDES += "virtual/kernel"
KCONFIG_MODE = "--alldefconfig"
KERNEL_VERSION_SANITY_SKIP = "1"

KSRC = "git://github.com/AspeedTech-BMC/linux.git;protocol=https;branch=${KBRANCH}"
PV = "${LINUX_VERSION}+git"
inherit kernel
require recipes-kernel/linux/linux-yocto.inc
```

**本地版本生成:**

配方包含 `do_set_local_version` 任务，使用 git tag 生成版本字符串：

```python
# 使用 git describe --tags --exact-match 获取 tag
# 格式: CONFIG_LOCALVERSION="-v00.08.02"
```

## 2. 交叉编译配置

### 2.1 架构配置

| 配置项 | 值 |
|--------|-----|
| 架构 | `arm64` (ARMv8 64-bit) |
| 默认 tune | `cortexa35` |
| SOC 系列 | `aspeed-g7` |

### 2.2 Machine 配置文件继承链

```
ast2700-default.conf (或 ast2700-a1.conf)
├── ast2700-sdk.inc
│   ├── soc-family.inc
│   ├── aspeed-sdk.inc
│   ├── ast-arm-trusted-firmware-a.inc
│   ├── ast-bootmcu.inc
│   └── ast-optee-os.inc
├── ast2700-secure-customize-gen.inc
└── obmc-bsp-common.inc
```

### 2.3 内核构建变量

| 变量 | 说明 | 示例值 |
|------|------|--------|
| `KERNEL_DEVICETREE` | 设备树文件 | `aspeed/ast2700-evb.dtb` |
| `KBUILD_DEFCONFIG` | 默认配置文件 | `aspeed_g7_defconfig` |
| `KERNEL_IMAGETYPE` | 内核镜像类型 | `zImage` (ARM) / `Image` (ARM64) |
| `PREFERRED_PROVIDER_virtual/kernel` | 内核提供者 | `linux-aspeed` |

## 3. 硬件支持配置

### 3.1 AST2700 芯片特性

| 特性 | 配置 | 说明 |
|------|------|------|
| SoC Family | `CONFIG_ARCH_ASPEED` | Aspeed 架构支持 |
| 芯片型号 | `CONFIG_MACH_ASPEED_G7` | AST2700 (G7) |
| 多核支持 | `CONFIG_SMP=y`, `CONFIG_NR_CPUS=2` | 双核 Cortex-A35 |
| VMSPLIT | `CONFIG_VMSPLIT_2G` | 2G/2G 虚拟地址分割 |
| 高内存 | `CONFIG_HIGHMEM=y` | 支持高位内存映射 |

### 3.2 关键内核配置选项

```bash
# 架构和芯片
CONFIG_ARCH_ASPEED=y
CONFIG_MACH_ASPEED_G7=y
CONFIG_SMP=y
CONFIG_NR_CPUS=2
CONFIG_HIGHMEM=y

# 压缩格式
CONFIG_KERNEL_XZ=y

# ARM 特性
CONFIG_VFP=y
CONFIG_NEON=y
CONFIG_KERNEL_MODE_NEON=y
```

## 4. 设备树覆盖配置

### 4.1 Machine 特定设备树

| Machine | 设备树 | Defconfig |
|---------|--------|-----------|
| `ast2700-default` | `aspeed/ast2700-evb.dtb` | `aspeed_g7_defconfig` |
| `ast2700-a1` | `aspeed/ast2700a1-evb.dtb` | `aspeed_g7_defconfig` |
| `ast2700-rtos` | `aspeed/ast2700-evb.dtb` | `defconfig` (通用) |
| `ast2700-irot` | `aspeed/ast2700-irot.dtb` | `aspeed_g7_defconfig` |
| `ast2700-emmc` | `aspeed/ast2700-evb.dtb` | `aspeed_g7_defconfig` |
| `ast2700-ufs` | `aspeed/ast2700-evb.dtb` | `aspeed_g7_defconfig` |

### 4.2 内核版本覆盖

| 配置文件 | 覆盖版本 |
|----------|----------|
| `ast2700-default-612.conf` | 6.12+ |
| `ast2700-default-66.conf` | 6.6+ |
| `ast2700-a1-612.conf` | 6.12+ |
| `ast2700-a1-66.conf` | 6.6+ |

## 5. 安全启动配置

### 5.1 安全模式 include 文件

```
meta-ast2700-sdk/conf/machine/include/
├── ast2700-secure-cot.inc          # Chain of Trust 配置
├── ast2700-secure-mode.inc         # A2 芯片安全模式
├── ast2700a1-secure-mode.inc       # A1 芯片安全模式
└── ast2700-secure-customize-gen.inc
```

### 5.2 FIT 镜像签名配置

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `FIT_HASH_ALG` | `sha384` | 哈希算法 |
| `FIT_SIGN_ALG` | `ecdsa384` | 签名算法 |
| `FIT_SIGN_NUMBITS` | `384` | 密钥位数 |
| `UBOOT_SIGN_ENABLE` | `1` | 启用签名 |
| `UBOOT_SIGN_KEYNAME` | `test_bl3_ecdsa_secp384r1` | 默认密钥名 |

### 5.3 支持的签名模式

| 模式 | 算法 | 量子抗性 |
|------|------|----------|
| `ecdsa384` | ECDSA P-384 + SHA-384 | 否 |
| `ecdsa384-lms` | ECDSA P-384 + SHA-384 + LMS | 是 (LMS) |

## 6. 内核模块配置

### 6.1 动态加载配置 (cfg 文件)

| 配置文件 | 功能 | CONFIG 选项 |
|----------|------|-------------|
| `ipmi_ssif.cfg` | IPMI SSIF 驱动 | `CONFIG_IPMI_SSIF=m` |
| `mtd_test.cfg` | MTD 测试模块 | `CONFIG_MTD_TESTS=m` |
| `crpyto_manager.cfg` | 加密管理器 | `CONFIG_CRYPTO_MANAGER=y` |
| `mctp_ipc.cfg` | MCTP IPC 传输 | `CONFIG_MCTP_TRANSPORT_ASPEED_MBOX=y` |

### 6.2 Vendor 特定配置

| 路径 | 配置内容 |
|------|----------|
| `meta-ibm/recipes-kernel/linux/linux-aspeed/ibm-enterprise.cfg` | IBM Enterprise 服务器 |
| `meta-amd/recipes-kernel/linux/linux-aspeed/daytonax.cfg` | AMD DaytonaX |
| `meta-aspeed-sdk/meta-ast2700-sdk/.../mctp_ipc.cfg` | AST2700 MCTP |

## 7. 闪存布局与内核偏移

### 7.1 标准布局 (128MB Flash)

| 区域 | 偏移 (KB) | 大小 (KB) | 说明 |
|------|-----------|-----------|------|
| U-Boot | 0 | 4096 | 包含环境变量 |
| Kernel | 4224 | ~9216 | 内核镜像区域 |
| ROFS | 13440 | ~84924 | 只读根文件系统 |
| RWFS | 98304 | 32768 | 读写数据区 |

### 7.2 RTOS 布局

| 区域 | 偏移 (KB) | 大小 (KB) |
|------|-----------|-----------|
| RTOS_IMAGE | 0 | 4096 |
| ATF | 2048 | - |
| U-Boot | 2112 | - |
| TEE | 3136 | - |

## 8. 编译依赖

### 8.1 Build 依赖

```bitbake
DEPENDS += "lzop-native"
```

### 8.2 QA 配置

```bitbake
ERROR_QA:remove = "buildpaths"
WARN_QA:append = "buildpaths"
```

### 8.3 版本推荐

| 组件 | 推荐版本 |
|------|----------|
| Zephyr SDK | 0.16.9 |
| Zephyr Kernel | 3.7.0 |

## 9. 快速参考

### 9.1 构建命令

```bash
# 设置环境
cd openbmc
source setup ast2700-default

# 编译内核
bitbake linux-aspeed -c compile
bitbake linux-aspeed -c deploy

# 完整镜像构建
bitbake obmc-phosphor-image
```

### 9.2 内核配置修改

```bash
# 打开配置菜单
bitbake linux-aspeed -c menuconfig

# 查看当前配置
bitbake linux-aspeed -c diffconfig
```

### 9.3 设备树编译

```bash
# 编译特定 DTB
bitbake linux-aspeed -c compile_its

# 查看设备树源位置
# 通常在 linux-aspeed 源码的 arch/arm64/boot/dts/aspeed/ 目录
```