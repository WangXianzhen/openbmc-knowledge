# AST2700 FIT 镜像配置

## 1. FIT 镜像概述

### 1.1 什么是 FIT 镜像

FIT (Flattened Image Tree) 是 U-Boot 的一种镜像格式，用于打包多个组件（内核、设备树、ramdisk等）到一个单一镜像中，支持签名验证和安全启动。

### 1.2 AST2700 FIT 镜像组成

```
FIT Image
├── images
│   ├── fip         # ARM Trusted Firmware (BL31)
│   ├── tee         # OP-TEE OS (BL32)
│   ├── sspfw       # Secure Sub-System Firmware (Zephyr)
│   ├── tspfw       # Trusted Subsystem Firmware (Zephyr)
│   ├── ibexfw      # iBEX Firmware (RISC-V)
│   ├── kernel      # Linux Kernel (zImage/Image)
│   └── fdt         # Flattened Device Tree
└── configurations
    └── conf@1      # 默认启动配置
```

## 2. Yocto/BitBake 配置

### 2.1 相关文件位置

| 文件 | 路径 | 用途 |
|------|------|------|
| bbappend | `meta-aspeed-sdk/recipes-kernel/linux/linux-yocto-fitimage.bbappend` | FIT 镜像配方扩展 |
| bbclass | `poky/meta/classes-recipe/kernel-fit-image.bbclass` | FIT 镜像构建类 |
| bbclass | `poky/meta/classes-recipe/kernel-fit-extra-artifacts.bbclass` | 额外产物类 |

### 2.2 配方文件内容

```bitbake
# meta-aspeed-sdk/recipes-kernel/linux/linux-yocto-fitimage.bbappend
DEPENDS += "${@bb.utils.contains('MACHINE_FEATURES', 'ast-secure', 'aspeed-secure-config-native', '', d)}"
```

## 3. Machine 配置中的 FIT 设置

### 3.1 核心 FIT 配置 (ast2700-sdk.inc)

```bitbake
# Bootloader FIT 配置
UBOOT_FIT_UBOOT_ENTRYPOINT ?= "0x80000000"
UBOOT_FIT_UBOOT_LOADADDRESS ?= "0x80000000"
UBOOT_FIT_ARM_TRUSTED_FIRMWARE_LOADADDRESS ?= "0xb0000000"
UBOOT_FIT_ARM_TRUSTED_FIRMWARE_ENTRYPOINT ?= "0xb0000000"
UBOOT_FIT_TEE_LOADADDRESS ?= "0xb0080000"
UBOOT_FIT_TEE_ENTRYPOINT ?= "0xb0080000"

# SSP 配置
UBOOT_FIT_SSP_ARCH ?= "arm"
UBOOT_FIT_SSP_OS ?= "zephyr"
UBOOT_FIT_SSP_LOADADDRESS ?= "0xac000000"
UBOOT_FIT_SSP_ENTRYPOINT ?= "0xac000000"

# TSP 配置
UBOOT_FIT_TSP_ARCH ?= "arm"
UBOOT_FIT_TSP_OS ?= "zephyr"
UBOOT_FIT_TSP_LOADADDRESS ?= "0xae000000"
UBOOT_FIT_TSP_ENTRYPOINT ?= "0xae000000"

# iBEX Firmware 配置
UBOOT_FIT_IBEXFW_ARCH ?= "riscv"
UBOOT_FIT_IBEXFW_OS ?= "zephyr"
UBOOT_FIT_IBEXFW_LOADADDRESS ?= "0x14ba8000"
UBOOT_FIT_IBEXFW_ENTRYPOINT ?= "0x14ba8000"

# Kernel FIT 配置
# 使用 lzma 压缩节省空间
FIT_KERNEL_COMP_ALG ?= "lzma"
FIT_KERNEL_COMP_ALG_EXTENSION ?= ".lzma"

FIT_ADDRESS_CELLS ?= "2"
UBOOT_ENTRYPOINT ?= "0x4 0x00000000"
UBOOT_LOADADDRESS ?= "0x4 0x00000000"

# 镜像源
UBOOT_FIT_ARM_TRUSTED_FIRMWARE_IMAGE ?= "${DEPLOY_DIR_IMAGE}/${TFA_BUILD_TARGET}.bin"
UBOOT_FIT_TEE_IMAGE ?= "${DEPLOY_DIR_IMAGE}/optee/tee-raw.bin"
UBOOT_FIT_SSP_IMAGE ?= "${DEPLOY_DIR_IMAGE}/zephyr-aspeed-ssp.bin"
UBOOT_FIT_TSP_IMAGE ?= "${DEPLOY_DIR_IMAGE}/zephyr-aspeed-tsp.bin"
UBOOT_FIT_IBEXFW_IMAGE ?= "${DEPLOY_DIR_IMAGE}/zephyr-aspeed-ibexfw.bin"
```

