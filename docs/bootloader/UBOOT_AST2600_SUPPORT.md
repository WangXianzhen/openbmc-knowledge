# U-Boot AST2600 Machine Support

## Overview

AST2600 is the previous-generation Aspeed BMC chip. While the AST2700 is the current generation, AST2600 code provides the foundation for many architectural patterns.

## Source Directory

`/mnt/d/code/aspped-github/u-boot/arch/arm/mach-aspeed/ast2600/`

## Files in Machine Support

| File | Purpose |
|------|---------|
| `board_common.c` | Common board initialization |
| `spl.c` | SPL boot implementation |
| `platform.S` | Low-level assembly init |
| `scu_info.c` | SCU information/printing |
| `cpu.c` | CPU-specific code |
| `cache.c` | Cache operations |
| `Kconfig` | Configuration options |
| `Makefile` | Build rules |
| `u-boot-spl.lds` | SPL linker script |
| `utils.S` | Utility assembly functions |

## Board-Specific Files

| Directory | Platform |
|-----------|----------|
| `board/aspeed/evb_ast2600/` | AST2600 Evaluation Board |
| `board/aspeed/ast2600_dcscm/` | AST2600 DCSCM variant |
| `board/aspeed/ast2600_ibm/` | IBM platform variant |
| `board/aspeed/ast2600_intel/` | Intel platform variant |
| `board/aspeed/slt_ast2600/` | SLT (System Level Test) |
| `board/aspeed/fpga_ast2600/` | FPGA prototype |

## SoC Variants

| Variant | Description |
|---------|-------------|
| AST2600-A0 | Initial silicon (deprecated) |
| AST2600-A1 | First production revision |
| AST2620-A1 | Cost-reduced variant |
| AST2600-A2 | Second production revision |
| AST2620-A2 | Cost-reduced A2 |
| AST2605-A2 | Lower-end variant |
| AST2600-A3 | Latest production revision |
| AST2620-A3 | Cost-reduced A3 |
| AST2605-A3 | Lower-end A3 |
| AST2625-A3 | Enhanced A3 |

## Key Features

### Silicon Revision Detection

```c
// From scu_info.c
u64 rev_id;
rev_id = readl(ASPEED_REVISION_ID0);
rev_id = ((u64)readl(ASPEED_REVISION_ID1) << 32) | rev_id;

// Compare against known revisions
if (rev_id == 0x0503030305030303) {
    // AST2600-A3
}
```

### Revision-Specific Workarounds

#### A0-Specific (platform.S)

```assembly
; Tune up CPU clocks for A0 only
ldr r0, =SCU_HW_STRAP1
ldr r1, [r0]
bic r1, #0x1800
orr r1, #0x1000
str r1, [r0]

; Configure HPLL
ldr r0, =SCU_HPLL_PARAM
movw r1, #0x4080
movt r1, #0x1000
str r1, [r0]
```

#### A1-Specific (platform.S)

```c
// LPC/eSPI mode selection by software
ldr r0, =GPIOYZ_DATA_VALUE
ldr r0, [r0]
tst r0, #0x1000

// Switch to LPC mode if GPIOZ[4]=1
ldr r0, =SCU_HW_STRAP2
ldr r1, [r0]
orr r1, #0x40
str r1, [r0]
```

#### A1/A2 Address Remapping (board_common.c)

```c
// Disable address remapping for A1 to prevent secure boot reboot failure
rev_id = ((u64)readl(ASPEED_REVISION_ID1) << 32) | readl(ASPEED_REVISION_ID0);

if (rev_id == 0x0501030305010303 ||  // AST2600-A1
    rev_id == 0x0501020305010203) {   // AST2620-A1
    if ((readl(ASPEED_SB_STS) & BIT(6))) {
        tmp_val = readl(0x1e60008c) & (~BIT(0));
        writel(0xaeed1a03, 0x1e600000);
        writel(tmp_val, 0x1e60008c);
        writel(0x1, 0x1e600000);
    }
}
```

#### A3 UART Fix (platform.S)

```assembly
; Fix UART1 route problem on A3
ldr r0, =0x1e789098
movw r1, #0x0a30
str r1, [r0]

ldr r0, =0x1e78909c
movw r1, #0x0000
str r1, [r0]
```

## Boot Configuration

### Supported Boot Modes

| Mode | Device | Detection |
|------|--------|-----------|
| SPI | SPI flash (FMC) | HW_STRAP1[2] = 0 |
| eMMC | eMMC/NAND | HW_STRAP1[2] = 1 |
| UART | Xmodem download | Special strap |

### ABR (Alternate Boot Region)

