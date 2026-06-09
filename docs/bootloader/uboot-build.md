# U-Boot 构建配置和依赖

## 1. 构建配方架构

### 1.1 配方继承关系

AST2700 U-Boot 使用分层配方设计:

```
u-boot-aspeed-sdk_2023.10.bb (主配方)
    └── u-boot-common-aspeed-sdk_2023.10.inc (源码配置)
            └── u-boot-aspeed.inc (构建逻辑)
                    └── recipes-bsp/u-boot/u-boot-configure.inc (标准配置)
```

### 1.2 配方继承链详解

```bitbake
# u-boot-aspeed-sdk_2023.10.bb
require u-boot-common-aspeed-sdk_${PV}.inc
require recipes-bsp/u-boot/u-boot-aspeed.inc
PROVIDES += "u-boot"

# 继承的类
inherit uboot-config uboot-extlinux-config uboot-sign deploy cml1 python3native
```

## 2. 源码配置

### 2.1 u-boot-common-aspeed-sdk_2023.10.inc

```bitbake
HOMEPAGE = "https://github.com/AspeedTech-BMC/u-boot"
SECTION = "bootloaders"
DEPENDS += "flex-native bison-native"

LICENSE = "GPL-2.0-or-later"
LIC_FILES_CHKSUM = "file://Licenses/README;md5=2ca5f2c35c8cc335f0a19756634782f1"

PE = "1"

# 分支和仓库
BRANCH = "aspeed-master-v2023.10"
SRC_URI = "git://github.com/AspeedTech-BMC/u-boot.git;protocol=https;branch=${BRANCH}"

# 特定提交版本
SRCREV = "b139e0526e716721e1d1be3ed0ea019aaaf079ed"

B = "${UNPACKDIR}/build"
do_configure[cleandirs] = "${B}"

# 禁用 initial-env 目标 (此版本不支持)
UBOOT_INITIAL_ENV = ""

PV = "v2023.10+git"
```

### 2.2 源码版本管理

源码版本通过 Python 函数动态计算:

```bitbake
python do_set_local_version() {
    import os
    import re
    
    # 移除现有 scmversion 文件
    s = d.getVar("S")
    b = d.getVar("B")
    
    # 获取 git 描述信息
    res = bb.process.run("git -C %s describe --tags --exact-match" % s)[0].strip()
    
    # 如果是 devtool 环境,添加额外标识
    if "devtool" in res:
        version_ext = bb.process.run("git -C %s rev-parse --verify --short HEAD" % s)[0].strip()
        scm_ver = '-%s-%s' % (res, version_ext)
    else:
        scm_ver = '-%s' % res
    
    # 生成 .scmversion 文件
    with open("%s/.scmversion" % s, "a") as f:
        f.write(scm_ver)
    
    # 提取子版本号
    match = re.search(r'[^-]*$', scm_ver)
    if match:
        sub_ver = match.group(0)
    
    with open("%s/.subversion" % s, "a") as f:
        f.write(sub_ver)
}

addtask set_local_version before do_compile after do_configure
```

## 3. 构建目标

### 3.1 编译命令

```bitbake
UBOOT_MAKE_TARGET ?= "DEVICE_TREE=${UBOOT_DEVICETREE}"

do_compile () {
    oe_runmake -C ${S} O=${B} ${UBOOT_MAKE_TARGET}
}
```

AST2700 的实际编译命令:
```bash
make evb-ast2700_defconfig DEVICE_TREE=ast2700-evb
```

### 3.2 环境变量设置

```bitbake
EXTRA_OEMAKE = 'CROSS_COMPILE=${TARGET_PREFIX} CC="${TARGET_PREFIX}gcc ${TOOLCHAIN_OPTIONS}" V=1'
EXTRA_OEMAKE += 'HOSTCC="${BUILD_CC} ${BUILD_CFLAGS} ${BUILD_LDFLAGS}"'
EXTRA_OEMAKE += 'STAGING_INCDIR=${STAGING_INCDIR_NATIVE} STAGING_LIBDIR=${STAGING_LIBDIR_NATIVE}'

PACKAGECONFIG ??= "openssl"
PACKAGECONFIG[openssl] = ",,openssl-native"
```