### 3.2 启用组件

```bitbake
# ast-arm-trusted-firmware-a.inc
UBOOT_FIT_ARM_TRUSTED_FIRMWARE = "1"

# ast-optee-os.inc
UBOOT_FIT_TEE = "1"

# ast-ssp.inc
UBOOT_FIT_CONF_USER_LOADABLES:append:aspeed-g7 = ' ,"sspfw"'

# ast-tsp.inc
UBOOT_FIT_CONF_USER_LOADABLES:append = ' ,"tspfw"'
```

### 3.3 Kernel 类配置

```bitbake
# aspeed-sdk.inc
KERNEL_CLASSES ?= "kernel-fit-extra-artifacts"
KERNEL_IMAGETYPE ?= "zImage"
KERNEL_IMAGETYPE:aarch64 ?= "Image"
KERNEL_IMAGETYPES:aarch64 ?= "Image"
INITRAMFS_IMAGE ?= "aspeed-image-initramfs"
INITRAMFS_FSTYPES ?= "cpio.xz"
```

## 4. 安全启动配置

### 4.1 Chain of Trust 配置 (ast2700-secure-cot.inc)

```bitbake
# U-Boot 签名启用
UBOOT_SIGN_ENABLE ?= "1"
UBOOT_SIGN_KEYDIR ?= "${STAGING_DATADIR_NATIVE}/aspeed-secure-config/ast2700/keys"

# 默认密钥
UBOOT_SIGN_KEYNAME ?= "test_bl3_ecdsa_secp384r1"

# Kernel FIT 签名配置
FIT_HASH_ALG ?= "sha384"
FIT_SIGN_ALG ?= "ecdsa384"
FIT_SIGN_NUMBITS ?= "384"
```

### 4.2 安全模式配置

```bitbake
# ast2700-secure-mode.inc (A2 芯片)
# 算法: ecdsa384-lms (默认)

# ecdsa384 模式
OTPTOOL_CONFIGS ?= "${STAGING_DATADIR_NATIVE}/aspeed-secure-config/ast2700/otp/2700A2_ECDSA384.json"
CALIPTRA_MANIFEST_CONFIG ?= "ast2700-default-ecc-manifest.toml"

# ecdsa384-lms 模式 (量子抗性)
OTPTOOL_CONFIGS ?= "${STAGING_DATADIR_NATIVE}/aspeed-secure-config/ast2700/otp/2700A2_ECDSA384_LMS.json"
CALIPTRA_MANIFEST_CONFIG ?= "ast2700-default-ecc-lms-manifest.toml"
```

```bitbake
# ast2700a1-secure-mode.inc (A1 芯片)
# FMC 签名
FMC_SIGN_ENABLE ?= "1"
FMC_KEY_DIR ?= "${STAGING_DATADIR_NATIVE}/aspeed-secure-config/ast2700/keys"
FMC_ECC_KEY ?= "${FMC_KEY_DIR}/test_oem_dss_private_key_ecdsa384_1.pem"
FMC_ECC_KEY_INDEX ?= "1"
FMC_LMS_KEY ?= "${FMC_KEY_DIR}/test_oem_dss_lms_key_1.prv"
FMC_LMS_KEY_INDEX ?= "1"
```

### 4.3 支持的签名算法

