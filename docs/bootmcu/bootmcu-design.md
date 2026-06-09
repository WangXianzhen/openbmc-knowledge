# BootMCU Firmware Design Analysis

## 1. Overview

BootMCU (also referred to as MCU Runtime or IBEX) is the RISC-V microcontroller firmware running on the AST2700 BMC chip. It serves as the **First Mutable Code (FMC)** in the secure boot chain, being the first updatable code verified by the BootROM.

### Key Characteristics

| Attribute | Value |
|-----------|-------|
| Processor Architecture | RISC-V (RISC-V32nf tune) |
| Build System | Yocto/OpenEmbedded (BitBake) |
| Base Source | U-Boot SPL (Secondary Program Loader) |
| U-Boot Version | v2023.10 (aspeed-master-v2023.10 branch) |
| Default Config | `ibex-ast2700_defconfig` |
| Toolchain | AST2700 RISC-V Linux GNU (prebuilt) |
| Output Format | FMC (First Mutable Code) image |

## 2. Repository Structure

### Recipe Files

```
meta-aspeed-sdk/recipes-bsp/bootmcu/
├── bootmcu-spl_2023.10.bb          # Main BitBake recipe
└── bootmcu-spl.inc                 # Build configuration include

# Configuration includes
meta-aspeed/conf/machine/
├── ast2700_bootmcu.conf            # Multi-config machine definition
└── include/bootmcu.inc             # Machine feature overrides

meta-aspeed-sdk/conf/machine/
└── include/ast-bootmcu.inc         # AST BootMCU feature overrides
```

### Source Repository

```bash
BRANCH = "aspeed-master-v2023.10"
SRC_URI = "git://github.com/AspeedTech-BMC/u-boot.git"
SRCREV = "b139e0526e716721e1d1be3ed0ea019aaaf079ed"
```

## 3. Build Flow

```
+------------------+     +-------------------+     +------------------+
| U-Boot SPL Source| --> | Cross Compile     | --> | SPL Binary       |
| (RISC-V)         |     | (RISC-V toolchain)|     | u-boot-spl.bin   |
+------------------+     +-------------------+     +--------+---------+
                                                         |
                                                         v
                                                +-------------------+
                                                | fmc-imgtool       |
                                                | (Image Wrapper)   |
                                                +--------+----------+
                                                         |
                                                         v
+------------------+     +-------------------+     +------------------+
| BootROM          | <-- | FMC Image         | --> | OTP Root Key     |
| (Immutable RoT)  |     | (Signed SPL)      |     | Verification     |
+------------------+     +-------------------+     +------------------+
```

### Build Tasks (in order)

1. **do_configure**: Apply defconfig and merge .cfg files
2. **do_compile**: Build SPL binary using RISC-V cross-compiler
3. **do_add_pubkey_to_spl_dtb**: (Optional) Inject public key into SPL DTB
4. **do_create_fmc_image**: Wrap SPL into FMC format using fmc-imgtool
5. **do_deploy**: Install binaries to deploy directory

### Build Configuration

```bash
# Cross-compiler settings
RISCV_PREBUILT_TOOLCHAIN = "${STAGING_DIR_NATIVE}${datadir}/ast2700-riscv-linux-gnu/bin/riscv32-unknown-linux-gnu-"
EXTRA_OEMAKE = 'CROSS_COMPILE=${RISCV_PREBUILT_TOOLCHAIN} CC="${RISCV_PREBUILT_TOOLCHAIN}gcc"'

# Make target
BOOTMCU_MACHINE = "ibex-ast2700_defconfig"
```

## 4. FMC Image Generation

Starting from AST2700 A1, the SPL binary is wrapped into FMC format using the `fmc-imgtool`:

```python
# do_create_fmc_image task
fmc-imgtool \
    --verbose \
    --version 2 \
    --input ${B}/spl/u-boot-spl.bin \
    --output ${B}/${BOOTMCU_FMC_BINARY} \
    --prebuilt-dir ${DEPLOY_DIR_IMAGE}/ \
    ${sign_args}
```

### Output Binaries

| Binary | Description |
|--------|-------------|
| `u-boot-spl.bin` | Raw SPL binary |
| `u-boot-spl.dtb` | SPL device tree blob |
| `u-boot-spl-nodtb.bin` | SPL without DTB |
| `ast2700-mcu-runtime.bin` | FMC-wrapped image (A1) |
| `ast2700-ibex-spl.bin` | FMC-wrapped image (SPL variant) |

## 5. Secure Boot Integration

### Configuration Variables

```bash
# Enable FMC image generation
FMC_IMAGE_ENABLE = "1"

# Signing configuration
FMC_SIGN_ENABLE = "1"
FMC_ECC_KEY = "${FMC_KEY_DIR}/test_oem_dss_private_key_ecdsa384_1.pem"
FMC_ECC_KEY_INDEX = "1"
FMC_LMS_KEY = "${FMC_KEY_DIR}/test_oem_dss_lms_key_1.prv"
FMC_LMS_KEY_INDEX = "1"

# Key directory
FMC_KEY_DIR ?= "${STAGING_DATADIR_NATIVE}/aspeed-secure-config/ast2700/keys"
```

### Signing Algorithms

Two secure boot modes are supported:

| Mode | Elliptic Curve | Hash | LMS | Notes |
|------|----------------|------|-----|-------|
| `ecdsa384` | ECDSA P-384 | SHA-384 | No | Basic secure boot |
| `ecdsa384-lms` | ECDSA P-384 | SHA-384 | Yes | Enhanced (quantum-resistant) |

## 6. Interaction with BootROM

### Trust Chain

```
BootROM (RoT)
    |
    v
[OTP Root Key Hash Verification]
    |
    v
BootMCU/FMC (First Mutable Code)
    |
    v
[Caliptra Manifest Verification]
    |
    v
BL31 (TF-A) / OP-TEE
    |
    v
U-Boot (FIT signature verification)
    |
    v
Linux Kernel
```

### BootROM Responsibilities

1. **Root of Trust**: Immutable code in ROM
2. **OTP Validation**: Verify BootMCU against OTP-stored root key hash
3. **FMC Loading**: Load and execute BootMCU from flash
4. **Jump to BootMCU**: Transfer control after verification

### BootMCU Responsibilities

1. **Initialize RISC-V Core**: Set up exception handling, clocks
2. **Memory Initialization**: Configure SRAM/DRAM
3. **Load Next Stage**: Load BL31/ATF or U-Boot
4. **Chain Verification**: Verify next stage before execution
5. **Provide Services**: UART, flash access for debug

## 7. Flash Layout (AST2700 A1)

```
+------------------+ 0x00000000
| BootROM          | (Internal ROM)
+------------------+ 0x10000000
| SPI Flash        |
| +----------------+
| | BootMCU (FMC)  | 0x100000 (1024 KB)
| | BL31 (TF-A)    | 0x200000 (2048 KB)
| | U-Boot         | 0x210000 (2112 KB)
| | OP-TEE         | 0x310000 (3136 KB)
| | Kernel         | 0x... (variable)
| | Rootfs         | 0x... (variable)
| +----------------+
+------------------+
```

## 8. Dependencies

### Build Dependencies

| Dependency | Purpose |
|------------|---------|
| `ast2700-riscv-linux-gnu-native` | RISC-V cross-compiler |
| `kern-tools-native` | Device tree tools |
| `swig-native` | Language bindings |
| `python3-setuptools-native` | Python build tools |
| `fmc-imgtool-native` | FMC image packaging |
| `openssl-native` | Cryptographic operations |
| `aspeed-secure-config-native` | (Secure boot) Key management |
| `u-boot-tools-native` | (Secure boot) mkimage, FIT signing |
| `bmc-pb` | Prebuilt images (DDR firmware, etc.) |

### Runtime Dependencies

| Component | Dependency |
|-----------|------------|
| BootROM | OTP programmed with root key |
| BL31 | Caliptra manifest signed |
| Prebuilt | DDR4/DDR5 firmware in flash |

## 9. Machine Configuration Examples

### AST2700 A1 Standard

```bash
# In ast2700-a1.conf
FMC_IMAGE_ENABLE = "1"
BOOTMCU_FMC_BINARY = "ast2700-mcu-runtime.bin"
ZEPHYR_BOARD_BOOTMCU ?= "ast2700_evb/ast2700_a1/bootmcu"
```

### AST2700 A1 RTOS

```bash
# In ast2700-a1-rtos.conf
FMC_IMAGE_ENABLE = "1"
BOOTMCU_FMC_BINARY = "ast2700-mcu-runtime.bin"
ZEPHYR_BOARD_BOOTMCU ?= "ast2700_evb/ast2700_a1/bootmcu"
```

### AST2700 A1 SPL Variant

```bash
# In ast2700-a1-spl.conf
FMC_IMAGE_ENABLE = "1"
BOOTMCU_FMC_BINARY = "ast2700-ibex-spl.bin"
```

## 10. Key Files Reference

| File Path | Purpose |
|-----------|---------|
| `/recipes-bsp/bootmcu/bootmcu-spl_2023.10.bb` | Main recipe |
| `/recipes-bsp/bootmcu/bootmcu-spl.inc` | Build tasks |
| `/conf/machine/ast2700_bootmcu.conf` | Standalone BootMCU machine |
| `/conf/multiconfig/bootmcu.conf` | Multi-config for isolated builds |
| `/meta-ast2700-sdk/conf/machine/ast2700-a1.conf` | Full A1 SDK machine |
| `/meta-ast2700-sdk/conf/machine/include/ast2700a1-secure-mode.inc` | Secure boot config |

## 11. Troubleshooting

### Build Issues

```bash
# Clean and rebuild
bitbake bootmcu-spl -c cleansstate
bitbake bootmcu-spl

# Enter devshell for debugging
bitbake bootmcu-spl -c devshell
```

### Signing Issues

```bash
# Verify FMC image
fmc-imgtool --verbose --input ast2700-mcu-runtime.bin --verify

# Check key configuration
cat ${FMC_KEY_DIR}/*.pem
```

### Flash Verification

```bash
# Compare deployed images
md5sum ${DEPLOY_DIR_IMAGE}/ast2700-mcu-runtime.bin
```

## 12. References

- U-Boot Source: https://github.com/AspeedTech-BMC/u-boot (branch: aspeed-master-v2023.10)
- FMC Image Tool: `/fmc_imgtool/` (Python)
- Secure Boot Guide: `/docs/AST2700_SecureBoot.md`
- OTP Configuration: `/recipes-aspeed/security/aspeed-secure-config/configs/ast2700/otp/`