## 4. 配置阶段

### 4.1 配置流程

```bitbake
do_configure () {
    if [ -z "${UBOOT_CONFIG}" ]; then
        if [ -n "${UBOOT_MACHINE}" ]; then
            oe_runmake -C ${S} O=${B} ${UBOOT_MACHINE}
        else
            oe_runmake -C ${S} O=${B} oldconfig
        fi
        merge_config.sh -m .config ${@" ".join(find_cfgs(d))}
        cml1_do_configure
    fi
}
```

### 4.2 配置片段合并

通过 `merge_config.sh` 支持配置片段 (.cfg 文件):

```bitbake
def find_cfgs(d):
    sources = src_patches(d, True)
    sources_list = []
    for s in sources:
        if s.endswith('.cfg'):
            sources_list.append(s)
    return sources_list
```

### 4.3 配置更新追踪

```bitbake
do_applyconfig () {
    if [ -e ${B}/.config -a -e ${B}/.config.orig ]; then
        sum1=$(md5sum ${B}/.config | cut -d' ' -f1)
        sum2=$(md5sum ${B}/.config.orig | cut -d' ' -f1)
        if [ ${sum1} != ${sum2} ]; then
            diff ... ${B}/.config.orig ${B}/.config > ${B}/fragment.cfg
            merge_config.sh -m ${S}/configs/${UBOOT_MACHINE} ${B}/fragment.cfg
            mv .config ${S}/configs/${UBOOT_MACHINE}
            cp -f ${B}/.config ${B}/.config.orig
        fi
    fi
}

addtask do_applyconfig
```

## 5. 编译阶段

### 5.1 编译流程

```bitbake
do_compile () {
    # 禁用 gold linker (如启用)
    if [ "${@bb.utils.filter('DISTRO_FEATURES', 'ld-is-gold', d)}" ]; then
        sed -i 's/$(CROSS_COMPILE)ld$/$(CROSS_COMPILE)ld.bfd/g' ${S}/config.mk
    fi
    
    # 清除环境变量
    unset LDFLAGS CFLAGS CPPFLAGS
    
    # 生成版本文件
    if [ ! -e ${B}/.scmversion -a ! -e ${S}/.scmversion ]; then
        echo ${UBOOT_LOCALVERSION} > ${B}/.scmversion
        echo ${UBOOT_LOCALVERSION} > ${S}/.scmversion
    fi
    
    # 执行编译
    oe_runmake -C ${S} O=${B} ${UBOOT_MAKE_TARGET}
}
```

### 5.2 环境变量生成

编译后自动生成 U-Boot 环境变量镜像:

```bitbake
do_compile:append() {
    if [ -n "${UBOOT_ENV}" ]; then
        ${B}/tools/mkenvimage -s ${UBOOT_ENV_SIZE} \
            -o ${B}/${UBOOT_ENV_BINARY} \
            ${UNPACKDIR}/${UBOOT_ENV_TXT}
    fi
}
```

## 6. 安装和部署

### 6.1 安装阶段

```bitbake
do_install () {
    install -d ${D}/boot
    install -m 644 ${B}/${UBOOT_BINARY} ${D}/boot/${UBOOT_IMAGE}
    ln -sf ${UBOOT_IMAGE} ${D}/boot/${UBOOT_BINARY}
    
    # 安装 U-Boot 环境
    if [ -n "${UBOOT_ENV}" ]; then
        install -m 644 ${B}/${UBOOT_ENV_BINARY} ${D}/boot/${UBOOT_ENV_IMAGE}
        ln -sf ${UBOOT_ENV_IMAGE} ${D}/boot/${UBOOT_ENV_BINARY}
    fi
    
    # 安装 fw_env.config
    if [ -e ${UNPACKDIR}/fw_env.config ]; then
        install -d ${D}${sysconfdir}
        install -m 644 ${UNPACKDIR}/fw_env.config ${D}${sysconfdir}/fw_env.config
    fi
}
```

