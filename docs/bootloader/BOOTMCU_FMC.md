# BootMCU / FMC (First Mutable Code) Design

## Overview

BootMCU (also known as FMC - First Mutable Code) is the RISC-V based secure bootloader for AST2700. It serves as the Root of Trust after the immutable BootROM and is responsible for loading and verifying the next stage of the boot chain.

## Key Components

| Component | Description |
|-----------|-------------|
| BootROM | Immutable ROM in silicon (not user-modifiable) |
| FMC/BootMCU | RISC-V based first mutable code |
| BL31 (TF-A) | Trusted Firmware-A |
| OP-TEE | Trusted Execution Environment |

## Boot Flow with BootMCU

```
BootROM (Silicon)
      |
      v
+------------------+
| OTP Root Key     | <-- Stored in One-Time Programmable memory
+------------------+
      |
      v
BootMCU/FMC (RISC-V) <-- Verified by OTP root key hash (ECDSA)
      |
      +---> BL31 (TF-A) ---> OP-TEE ---> U-Boot ---> Linux
      |
      +---> Caliptra Manifest (if enabled)
```

## Recipe Files

### `/mnt/d/code/aspped-github/openbmc/meta-aspeed-sdk/recipes-bsp/bootmcu/bootmcu-spl_2023.10.bb`

```bitbake
require bootmcu-spl.inc
require recipes-bsp/u-boot/u-boot-common-aspeed-sdk_${PV}.inc
```

### `/mnt/d/code/aspped-github/openbmc/meta-aspeed-sdk/recipes-bsp/bootmcu/bootmcu-spl.inc`

Main include file containing the build logic:

```bitbake
SUMMARY = "BootMCU firmware and execute SPL"
DESCRIPTION = "BootMCU is designated to load the first, verified image for the main processor"
PACKAGE_ARCH = "${MACHINE_ARCH}"

PROVIDES += "virtual/bootmcu"

# Dependencies
DEPENDS = "ast2700-riscv-linux-gnu-native kern-tools-native swig-native \
           ${PYTHON_PN}-setuptools-native fmc-imgtool-native"
DEPENDS += "${@bb.utils.contains('MACHINE_FEATURES', 'ast-secure', \
            'aspeed-secure-config-native u-boot-tools-native', '', d)}"

# Toolchain
RISCV_PREBUILT_TOOLCHAIN = "${STAGING_DIR_NATIVE}${datadir}/ast2700-riscv-linux-gnu/bin/riscv32-unknown-linux-gnu-"
EXTRA_OEMAKE = 'CROSS_COMPILE=${RISCV_PREBUILT_TOOLCHAIN} ...'
```

## Build Tasks

### `do_configure()`

Configures the BootMCU build with machine-specific settings and merges configuration fragments:

```bash
do_configure () {
    oe_runmake -C ${S} O=${B} ${BOOTMCU_MACHINE}
    merge_config.sh -m .config ${@" ".join(find_cfgs(d))}
    cml1_do_configure
}
```

### `do_compile()`

Compiles the BootMCU firmware:

```bash
do_compile() {
    unset LDFLAGS
    unset CFLAGS
    unset CPPFLAGS
    
    # Generate version if not exists
    if [ ! -e ${B}/.scmversion -a ! -e ${S}/.scmversion ]
    then
        echo ${UBOOT_LOCALVERSION} > ${B}/.scmversion
        echo ${UBOOT_LOCALVERSION} > ${S}/.scmversion
    fi
    
    oe_runmake -C ${S} O=${B} all
}
```

### `do_add_pubkey_to_spl_dtb()`

Adds the public key into the SPL device tree by signing a dummy FIT image and injecting the key into the `/signature` node:

```bash
do_add_pubkey_to_spl_dtb() {
    # Only run when SPL signing is enabled
    if [ "${SPL_SIGN_ENABLE}" != "1" ] || [ -n "${SPL_DTB_BINARY}" ]; then
        return 0
    fi
    
    # Sign dummy image to add signing keys to SPL DTB
    ${UBOOT_MKIMAGE_SIGN} \
        -f auto \
        -k "${SPL_SIGN_KEYDIR}" \
        -o "${UBOOT_FIT_HASH_ALG},${UBOOT_FIT_SIGN_ALG}" \
        -g "${SPL_SIGN_KEYNAME}" \
        -K "${B}/spl/u-boot-spl.dtb" \
        -d /dev/null \
        -r ${B}/unused.itb \
        ${SPL_MKIMAGE_SIGN_ARGS}
    
    # Verify signature
    ${UBOOT_FIT_CHECK_SIGN} \
        -k "${B}/spl/u-boot-spl.dtb" \
        -f ${B}/unused.itb
    
    # Concatenate nodtb part and signed DTB
    cat ${B}/spl/u-boot-spl-nodtb.bin ${B}/spl/u-boot-spl.dtb > ${B}/spl/u-boot-spl.bin
}

addtask add_pubkey_to_spl_dtb before do_deploy do_create_fmc_image after do_compile
```

### `do_create_fmc_image()`

Uses fmc-imgtool to create the FMC image with ECC signature (for AST2700 A1+):