| 算法 | 椭圆曲线 | 哈希 | LMS | 说明 |
|------|----------|------|-----|------|
| `ecdsa384` | ECDSA P-384 | SHA-384 | 否 | 基本安全启动 |
| `ecdsa384-lms` | ECDSA P-384 + LMS | SHA-384 | 是 | 增强安全 (量子抗性) |

## 5. FIT 镜像结构示例

### 5.1 ITS (Image Tree Source) 格式

```dts
/dts-v1/;

/ {
    description = "AST2700 FIT Image";
    #address-cells = <2>;

    images {
        fip@0 {
            description = "ARM Trusted Firmware";
            data = /incbin/("bl31.bin");
            type = "firmware";
            arch = "arm64";
            os = "arm-trusted-firmware";
            load = <0x0 0xb0000000>;
            entry = <0x0 0xb0000000>;
            compression = "none";
        };

        tee@1 {
            description = "OP-TEE OS";
            data = /incbin/("tee.bin");
            type = "tee";
            arch = "arm64";
            os = "op-tee";
            load = <0x0 0xb0080000>;
            entry = <0x0 0xb0080000>;
            compression = "none";
        };

        kernel@2 {
            description = "Linux Kernel";
            data = /incbin/("Image.lzma");
            type = "kernel";
            arch = "arm64";
            os = "linux";
            load = <0x0 0x40000000>;
            entry = <0x0 0x40000000>;
            compression = "lzma";
            hash@1 {
                algo = "sha384";
            };
        };

        fdt@3 {
            description = "Flattened Device Tree";
            data = /incbin/("ast2700-evb.dtb");
            type = "flat_dt";
            arch = "arm64";
            compression = "none";
            load = <0x0 0x43000000>;
        };

        sspfw@4 {
            description = "SSP Firmware";
            data = /incbin/("ssp.bin");
            type = "firmware";
            arch = "arm";
            os = "zephyr";
            load = <0x0 0xac000000>;
            entry = <0x0 0xac000000>;
            compression = "none";
        };
    };

    configurations {
        default = "conf@1";
        conf@1 {
            description = "Default Linux boot";
            firmware = "fip@0";
            tee = "tee@1";
            kernel = "kernel@2";
            fdt = "fdt@3";
            loadables = "sspfw@4";
            signature@1 {
                algo = "sha384,ecdsa384";
                key-name-hint = "test_bl3_ecdsa_secp384r1";
            };
        };
    };
};
```

## 6. 镜像偏移和布局

### 6.1 闪存布局

| 区域 | 偏移 (KB) | 大小 (KB) | 说明 |
|------|-----------|-----------|------|
| U-Boot + FIT | 0 | 4096 | 包含 U-Boot 和 bootloader FIT |
| Kernel | 4224 | ~9216 | 内核镜像区域 |
| ROFS | 13440 | ~84924 | 只读根文件系统 |
| RWFS | 98304 | 32768 | 读写数据区 |

### 6.2 组件加载地址

| 组件 | 加载地址 | 入口地址 | 说明 |
|------|----------|----------|------|
| U-Boot | 0x80000000 | 0x80000000 | DDR 起始 |
| ATF (BL31) | 0xB0000000 | 0xB0000000 | 信任固件 |
| OP-TEE (BL32) | 0xB0080000 | 0xB0080000 | 可信执行环境 |
| Kernel | 0x40000000 | 0x40000000 | Linux 内核 |
| FDT | 0x43000000 | - | 设备树 |
| SSP | 0xAC000000 | 0xAC000000 | 安全子处理器 |
| TSP | 0xAE000000 | 0xAE000000 | 可信子系统 |
| iBEX | 0x14BA8000 | 0x14BA8000 | RISC-V 固件 |

## 7. 构建和部署

### 7.1 构建命令

```bash
# 完整构建
bitbake obmc-phosphor-image

# 仅构建 FIT 镜像
bitbake linux-yocto-fitimage

# 重新生成 FIT 镜像
bitbake linux-yocto-fitimage -c clean
bitbake linux-yocto-fitimage
```

### 7.2 构建产物位置