```c
void aspeed_print_2nd_wdt_mode(void)
{
    /* ABR enable */
    if (readl(ASPEED_HW_STRAP2) & BIT(11)) {
        if (readl(ASPEED_HW_STRAP1) & BIT(2)) {
            printf("eMMC 2nd Boot (ABR): Enable");
            printf(", boot partition: %s",
                readl(ASPEED_EMMC_WDT_CTRL) & BIT(4) ? "2" : "1");
        } else {
            printf("FMC 2nd Boot (ABR): Enable");
            if (readl(ASPEED_HW_STRAP2) & BIT(12))
                printf(", Single flash");
            else
                printf(", Dual flashes");
            printf(", Source: %s",
                readl(ASPEED_FMC_WDT2) & BIT(4) ? "Alternate" : "Primary");
        }
    }
}
```

## Secure Boot

### OTP QSR Bits

| Bit | Field | Values |
|-----|-------|--------|
| 7 | Mode | 0=GCM, 1=Mode_2 |
| 10-11 | Hash | 0=SHA224, 1=SHA256, 2=SHA384, 3=SHA512 |
| 12-13 | RSA | 0=RSA1024, 1=RSA2048, 2=RSA3072, 3=RSA4096 |

### Secure Boot Status

```c
void aspeed_print_security_info(void)
{
    u32 qsr = readl(ASPEED_OTP_QSR);
    u32 sb_sts = readl(ASPEED_SB_STS);
    
    if (!(sb_sts & BIT(6)))
        return;  // Secure boot not enabled
    
    printf("Secure Boot: ");
    if (qsr & BIT(7)) {
        // Mode_2 with RSA
        hash = (qsr >> 10) & 3;
        rsa = (qsr >> 12) & 3;
    } else {
        // Mode_GCM with AES
        printf("Mode_GCM");
    }
}
```

## Build Configurations

### Defconfig Files

| File | Description |
|------|-------------|
| `evb-ast2600_defconfig` | Standard EVB |
| `evb-ast2600-ecc_defconfig` | With ECC secure boot |
| `evb-ast2600-emmc_defconfig` | eMMC boot variant |
| `evb-ast2600-ncsi_defconfig` | NCSI support |
| `ast2600_openbmc_defconfig` | OpenBMC configuration |
| `ast2600-dcscm_defconfig` | DCSCM variant |
| `ast2600-pfr_defconfig` | PFR (Platform Firmware Resilience) |
| `slt-ast2600_defconfig` | SLT testing |

### Key Config Options

```c
// .config fragments
CONFIG_ARM=y
CONFIG_ARCH_ASPEED=y
CONFIG_TEXT_BASE=0x83000000
CONFIG_NR_DRAM_BANKS=1
CONFIG_SYS_SDRAM_BASE=0x80000000

// SPL options
CONFIG_SPL=y
CONFIG_SPL_SPI_SUPPORT=y
CONFIG_SPL_MMC_SUPPORT=y
CONFIG_SPL_DM=y

// Driver model
CONFIG_DM=y
CONFIG_DM_GPIO=y
CONFIG_DM_MMC=y

// Ethernet
CONFIG_PHY_GIGE=y
CONFIG_MAC0=y
CONFIG_MAC1=y

// Security
CONFIG_SPL_FIT_SIGNATURE=y
CONFIG_FIT_SIGNATURE=y
CONFIG_RSA=y
CONFIG_SHA384=y
```

## Memory Map

| Region | Address | Size | Description |
|--------|---------|------|-------------|
| ROM | 0x00000000 | 64KB | BootROM |
| SRAM | 0x00100000 | 512KB | Internal SRAM |
| SPI Flash | 0x10000000 | 128MB | FMC region 0 |
| FMC Reg | 0x1e620000 | 4KB | Flash controller |
| Timer | 0x1e6e0000 | 4KB | Timer registers |
| SCU | 0x1e6e2000 | 4KB | System control |
| Video | 0x1e6e8000 | 64KB | Video engine |
| GPIO | 0x1e780000 | 64KB | GPIO controller |
| DRAM | 0x80000000 | 2GB | External DDR |
| PCIe | 0x400000000 | 4GB | PCIe memory |

## SMP Support

### Secondary Core Initialization

```c
// platform.S - SMP mailbox structure
/*
 * SMP mailbox
 * +----------------------+ 0x40
 * | cpuN sec_entrypoint  |
 * +----------------------+ 0x3c
 * | mailbox insn. for    |
 * | cpuN GO sign polling |
 * +----------------------+ 0x10
 * | mailbox ready        |
 * +----------------------+ 0x0c
 * | reserved             |
 * +----------------------+ 0x08
 * | cpuN GO signal       |
 * +----------------------+ 0x04
 * | cpuN ns_entrypoint   |
 * +----------------------+ SCU180
 */
```

### SMP Entry Points

| Register | Offset | Purpose |
|----------|--------|---------|
| `SCU_SMP_NS_EP` | 0x180 | Non-secure entry point |
| `SCU_SMP_GO` | 0x184 | GO signal |
| `SCU_SMP_READY` | 0x18c | Ready flag (magic: 0xcafebabe) |
| `SCU_SMP_POLLINSN` | 0x190 | Polling instruction area |
| `SCU_SMP_S_EP` | 0x1bc | Secure entry point |