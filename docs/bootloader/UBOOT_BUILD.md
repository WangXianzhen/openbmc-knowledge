# U-Boot Build System Documentation

## Overview

The U-Boot build system uses BitBake (from OpenEmbedded) for cross-compilation. The build is configured through recipe files in `meta-aspeed-sdk/recipes-bsp/u-boot/`.

## Recipe Files

### Primary Recipes

| File | Version | Purpose |
|------|---------|---------|
| `u-boot-aspeed-sdk_2019.04.bb` | 2019.04 | Legacy U-Boot for AST2500 |
| `u-boot-aspeed-sdk_2023.10.bb` | 2023.10 | Current U-Boot for AST2600/2700 |
| `u-boot-fw-utils-aspeed-sdk_*.bb` | - | U-Boot firmware utilities |
| `bootmcu-spl_2023.10.bb` | 2023.10 | BootMCU/RISC-V SPL |

### Include Files

| File | Purpose |
|------|---------|
| `u-boot-aspeed.inc` | Common U-Boot build logic |
| `u-boot-common-aspeed-sdk_2023.10.inc` | 2023.10-specific settings |
| `u-boot-common-aspeed-sdk_2019.04.inc` | 2019.04-specific settings |
| `bootmcu-spl.inc` | BootMCU build logic |

## Recipe Structure

### `u-boot-aspeed-sdk_2023.10.bb`

```bitbake
require u-boot-common-aspeed-sdk_${PV}.inc

UBOOT_MAKE_TARGET ?= "DEVICE_TREE=${UBOOT_DEVICETREE}"

require recipes-bsp/u-boot/u-boot-aspeed.inc

PROVIDES += "u-boot"
DEPENDS += "bc-native dtc-native"
DEPENDS += "${@bb.utils.contains('MACHINE_FEATURES', 'ast-secure', \
            'aspeed-secure-config-native', '', d)}"

# Environment configuration for eMMC
UBOOT_ENV_SIZE:ast-mmc = "0x20000"
UBOOT_ENV:ast-mmc = "u-boot-env"
UBOOT_ENV_SUFFIX:ast-mmc = "bin"
UBOOT_ENV_TXT:ast-mmc = "u-boot-env.txt"

# Environment configuration for UFS
UBOOT_ENV_SIZE:ast-ufs = "0x20000"
UBOOT_ENV:ast-ufs = "u-boot-env"
UBOOT_ENV_SUFFIX:ast-ufs = "bin"
UBOOT_ENV_TXT:ast-ufs = "u-boot-env-ufs.txt"

do_compile:append() {
    if [ -n "${UBOOT_ENV}" ]
    then
        # Generate default environment image
        ${B}/tools/mkenvimage -s ${UBOOT_ENV_SIZE} \
            -o ${B}/${UBOOT_ENV_BINARY} ${UNPACKDIR}/${UBOOT_ENV_TXT}
    fi
}
```

### `u-boot-common-aspeed-sdk_2023.10.inc`

```bitbake
HOMEPAGE = "https://github.com/AspeedTech-BMC/u-boot"
SECTION = "bootloaders"
DEPENDS += "flex-native bison-native"

LICENSE = "GPL-2.0-or-later"
LIC_FILES_CHKSUM = "file://Licenses/README;md5=2ca5f2c35c8cc335f0a19756634782f1"

BRANCH = "aspeed-master-v2023.10"
SRC_URI = "git://github.com/AspeedTech-BMC/u-boot.git;protocol=https;branch=${BRANCH}"

# Tag for v00.05.12
SRCREV = "b139e0526e716721e1d1be3ed0ea019aaaf079ed"

B = "${UNPACKDIR}/build"
do_configure[cleandirs] = "${B}"

# Disable initial environment generation
UBOOT_INITIAL_ENV = ""

PV = "v2023.10+git"
```

### `u-boot-aspeed.inc` - Build Tasks

#### `do_configure()`

```bash
do_configure () {
    if [ -z "${UBOOT_CONFIG}" ]; then
        if [ -n "${UBOOT_MACHINE}" ]; then
            oe_runmake -C ${S} O=${B} ${UBOOT_MACHINE}
        else
            oe_runmake -C ${S} O=${B} oldconfig
        fi
        # Merge .cfg configuration fragments
        merge_config.sh -m .config ${@" ".join(find_cfgs(d))}
        cml1_do_configure
    fi
}
```