### 6.2 部署阶段

```bitbake
do_deploy () {
    install -d ${DEPLOYDIR}
    install -m 644 ${B}/${UBOOT_BINARY} ${DEPLOYDIR}/${UBOOT_IMAGE}
    install -m 644 ${B}/${UBOOT_BINARY} ${DEPLOYDIR}/${UBOOT_IMAGE}-${sub_ver}
    
    # 创建符号链接
    cd ${DEPLOYDIR}
    rm -f ${UBOOT_BINARY} ${UBOOT_SYMLINK}
    ln -sf ${UBOOT_IMAGE} ${UBOOT_SYMLINK}
    ln -sf ${UBOOT_IMAGE} ${UBOOT_BINARY}
    
    # 部署 U-Boot 环境
    if [ -n "${UBOOT_ENV}" ]; then
        install -m 644 ${B}/${UBOOT_ENV_BINARY} ${DEPLOYDIR}/${UBOOT_ENV_IMAGE}
        rm -f ${DEPLOYDIR}/${UBOOT_ENV_BINARY} ${DEPLOYDIR}/${UBOOT_ENV_SYMLINK}
        ln -sf ${UBOOT_ENV_IMAGE} ${DEPLOYDIR}/${UBOOT_ENV_BINARY}
        ln -sf ${UBOOT_ENV_IMAGE} ${DEPLOYDIR}/${UBOOT_ENV_SYMLINK}
    fi
}

addtask deploy before do_build after do_compile
```

## 7. 依赖关系

### 7.1 构建依赖

| 依赖项 | 类型 | 用途 |
|--------|------|------|
| flex-native | buildtools | 词法分析器生成 |
| bison-native | buildtools | 语法分析器生成 |
| bc-native | buildtools | 引导脚本计算器 |
| dtc-native | buildtools | 设备树编译 |
| openssl-native | 可选 | 签名工具 |
| kern-tools-native | 工具 | 内核工具 |
| swig-native | 工具 | 脚本绑定 |
| aspeed-secure-config-native | 可选 | 安全配置生成 |

### 7.2 运行时依赖

```bitbake
PACKAGE_BEFORE_PN += "${PN}-env"
RPROVIDES:${PN}-env += "u-boot-default-env"
RDEPENDS:${PN} += "${PN}-env"
ALLOW_EMPTY:${PN}-env = "1"
```

### 7.3 安全特性依赖

```bitbake
# 当启用 ast-secure 功能时的条件依赖
DEPENDS += "${@bb.utils.contains('MACHINE_FEATURES', 'ast-secure', 'aspeed-secure-config-native', '', d)}"
```

## 8. 多配置构建支持

### 8.1 UBOOT_CONFIG 变体

```bitbake
# 支持多配置构建
UBOOT_CONFIG = "emmc ramdisk"
UBOOT_MACHINE = "evb-ast2700_defconfig evb-ast2700_defconfig"
UBOOT_BINARIES = "u-boot.bin u-boot.bin"
UBOOT_SUFFIX = "bin"
```

### 8.2 编译循环

```bitbake
for config in ${UBOOT_MACHINE}; do
    i=$(expr $i + 1)
    for type in ${UBOOT_CONFIG}; do
        j=$(expr $j + 1)
        if [ $j -eq $i ]; then
            oe_runmake -C ${S} O=${B}/${config} ${config}
            oe_runmake -C ${S} O=${B}/${config} ${UBOOT_MAKE_TARGET}
            # 处理二进制文件
        fi
    done
done
```

## 9. fw-utils 工具