```
build/<machine>/tmp/deploy/images/<machine>/
├── fitImage-<initramfs>-<machine>      # 完整的 FIT 镜像
├── fitImage-<initramfs>-<machine>.its  # ITS 源文件
├── bl31.bin                             # ARM Trusted Firmware
├── tee.bin                              # OP-TEE 二进制
├── zephyr-aspeed-ssp.bin                # SSP 固件
├── zephyr-aspeed-tsp.bin                # TSP 固件
├── Image                                # ARM64 内核镜像
├── zImage                               # ARM 内核镜像
├── *.dtb                                # 设备树二进制
└── u-boot.bin                           # U-Boot 镜像
```

### 7.3 手动创建 FIT

```bash
# 1. 准备组件
mkimage -f fit-image.its fitImage

# 2. 签名 FIT 镜像
mkimage -F -f fit-image-signed.its fitImage.signed

# 3. 验证 FIT 镜像
mkimage -l fitImage
```

## 8. 调试和验证

### 8.1 U-Boot 查看 FIT 内容

```u-boot
# 列出 FIT 镜像信息
iminfo $loadaddr

# 查看 FIT 镜像结构
fit_info $loadaddr

# 列出所有配置
fit_print $loadaddr

# 验证签名
iminfo $loadaddr
```

### 8.2 Linux 查看设备树

```bash
# 查看启动参数
cat /proc/cmdline

# 查看设备树
ls -la /proc/device-tree/

# 查看模型
cat /proc/device-tree/model
```

### 8.3 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| FIT 镜像无法加载 | 偏移量错误 | 检查 U-Boot 环境变量 |
| 签名验证失败 | 密钥不匹配 | 重新配置密钥 |
| 组件加载失败 | 地址错误 | 检查 load address |
| 内核 panic | FDT 不匹配 | 使用正确的 DTB |

## 9. iROT 特殊配置

### 9.1 iROT 机器配置

```bitbake
# ast2700-irot.conf
# iROT 使用不同的闪存布局和 Caliptra manifest

# CALIPTRA Manifest
CALIPTRA_MANIFEST_CONFIG = "ast2700-irot-kernel-ecc-lms-manifest.toml"

# 内核镜像类型
KERNEL_IMAGETYPE:df-obmc-static-norootfs = "Image"
KERNEL_IMAGETYPES:df-obmc-static-norootfs = "${KERNEL_IMAGETYPE}"

# 压缩格式
FIT_KERNEL_COMP_ALG:df-obmc-static-norootfs = "gzip"
FIT_KERNEL_COMP_ALG_EXTENSION:df-obmc-static-norootfs = ".gz"

# 闪存偏移
FLASH_UBOOT_ENV_OFFSET:df-obmc-static-norootfs:flash-131072 = "4160"
FLASH_MANIFEST_OFFSET:df-obmc-static-norootfs:flash-131072 = "4096"
```

### 9.2 iROT Caliptra Manifest

iROT 使用不同的 Caliptra manifest 格式，包含:
- ATF/OPTEE/UBOOT/KERNEL/ROOTFS

## 10. 快速参考

### 10.1 关键环境变量 (U-Boot)

```u-boot
# 启动命令
setenv bootcmd "run boot_fit"

# FIT 镜像加载地址
setenv loadaddr 0x83000000

# 内核参数
setenv bootargs "console=ttyS12,115200"
```

### 10.2 签名密钥位置

```
meta-aspeed-sdk/recipes-aspeed/security/aspeed-secure-config/
└── ast2700/
    └── keys/
        ├── test_bl3_ecdsa_secp384r1.key      # U-Boot 签名密钥
        ├── test_bl3_ecdsa_secp384r1.crt      # U-Boot 证书
        ├── test_oem_dss_private_key_ecdsa384_1.pem  # OEM DSS 密钥
        └── test_oem_dss_lms_key_1.prv        # LMS 密钥
```

### 10.3 压缩算法对比

| 算法 | 压缩率 | 解压时间 | 内核支持 |
|------|--------|----------|----------|
| gzip | 中 | 快 | 原生 |
| lzma | 高 | 中 | 需启用 |
| xz | 最高 | 慢 | 需启用 |
| zstd | 高 | 很快 | 需启用 |

AST2700 默认使用 `lzma` 以平衡压缩率和兼容性。