#### `do_compile()`

```bash
do_compile () {
    # Handle gold linker if needed
    if [ "${@bb.utils.filter('DISTRO_FEATURES', 'ld-is-gold', d)}" ]; then
        sed -i 's/$(CROSS_COMPILE)ld$/$(CROSS_COMPILE)ld.bfd/g' ${S}/config.mk
    fi

    unset LDFLAGS
    unset CFLAGS
    unset CPPFLAGS

    # Generate version if not exists
    if [ ! -e ${B}/.scmversion -a ! -e ${S}/.scmversion ]
    then
        echo ${UBOOT_LOCALVERSION} > ${B}/.scmversion
        echo ${UBOOT_LOCALVERSION} > ${S}/.scmversion
    fi

    if [ -n "${UBOOT_CONFIG}" ]; then
        # Multi-configuration build
        for config in ${UBOOT_MACHINE}; do
            oe_runmake -C ${S} O=${B}/${config} ${config}
            oe_runmake -C ${S} O=${B}/${config} ${UBOOT_MAKE_TARGET}
        done
    else
        oe_runmake -C ${S} O=${B} ${UBOOT_MAKE_TARGET}
    fi
}
```

#### `do_deploy()`

```bash
do_deploy () {
    sub_ver=$(cat ${B}/.subversion)
    install -d ${DEPLOYDIR}
    
    # Deploy main U-Boot binary
    install -m 644 ${B}/${UBOOT_BINARY} ${DEPLOYDIR}/${UBOOT_IMAGE}
    install -m 644 ${B}/${UBOOT_BINARY} ${DEPLOYDIR}/${UBOOT_IMAGE}-${sub_ver}
    ln -sf ${UBOOT_IMAGE} ${DEPLOYDIR}/${UBOOT_BINARY}
    
    # Deploy SPL if configured
    if [ -n "${SPL_BINARY}" ]; then
        install -m 644 ${B}/${SPL_BINARY} ${DEPLOYDIR}/${SPL_IMAGE}
        install -m 644 ${B}/${SPL_BINARY} ${DEPLOYDIR}/${SPL_IMAGE}-${sub_ver}
        ln -sf ${SPL_IMAGE} ${DEPLOYDIR}/${SPL_BINARYNAME}
    fi
    
    # Deploy environment if configured
    if [ -n "${UBOOT_ENV}" ]; then
        install -m 644 ${B}/${UBOOT_ENV_BINARY} ${DEPLOYDIR}/${UBOOT_ENV_IMAGE}
        ln -sf ${UBOOT_ENV_IMAGE} ${DEPLOYDIR}/${UBOOT_ENV_BINARY}
    fi
}

addtask deploy before do_build after do_compile
```

## Build Variables

### U-Boot Specific

| Variable | Default | Description |
|----------|---------|-------------|
| `UBOOT_MACHINE` | - | Target defconfig |
| `UBOOT_MAKE_TARGET` | `all` | Make target |
| `UBOOT_BINARY` | `u-boot.bin` | Output binary name |
| `UBOOT_IMAGE` | `u-boot-${PV}-${PR}.bin` | Deployed image name |
| `UBOOT_SYMLINK` | `u-boot.bin` | Symlink name |
| `UBOOT_SUFFIX` | `bin` | Binary suffix |
| `SPL_BINARY` | `spl/u-boot-spl.bin` | SPL binary path |
| `SPL_IMAGE` | `u-boot-spl-${PV}-${PR}` | SPL deployed image |
| `UBOOT_LOCALVERSION` | `""` | Version suffix |

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `UBOOT_ENV` | - | Enable env image |
| `UBOOT_ENV_BINARY` | `u-boot-env.bin` | Env binary |
| `UBOOT_ENV_SIZE` | varies | Env size |
| `UBOOT_ENV_TXT` | - | Env source file |

### Signing Variables