### 9.1 u-boot-fw-utils 配方

```bitbake
require u-boot-common-aspeed-sdk_${PV}.inc
require recipes-bsp/u-boot/u-boot-configure.inc

SUMMARY = "U-Boot bootloader fw_printenv/setenv utilities"
DEPENDS += "mtd-utils"

PROVIDES += "u-boot-fw-utils"
RPROVIDES:${PN} += "u-boot-fw-utils"

INSANE_SKIP:${PN} = "already-stripped"

EXTRA_OEMAKE:class-target = 'CROSS_COMPILE=${TARGET_PREFIX} CC="${CC} ${CFLAGS} ${LDFLAGS}" HOSTCC="${BUILD_CC} ${BUILD_CFLAGS} ${BUILD_LDFLAGS}" V=1'
EXTRA_OEMAKE:class-cross = 'HOSTCC="${CC} ${CFLAGS} ${LDFLAGS}" V=1'
```

### 9.2 fw_printenv/setenv 工具

```bitbake
do_compile () {
    oe_runmake envtools
}

do_install () {
    install -d ${D}${base_sbindir}
    install -m 755 ${B}/tools/env/fw_printenv ${D}${base_sbindir}/fw_printenv
    ln -sf fw_printenv ${D}${base_sbindir}/fw_setenv
    
    install -d ${D}${sysconfdir}
    install -m 644 ${UNPACKDIR}/${ENV_CONFIG_FILE} ${D}${sysconfdir}/fw_env.config
}
```

## 10. 交叉编译支持

```bitbake
BBCLASSEXTEND = "cross"
SYSROOT_DIRS:append:class-cross = " ${bindir_cross}"

do_install:class-cross () {
    install -d ${D}${bindir_cross}
    install -m 755 ${B}/tools/env/fw_printenv ${D}${bindir_cross}/fw_printenv
    ln -sf fw_printenv ${D}${bindir_cross}/fw_setenv
}
```

## 11. 构建产物

### 11.1 产出文件

| 文件 | 路径 | 说明 |
|------|------|------|
| u-boot.bin | ${DEPLOYDIR}/ | 主 U-Boot 镜像 |
| u-boot-env.bin | ${DEPLOYDIR}/ | U-Boot 环境变量 |
| fw_printenv | /usr/sbin/ | 环境变量读取工具 |
| fw_setenv | /usr/sbin/ | 环境变量写入工具 |
| fw_env.config | /etc/ | 环境变量配置 |

### 11.2 符号链接结构

```
${DEPLOYDIR}/
├── u-boot.bin (→ u-boot.bin-v2023.10+git-r0)
├── u-boot (→ u-boot.bin-v2023.10+git)
├── u-boot-env.bin (→ u-boot-env.bin-v2023.10+git)
└── u-boot-env (→ u-boot-env.bin-v2023.10+git)
```

## 12. 构建命令示例

### 12.1 构建 U-Boot

```bash
# 方式 1: 通过 bitbake 构建
bitbake u-boot-aspeed-sdk

# 方式 2: 完整镜像构建 (包含 U-Boot)
bitbake obmc-phosphor-image
```

### 12.2 清理构建

```bash
# 清理 U-Boot 构建
bitbake u-boot-aspeed-sdk -c clean

# 完全清理 (重新解压和编译)
bitbake u-boot-aspeed-sdk -c cleansstate
```

### 12.3 开发模式

```bash
# 打开开发 shell
bitbake u-boot-aspeed-sdk -c devshell
```

## 13. 与前代版本的差异

| 特性 | AST2500/2600 | AST2700 |
|------|--------------|---------|
| 配方版本 | 2019.04 | 2023.10 |
| 构建目录 | ${S}/build | ${UNPACKDIR}/build |
| 初始环境 | u-boot-initial-env | 禁用 |
| 签名类 | - | uboot-sign |
| ECDSA FDT 支持 | 无 | 有 (补丁) |