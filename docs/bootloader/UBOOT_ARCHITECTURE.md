# U-Boot AST Architecture Documentation

## File Overview

This document describes the U-Boot architecture for Aspeed BMC chips (AST2400, AST2500, AST2600, AST2700).

## Key Source Files

### Architecture Support Files

| File | Purpose |
|------|---------|
| `arch/arm/mach-aspeed/cpuinfo.c` | CPU information printing |
| `arch/arm/mach-aspeed/ast2600/board_common.c` | Common board initialization |
| `arch/arm/mach-aspeed/ast2600/spl.c` | SPL boot implementation |
| `arch/arm/mach-aspeed/ast2600/platform.S` | Low-level platform init |
| `arch/arm/mach-aspeed/ast2600/scu_info.c` | SCU information parsing |
| `arch/arm/mach-aspeed/ast2600/cache.c` | Cache operations |

## Key Data Structures

### SoC ID Table (`scu_info.c`)

```c
struct soc_id {
    const char *name;
    u64 rev_id;
};

static struct soc_id soc_map_table[] = {
    SOC_ID("AST2600-A0", 0x0500030305000303),
    SOC_ID("AST2600-A1", 0x0501030305010303),
    SOC_ID("AST2620-A1", 0x0501020305010203),
    SOC_ID("AST2600-A2", 0x0502030305010303),
    SOC_ID("AST2620-A2", 0x0502020305010203),
    SOC_ID("AST2605-A2", 0x0502010305010103),
    SOC_ID("AST2600-A3", 0x0503030305030303),
    SOC_ID("AST2620-A3", 0x0503020305030203),
    SOC_ID("AST2605-A3", 0x0503010305030103),
    SOC_ID("AST2625-A3", 0x0503040305030403),
};
```

### PLL Register Structure (`board_common.c`, `clk_ast2600.c`)

```c
union ast2600_pll_reg {
    unsigned int w;
    struct {
        unsigned int m : 13;        /* bit[12:0]  */
        unsigned int n : 6;         /* bit[18:13] */
        unsigned int p : 4;         /* bit[22:19] */
        unsigned int off : 1;       /* bit[23]    */
        unsigned int bypass : 1;    /* bit[24]    */
        unsigned int reset : 1;     /* bit[25]    */
        unsigned int reserved : 6;  /* bit[31:26] */
    } b;
};

/* PLL Output Formula: F = CLKIN * ((M + 1) / (N + 1)) / (P + 1) */
```

### System Reset Control Flags (`scu_info.c`)

```c
#define SYS_WDT8_SW_RESET    BIT(15)
#define SYS_WDT8_ARM_RESET   BIT(14)
#define SYS_WDT8_FULL_RESET  BIT(13)
#define SYS_WDT8_SOC_RESET   BIT(12)
#define SYS_WDT7_SW_RESET    BIT(11)
#define SYS_WDT7_ARM_RESET   BIT(10)
#define SYS_WDT7_FULL_RESET  BIT(9)
#define SYS_WDT7_SOC_RESET   BIT(8)
/* ... more WDT reset flags ... */
#define SYS_CM3_EXT_RESET    BIT(6)
#define SYS_PCI2_RESET       BIT(5)
#define SYS_PCI1_RESET       BIT(4)
#define SYS_DRAM_ECC_RESET   BIT(3)
#define SYS_FLASH_ABR_RESET  BIT(2)
#define SYS_EXT_RESET        BIT(1)
#define SYS_PWR_RESET_FLAG   BIT(0)
```

## Main Functions

### `print_cpuinfo()` (`cpuinfo.c`)

Prints comprehensive CPU and system information:

```c
int print_cpuinfo(void)
{
    aspeed_print_soc_id();           // SoC type and revision
    aspeed_print_sysrst_info();      // Reset cause information
    aspeed_print_security_info();    // Secure boot status
    aspeed_print_2nd_wdt_mode();     // ABR/WDT configuration
    aspeed_print_fmc_aux_ctrl();     // FMC auxiliary control
    aspeed_print_spi1_abr_mode();    // SPI1 ABR mode
    aspeed_print_spi1_aux_ctrl();    // SPI1 auxiliary control
    aspeed_print_spi_strap_mode();   // SPI strap mode
    aspeed_print_espi_mode();        // eSPI/LPC mode
    aspeed_print_mac_info();         // MAC interface info
    return 0;
}
```

### `board_init()` (`board_common.c`)

Platform-specific initialization:

```c
__weak int board_init(void)
{
    // Disable address remapping for A1 to prevent secure boot reboot failure
    rev_id = ((u64)readl(ASPEED_REVISION_ID1) << 32) | readl(ASPEED_REVISION_ID0);
    
    if (rev_id == 0x0501030305010303 || rev_id == 0x0501020305010203) {
        if ((readl(ASPEED_SB_STS) & BIT(6))) {
            // Disable address remapping
        }
    }
    
    gd->bd->bi_boot_params = CONFIG_SYS_SDRAM_BASE + 0x100;
    
    // Initialize comphy via MISC uclass drivers
    while (uclass_get_device(UCLASS_MISC, i++, &dev) == 0);
    
    return 0;
}
```

### `dram_init()` (`board_common.c`)

DRAM initialization via RAM uclass:

```c
__weak int dram_init(void)
{
    struct udevice *dev;
    struct ram_info ram;
    
    uclass_get_device(UCLASS_RAM, 0, &dev);
    ram_get_info(dev, &ram);
    gd->ram_size = ram.size;
    return 0;
}
```

### `aspeed_mmc_init()` (`board_common.c`)

eMMC boot controller initialization for AST2600:

```c
void aspeed_mmc_init(void)
{
    // Check if boot from eMMC is enabled
    if ((readl(0x1e6e2500) & 0x4) == 0)
        return;
    
    // Disable FMC WDT
    writel(readl(0x1e620064) & 0xfffffffe, 0x1e620064);
    
    // Disable eMMC boot controller engine
    *(volatile int *)0x1e6f500C &= ~0x90000000;
    
    // Set pinctrl for eMMC
    *(volatile int *)0x1e6e2400 |= 0xff000000;
    
    // Configure clock (PLL calculation)
    // F = 25Mhz * [(M + 2) / (n + 1)] / (p + 1)
}
```

## Register Configuration

### SCU (System Control Unit) Registers

| Register | Offset | Purpose |
|----------|--------|---------|
| `SCU_PROT_KEY1` | 0x000 | Protection key 1 (magic: 0x1688a8a8) |
| `SCU_PROT_KEY2` | 0x010 | Protection key 2 |
| `SCU_REV_ID` | 0x014 | Silicon revision ID |
| `SCU_SYSRST_CTRL` | 0x040 | System reset control |
| `SCU_HW_STRAP1` | 0x500 | Hardware strap 1 |
| `SCU_HW_STRAP2` | 0x510 | Hardware strap 2 |
| `SCU_HW_STRAP3` | 0x51c | Hardware strap 3 |
| `SCU_SMP_S_EP` | 0x1bc | SMP secure entry point |

### FMC (Flash Memory Controller) Registers

| Register | Offset | Purpose |
|----------|--------|---------|
| `FMC_CE0_CTRL` | 0x010 | Chip enable 0 control |
| `FMC_SW_RST_CTRL` | 0x050 | Software reset control |
| `FMC_WDT1_CTRL_MODE` | 0x060 | WDT1 control |
| `FMC_WDT2_CTRL_MODE` | 0x064 | WDT2 control (ABR) |

### GPIO Registers

| Register | Offset | Purpose |
|----------|--------|---------|
| `GPIOYZ_DATA_VALUE` | 0x1e0 | GPIO Y/Z data value |
| `GPIO_BASE` | 0x1e780000 | Base address |

## Initialization Sequence

### Low-Level Init (`platform.S`)

```assembly
lowlevel_init:
    ; 1. Timer initialization
    timer_init
    
    ; 2. Reset SMP mailbox
    mov r0, #0x0
    str r0, [SCU_SMP_READY]
    
    ; 3. Enable cache SMP bit
    mrc p15, 0, r0, c1, c0, 1
    orr r0, #0x40
    mcr p15, 0, r0, c1, c0, 1
    
    ; 4. CPU identification
    mrc p15, 0, r0, c0, c0, 5
    
    ; 5. Primary core setup OR secondary core polling
    beq do_primary_core_setup
    b poll_smp_mbox_ready
    
do_primary_core_setup:
    ; Unlock SCU
    scu_unlock
    
    ; Identify silicon revision
    ; Apply A0/A1/A2/A3 specific workarounds
    
    ; Enable Vault Key Write Protection
    mov r0, #0x2
    str r0, [SEC_VAULT_KEY_CTRL]
    
    ; PCIeRC/E2M8 power-on reset handling
    
    ; MMIO decode setting
    mov r1, #0x2000
    str r1, [SCU_MMIO_DEC_SET]
    
    ; Enable cache & SRAM parity check
    ; Relocate SMP mailbox instructions
    ; Notify secondary cores via SEV
```

## Security Features

### Secure Boot Detection (`scu_info.c`)

```c
void aspeed_print_security_info(void)
{
    u32 qsr = readl(ASPEED_OTP_QSR);    // OTP QSR register
    u32 sb_sts = readl(ASPEED_SB_STS);  // Secure boot status
    
    if (!(sb_sts & BIT(6)))
        return;  // Secure boot not enabled
        
    if (qsr & BIT(7)) {
        // Mode_2 with RSA signing
        hash = (qsr >> 10) & 3;  // SHA224/256/384/512
        rsa = (qsr >> 12) & 3;   // RSA1024/2048/3072/4096
    } else {
        // Mode_GCM with AES
    }
}
```

### Address Remapping Disable (A1 Workaround)

```c
// For AST2600 A1/A2, disable address remapping to prevent
// secure boot reboot failure
if (rev_id == 0x0501030305010303 ||  // AST2600-A1
    rev_id == 0x0501020305010203) {   // AST2620-A1
    if (readl(ASPEED_SB_STS) & BIT(6)) {
        tmp_val = readl(0x1e60008c) & (~BIT(0));
        writel(0xaeed1a03, 0x1e600000);
        writel(tmp_val, 0x1e60008c);
        writel(0x1, 0x1e600000);
    }
}
```

## Dependencies

- `asm/arch/aspeed_scu_info.h` - SCU definitions
- `asm/arch/platform.h` - Platform definitions
- `asm/io.h` - I/O access macros
- `linux/bitops.h` - Bit manipulation
- `dm.h` - Driver model
- `ram.h` - RAM operations

## Boot Mode Detection

```c
#define AST_BOOTMODE_SPI    0
#define AST_BOOTMODE_EMMC   1
#define AST_BOOTMODE_UART   2

u32 aspeed_bootmode(void);  // Detected by hardware strap pins

u32 spl_boot_device(void)
{
    switch (aspeed_bootmode()) {
    case AST_BOOTMODE_EMMC:
        return BOOT_DEVICE_MMC1;
    case AST_BOOTMODE_SPI:
        return BOOT_DEVICE_RAM;
    case AST_BOOTMODE_UART:
        return BOOT_DEVICE_UART;
    default:
        return BOOT_DEVICE_NONE;
    }
}
```