| Variable | Description |
|----------|-------------|
| `SPL_SIGN_ENABLE` | Enable SPL signing |
| `SPL_SIGN_KEYDIR` | Signing key directory |
| `SPL_MKIMAGE_SIGN_ARGS` | Additional mkimage args |
| `UBOOT_MKIMAGE_SIGN` | Signing command |
| `UBOOT_FIT_CHECK_SIGN` | Verification command |

## Configuration Fragments

The build system supports `.cfg` files that are merged into the base configuration:

```python
def find_cfgs(d):
    sources = src_patches(d, True)
    sources_list = []
    for s in sources:
        if s.endswith('.cfg'):
            sources_list.append(s)
    return sources_list
```

## Build Workflow

```
+------------------------------------------+
|           Build Flow                     |
+------------------------------------------+

1. do_fetch
   - Clone git repository
   - Checkout SRCREV
   
2. do_unpack
   - Extract source to ${S}
   - Apply patches
   
3. do_configure
   - Run defconfig
   - Merge .cfg fragments
   - Run oldconfig/menuconfig
   
4. do_compile
   - Set version
   - Run make
   - Generate SPL if enabled
   - Generate env image if enabled
   
5. do_install
   - Install binaries to ${D}
   
6. do_deploy
   - Copy to deploy directory
   - Create symlinks
```

## BootMCU Build Variables

| Variable | Description |
|----------|-------------|
| `BOOTMCU_MACHINE` | BootMCU target machine |
| `BOOTMCU_FMC_BINARY` | FMC output binary |
| `FMC_IMAGE_ENABLE` | Enable FMC image creation |
| `FMC_SIGN_ENABLE` | Enable FMC signing |
| `FMC_ECC_KEY` | ECC signing key path |
| `FMC_LMS_KEY` | LMS signing key path |
| `RISCV_PREBUILT_TOOLCHAIN` | RISC-V cross-compiler |

## Build Commands

### Build U-Boot

```bash
# Build U-Boot for AST2700
bitbake u-boot

# Clean and rebuild
bitbake u-boot -c cleansstate
bitbake u-boot

# Build with verbose output
bitbake u-boot -V

# Build specific machine
UBOOT_MACHINE=ast2700-default bitbake u-boot
```

### Build BootMCU

```bash
# Build BootMCU (RISC-V)
bitbake bootmcu-spl

# Clean BootMCU
bitbake bootmcu-spl -c cleansstate
```

### Build U-Boot Tools

```bash
# Build mkimage and other tools
bitbake u-boot-tools
```

## Output Artifacts

### U-Boot Outputs

```
tmp/deploy/images/<machine>/
  u-boot.bin                 # Main U-Boot binary
  u-boot.bin-<version>       # Versioned copy
  u-boot-<type>.bin          # Multi-config variant
  u-boot-spl.bin             # SPL binary (if enabled)
  u-boot-spl.bin-<version>   # Versioned SPL
  u-boot-env.bin             # Environment (if enabled)
```

### BootMCU Outputs

```
tmp/deploy/images/<machine>/
  u-boot-spl.dtb             # SPL device tree
  u-boot-spl-nodtb.bin       # SPL without DTB
  u-boot-spl.bin             # Combined SPL
  fmc_ast2700.bin            # FMC image (A1+)
  fmc_ast2700.bin-<subver>   # Versioned FMC
```

## Dependencies

### Native Tools

| Tool | Purpose |
|------|---------|
| `bc-native` | Calculator for build |
| `dtc-native` | Device tree compiler |
| `flex-native` | Lexer generator |
| `bison-native` | Parser generator |
| `openssl-native` | Cryptographic operations |
| `swig-native` | Language bindings |
| `kern-tools-native` | Kernel tools |

### Cross-Compilation Tools

| Tool | Purpose |
|------|---------|
| `${TARGET_PREFIX}gcc` | ARM cross-compiler |
| `${RISCV_PREBUILT_TOOLCHAIN}gcc` | RISC-V cross-compiler (BootMCU) |

## Source Repository

- **Repository**: https://github.com/AspeedTech-BMC/u-boot
- **Branch**: `aspeed-master-v2023.10`
- **Commit**: `b139e0526e716721e1d1be3ed0ea019aaaf079ed`