```bash
do_create_fmc_image() {
    export OPENSSL_MODULES="${STAGING_LIBDIR_NATIVE}/ossl-modules"
    
    local ecc_key=""
    local ecc_key_index=""
    local lms_key=""
    local lms_key_index=""
    local sign_args=""
    
    if [ "${FMC_IMAGE_ENABLE}" != "1" ]; then
        return
    fi
    
    # Build signing arguments
    if [ -f "${FMC_ECC_KEY}" ]; then
        ecc_key="--ecc-key ${FMC_ECC_KEY}"
    fi
    
    if [ -n "${FMC_ECC_KEY_INDEX}" ]; then
        ecc_key_index="--ecc-key-index ${FMC_ECC_KEY_INDEX}"
    fi
    
    if [ -f "${FMC_LMS_KEY}" ]; then
        lms_key="--lms-key ${FMC_LMS_KEY}"
    fi
    
    if [ -n "${FMC_LMS_KEY_INDEX}" ]; then
        lms_key_index="--lms-key-index ${FMC_LMS_KEY_INDEX}"
    fi
    
    if [ "${FMC_SIGN_ENABLE}" = "1" ]; then
        sign_args="${ecc_key} ${ecc_key_index} ${lms_key} ${lms_key_index}"
    fi
    
    # Create FMC image using fmc-imgtool
    fmc-imgtool \
        --verbose \
        --version 2 \
        --input ${B}/spl/u-boot-spl.bin \
        --output ${B}/${BOOTMCU_FMC_BINARY} \
        --prebuilt-dir ${DEPLOY_DIR_IMAGE}/ \
        ${sign_args}
}

addtask create_fmc_image before do_deploy after do_compile
```

### `do_deploy()`

Deploys the compiled artifacts:

```bash
do_deploy() {
    sub_ver=$(cat ${B}/.subversion)
    install -d ${DEPLOYDIR}
    
    # SPL components
    install -m 644 ${B}/spl/u-boot-spl.dtb ${DEPLOYDIR}
    install -m 644 ${B}/spl/u-boot-spl-nodtb.bin ${DEPLOYDIR}
    install -m 644 ${B}/spl/u-boot-spl.bin ${DEPLOYDIR}
    
    # FMC image (since AST2700 A1)
    install -m 644 ${BOOTMCU_FMC_BINARY} ${DEPLOYDIR}
    install -m 644 ${BOOTMCU_FMC_BINARY} ${DEPLOYDIR}/${BOOTMCU_FMC_BINARY}-${sub_ver}
}

addtask deploy before do_build after do_compile
```

## Key Variables

| Variable | Description |
|----------|-------------|
| `BOOTMCU_MACHINE` | Target machine (e.g., ast2700-default) |
| `BOOTMCU_FMC_BINARY` | Output FMC binary name |
| `FMC_IMAGE_ENABLE` | Enable FMC image creation |
| `FMC_SIGN_ENABLE` | Enable FMC signing |
| `FMC_ECC_KEY` | Path to ECC signing key |
| `FMC_ECC_KEY_INDEX` | ECC key index (0-3) |
| `FMC_LMS_KEY` | LMS signing key path |
| `SPL_SIGN_ENABLE` | Enable SPL signing |
| `SPL_SIGN_KEYDIR` | SPL signing key directory |
| `SPL_DTB_BINARY` | SPL DTB binary path |
| `UBOOT_MKIMAGE_SIGN` | mkimage command for signing |
| `UBOOT_FIT_CHECK_SIGN` | FIT signature verification tool |

## FMC Image Format

The FMC image is created by fmc-imgtool with the following structure:

```
+---------------------------+
| FMC Header                |  (version 2 format)
|   - Magic                 |
|   - Size                  |
|   - CRC32                 |
+---------------------------+
| Image Data                |  (u-boot-spl.bin)
|   - SPL binary            |
|   - Device tree blob      |
+---------------------------+
| ECC Signature             |  (optional)
|   - ECDSA384 signature    |
+---------------------------+
| LMS Signature             |  (optional, for A1+)
|   - LMS signature         |
+---------------------------+
```

## Signing Algorithms

| Mode | Elliptic Curve | Hash | LMS | Notes |
|------|----------------|------|-----|-------|
| `ecdsa384` | ECDSA P-384 | SHA-384 | No | Basic secure boot |
| `ecdsa384-lms` | ECDSA P-384 | SHA-384 | Yes | Enhanced (quantum-resistant) |

## Dependencies

| Dependency | Purpose |
|------------|---------|
| `ast2700-riscv-linux-gnu-native` | RISC-V toolchain for BootMCU |
| `kern-tools-native` | Kernel image tools |
| `swig-native` | Language binding |
| `fmc-imgtool-native` | FMC image creation tool |
| `aspeed-secure-config-native` | Secure configuration |
| `openssl-native` | Cryptographic operations |
| `u-boot-tools-native` | mkimage, etc. |

## Configuration Files

The build uses configuration fragments (.cfg files) from the source URI:

```python
def find_cfgs(d):
    sources=src_patches(d, True)
    sources_list=[]
    for s in sources:
        if s.endswith('.cfg'):
            sources_list.append(s)
    return sources_list
```

## Machine Configuration

### `/mnt/d/code/aspped-github/openbmc/meta-aspeed-sdk/conf/machine/include/bootmcu.inc`

```bitbake
MACHINE_FEATURES:append = " ast-bootmcu"
MACHINEOVERRIDES .= ":ast-bootmcu"
```

### `/mnt/d/code/aspped-github/openbmc/meta-aspeed-sdk/conf/machine/include/ast-bootmcu.inc`

Contains additional BootMCU-specific machine configurations.

## Usage

```bash
# Build BootMCU for AST2700
bitbake bootmcu-spl

# Build with signing enabled
SPL_SIGN_ENABLE = "1"
FMC_SIGN_ENABLE = "1"
FMC_ECC_KEY = "/path/to/key.pem"

# View deployed artifacts
ls tmp/deploy/images/ast2700-default/
# u-boot-spl.bin
# u-boot-spl.dtb
# u-boot-spl-nodtb.bin
# fmc_ast2700.bin
# fmc_ast2700.bin-<subversion>
```