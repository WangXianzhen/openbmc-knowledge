# U-Boot AST2700 Bootloader Design Documentation

This directory contains detailed design documentation for the U-Boot bootloader implementation used in Aspeed AST2700 BMC chips.

## Overview

The AST2700 boot system consists of multiple components:
- **BootROM**: Immutable first-stage bootloader in silicon
- **BootMCU (FMC)**: First Mutable Code, RISC-V based secure loader
- **U-Boot SPL**: Secondary Program Loader for main ARM core
- **U-Boot**: Full bootloader with driver model support

## Architecture Diagram

```
+------------------------------------------------------------------+
|                         Boot Flow                                 |
+------------------------------------------------------------------+
|                                                                   |
|  BootROM (Silicon)                                               |
|       |                                                          |
|       v                                                          |
|  FMC/BootMCU (RISC-V) ---> OTP Root Key Verification             |
|       |                                                          |
|       +-- BL31 (TF-A) ---> Caliptra Manifest Verification        |
|       |                                                          |
|       +-- OP-TEE ---> Caliptra Manifest Verification             |
|       |                                                          |
|       v                                                          |
|  U-Boot SPL ---> FIT Image Verification (ECDSA384/SHA384)        |
|       |                                                          |
|       v                                                          |
|  U-Boot ---> Kernel FIT Image Verification                       |
|       |                                                          |
|       v                                                          |
|  Linux Kernel                                                    |
|                                                                   |
+------------------------------------------------------------------+
```

## Directory Structure

```
bootloader/
  UBOOT_ARCHITECTURE.md      - U-Boot architecture and boot flow
  UBOOT_AST2600_SUPPORT.md   - AST2600 machine support details
  UBOOT_SPL.md               - SPL (Secondary Program Loader) design
  BOOTMCU_FMC.md             - BootMCU/FMC (First Mutable Code) design
  UBOOT_DRIVERS.md           - Aspeed driver subsystem documentation
  UBOOT_BUILD.md             - Build system and recipe documentation
```

## Supported Platforms

| Platform | Boot Mode | Secure Boot |
|----------|-----------|-------------|
| AST2700-A2 | SPI/eMMC/UFS | ECDSA384/SHA384 |
| AST2700-A1 | SPI/eMMC | ECDSA384/SHA384 + LMS |
| AST2600-A3 | SPI/eMMC | RSA (legacy) |

## Key Source Locations

| Component | Path |
|-----------|------|
| U-Boot Source | `/mnt/d/code/aspped-github/u-boot/` |
| Machine Support | `arch/arm/mach-aspeed/ast2600/` |
| Drivers | `drivers/clk/aspeed/`, `drivers/ram/aspeed/`, etc. |
| Build Recipes | `meta-aspeed-sdk/recipes-bsp/u-boot/` |
| BootMCU Recipes | `meta-aspeed-sdk/recipes-bsp/bootmcu/` |

## Version Information

- **U-Boot Version**: v2023.10 (branch: `aspeed-master-v2023.10`)
- **Commit**: b139e0526e716721e1d1be3ed0ea019aaaf079ed
- **BootMCU Version**: Uses same v2023.10 baseline

## Quick Reference Commands

```bash
# Build BootMCU (RISC-V)
cd meta-aspeed-sdk
bitbake bootmcu-spl

# Build U-Boot for AST2700
bitbake u-boot

# Clean build
bitbake u-boot -c cleansstate
```