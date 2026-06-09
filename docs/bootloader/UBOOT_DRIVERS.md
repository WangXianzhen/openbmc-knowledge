# U-Boot Aspeed Drivers Documentation

## Overview

U-Boot includes a comprehensive driver subsystem for Aspeed BMC chips, supporting clock, reset, pin control, RAM, and other peripherals through the Linux-style driver model.

## Driver Directory Structure

```
drivers/
  clk/aspeed/           # Clock controller drivers
    clk_ast2400.c
    clk_ast2500.c
    clk_ast2600.c
  pinctrl/aspeed/       # Pin multiplexing
    pinctrl_ast2400.c
    pinctrl_ast2500.c
    pinctrl_ast2600.c
  ram/aspeed/           # DRAM controller
    sdram_ast2500.c
    sdram_ast2600.c
    sdram_phy_ast2600.h
  reset/aspeed/         # Reset controller
    reset-ast2400.c
    reset-ast2500.c
    reset-ast2600.c
```

## Clock Driver (`drivers/clk/aspeed/clk_ast2600.c`)

### Key Data Structures

```c
/* PLL Register Layout */
union ast2600_pll_reg {
    u32 w;
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

/* PLL Configuration */
struct ast2600_pll_cfg {
    union ast2600_pll_reg reg;
    u32 ext_reg;
};

/* PLL Descriptor */
struct ast2600_pll_desc {
    u32 in;        /* Input frequency */
    u32 out;       /* Output frequency */
    struct ast2600_pll_cfg cfg;
};
```

### PLL Lookup Table

```c
static const struct ast2600_pll_desc ast2600_pll_lookup[] = {
    { .in = AST2600_CLK_IN, .out = 400000000,
      .cfg.reg.b.m = 95, .cfg.reg.b.n = 2, .cfg.reg.b.p = 1, .cfg.ext_reg = 0x31 },
    { .in = AST2600_CLK_IN, .out = 200000000,
      .cfg.reg.b.m = 127, .cfg.reg.b.n = 0, .cfg.reg.b.p = 15, .cfg.ext_reg = 0x3f },
    { .in = AST2600_CLK_IN, .out = 334000000,
      .cfg.reg.b.m = 667, .cfg.reg.b.n = 4, .cfg.reg.b.p = 9, .cfg.ext_reg = 0x14d },
    { .in = AST2600_CLK_IN, .out = 1000000000,
      .cfg.reg.b.m = 119, .cfg.reg.b.n = 2, .cfg.reg.b.p = 0, .cfg.ext_reg = 0x3d },
    /* ... more entries ... */
};
```

### MAC Clock Delay Configuration

```c
#define MAC_DEF_DELAY_1G   FIELD_PREP(MAC_CLK_1G_OUTPUT_DELAY_1, 16) |  \
                           FIELD_PREP(MAC_CLK_1G_INPUT_DELAY_1, 10) |   \
                           FIELD_PREP(MAC_CLK_1G_OUTPUT_DELAY_2, 16) |  \
                           FIELD_PREP(MAC_CLK_1G_INPUT_DELAY_2, 10)

#define MAC34_DEF_DELAY_1G FIELD_PREP(MAC_CLK_1G_OUTPUT_DELAY_1, 8) |   \
                           FIELD_PREP(MAC_CLK_1G_INPUT_DELAY_1, 4) |    \
                           FIELD_PREP(MAC_CLK_1G_OUTPUT_DELAY_2, 8) |   \
                           FIELD_PREP(MAC_CLK_1G_INPUT_DELAY_2, 4)
```

### Clock Stop Control (SCU Registers)

| Register | Bit | Description |
|----------|-----|-------------|
| `SCU_CLKSTOP_MAC1` | 20 | MAC1 clock stop |
| `SCU_CLKSTOP_MAC2` | 21 | MAC2 clock stop |
| `SCU_CLKSTOP_MAC3` | 20 | MAC3 clock stop |
| `SCU_CLKSTOP_MAC4` | 21 | MAC4 clock stop |

## Reset Driver (`drivers/reset/aspeed/reset-ast2600.c`)

### Reset Types

```c
#define ASPEED_RESET_MAC1    BIT(0)
#define ASPEED_RESET_MAC2    BIT(1)
#define ASPEED_RESET_UART1   BIT(2)
#define ASPEED_RESET_UART2   BIT(3)
/* ... */
#define ASPEED_RESET_HACE    BIT(19)
```

### Reset Control Register

| Register | Offset | Description |
|----------|--------|-------------|
| `SCU_SYS_RST_CTRL` | 0x040 | System reset control |
| `SCU_SYS_RST_CTRL_CLR` | 0x044 | Clear reset control |

## RAM Driver (`drivers/ram/aspeed/sdram_ast2600.c`)

### Key Constants

```c
#define AST_SCU_HANDSHAKE     0x100
#define AST_SCU_MPLL          0x220
#define AST_SCU_MPLL_EXT      0x224
#define AST_SCU_HW_STRAP      0x500
#define AST_SCU_EFUSE_DATA    0x594

/* Handshake bits */
#define SCU_SDRAM_SUPPORT_IKVM_HIGH_RES BIT(0)
#define SCU_SDRAM_INIT_READY_MASK       BIT(6)
#define SCU_SDRAM_INIT_BY_SOC_MASK      BIT(7)
#define SCU_P2A_BRIDGE_DISABLE          BIT(12)

/* MPLL Frequency Settings */
#define SCU_MPLL_FREQ_400M  0x0008405F
#define SCU_MPLL_EXT_400M   0x0000002F
#define SCU_MPLL_FREQ_333M  0x00488299
#define SCU_MPLL_EXT_333M   0x0000014C
#define SCU_MPLL_FREQ_200M  0x0078007F
#define SCU_MPLL_EXT_200M   0x0000003F
#define SCU_MPLL_FREQ_100M  0x0078003F
#define SCU_MPLL_EXT_100M   0x0000001F
```

### DDR4 Mode Register Configuration

```c
#define MR01_DRAM_ODT        (0x3 << 24)  // 40 ohm (default)

#if defined(CONFIG_ASPEED_DDR4_DRAM_ODT60)
#define MR01_DRAM_ODT        (0x1 << 24)
#elif defined(CONFIG_ASPEED_DDR4_DRAM_ODT48)
#define MR01_DRAM_ODT        (0x5 << 24)
#endif

/* Mode register values */
#define DDR4_MR01_MODE       ((MR1_VAL << 16) | MR0_VAL)
#define DDR4_MR23_MODE       ((MR3_VAL << 16) | MR2_VAL)
#define DDR4_MR45_MODE       ((MR5_VAL << 16) | MR4_VAL)
#define DDR4_MR6_MODE        MR6_VAL
```

### DDR4 Timing Parameters

| Parameter | Description | Formula |
|-----------|-------------|---------|
| `DDR4_TRFC` | Refresh cycle time | Based on speed grade |
| `DDR4_TRFI` | Refresh interval | 7.8us or 3.9us |
| `DDR4_TRFC_1600` | tRFC for DDR4-1600 | 0x467299f1 |
| `DDR4_TRFC_1333` | tRFC for DDR4-1333 | 0x3a5f80c9 |

### DRAM Initialization Flow

```c
static int ast2600_sdram_init(struct udevice *dev)
{
    // 1. Check FPGA mode
    #ifdef CONFIG_FPGA_ASPEED
        // Use fixed FPGA settings
        // Search read window for calibration
    #else
        // 2. Configure MPLL for target frequency
        #if defined(CONFIG_ASPEED_DDR4_1600)
            set_mpll(SCU_MPLL_FREQ_400M, SCU_MPLL_EXT_400M);
        #elif defined(CONFIG_ASPEED_DDR4_1333)
            set_mpll(SCU_MPLL_FREQ_333M, SCU_MPLL_EXT_333M);
        #endif
        
        // 3. Set DDR4 mode registers
        write_mr(DDR4_MR01_MODE);
        write_mr(DDR4_MR23_MODE);
        write_mr(DDR4_MR45_MODE);
        write_mr(DDR4_MR6_MODE);
        
        // 4. Memory training (optional)
        // 5. ECC initialization (if enabled)
    #endif
}
```

### Memory Training Data

```c
/* FPGA read window calibration */
#define SEARCH_RDWIN_ANCHOR_0   (CONFIG_SYS_SDRAM_BASE + 0x0000)
#define SEARCH_RDWIN_ANCHOR_1   (CONFIG_SYS_SDRAM_BASE + 0x0004)
#define SEARCH_RDWIN_PTRN_0     0x12345678
#define SEARCH_RDWIN_PTRN_1     0xaabbccdd
#define SEARCH_RDWIN_PTRN_SUM   0xbcf02355
```

## Pin Control Driver (`drivers/pinctrl/aspeed/pinctrl_ast2600.c`)

### Pin Configuration Structure

```c
struct ast2600_pinctrl_function {
    const char *name;
    const char * const *groups;
    unsigned ngroups;
};

struct ast2600_pinctrl_group {
    const char *name;
    unsigned int *pins;
    unsigned int npins;
};
```

### SCU Pin Control Registers

| Register | Offset | Description |
|----------|--------|-------------|
| `SCU_PINCTRL_BASE` | 0x1e6e2400 | Pin control base |
| `SCU_PINCTRL_LOCK` | 0x1e6e2404 | Pin lock register |

## Platform SCU Registers

### `/mnt/d/code/aspped-github/u-boot/arch/arm/mach-aspeed/ast2600/platform.S`

```assembly
#define SCU_BASE              0x1e6e2000
#define SCU_PROT_KEY1         (SCU_BASE)          /* Magic: 0x1688a8a8 */
#define SCU_PROT_KEY2         (SCU_BASE + 0x010)
#define SCU_REV_ID            (SCU_BASE + 0x014)
#define SCU_SYSRST_CTRL       (SCU_BASE + 0x040)
#define SCU_SYSRST_CTRL_CLR   (SCU_BASE + 0x044)
#define SCU_SYSRST_EVENT      (SCU_BASE + 0x064)
#define SCU_CLK_STOP_CTRL_CLR (SCU_BASE + 0x084)
#define SCU_DEBUG_CTRL        (SCU_BASE + 0x0c8)
#define SCU_DEBUG_CTRL2       (SCU_BASE + 0x0d8)
#define SCU_SMP_NS_EP         (SCU_BASE + 0x180)
#define SCU_SMP_GO            (SCU_BASE + 0x184)
#define SCU_SMP_READY         (SCU_BASE + 0x18c)
#define SCU_SMP_POLLINSN      (SCU_BASE + 0x190)
#define SCU_SMP_S_EP          (SCU_BASE + 0x1bc)
#define SCU_HPLL_PARAM        (SCU_BASE + 0x200)
#define SCU_HPLL_PARAM_EXT    (SCU_BASE + 0x204)
#define SCU_USB_MULTI_FUNC    (SCU_BASE + 0x440)
#define SCU_HW_STRAP1         (SCU_BASE + 0x500)
#define SCU_HW_STRAP2         (SCU_BASE + 0x510)
#define SCU_HW_STRAP3         (SCU_BASE + 0x51c)
#define SCU_CA7_PARITY_CHK    (SCU_BASE + 0x820)
#define SCU_CA7_PARITY_CLR    (SCU_BASE + 0x824)
#define SCU_MMIO_DEC_SET      (SCU_BASE + 0xc24)
```

## Hardware Strapping

### HW_STRAP1 Bits

| Bit | Name | Description |
|-----|------|-------------|
| 2 | eMMC boot | Boot from eMMC when set |
| 6 | MAC1 RGMII | MAC1 uses RGMII (else RMII/NCSI) |
| 7 | MAC2 RGMII | MAC2 uses RGMII (else RMII/NCSI) |
| 8-10 | CPU clock | CPU clock selection |

### HW_STRAP2 Bits

| Bit | Name | Description |
|-----|------|-------------|
| 0 | MAC2 RGMII | MAC2 uses RGMII |
| 1 | MAC3 RGMII | MAC3 uses RGMII |
| 2 | SIO address | SuperIO address (0=2e, 1=4e) |
| 6 | eSPI/LPC | eSPI mode (else LPC) |
| 10 | SPI 3/4 byte | SPI address mode auto detection |
| 11 | ABR enable | Alternate boot region enable |
| 12 | Single flash | Single flash mode (else dual) |
| 16 | SPI1 ABR | SPI1 alternate boot region |
| 17 | SPI1 select | SPI1 pin select enable |
| 22 | FMC aux ctrl | FMC auxiliary control enable |
| 27 | SPI1 aux ctrl | SPI1 auxiliary control enable |

## Configuration Options

| Option | Description |
|--------|-------------|
| `CONFIG_ASPEED_DDR4_1600` | DDR4-1600 speed grade |
| `CONFIG_ASPEED_DDR4_1333` | DDR4-1333 speed grade |
| `CONFIG_ASPEED_DDR4_800` | DDR4-800 speed grade |
| `CONFIG_ASPEED_DDR4_400` | DDR4-400 speed grade |
| `CONFIG_ASPEED_DDR4_DRAM_ODT60` | 60 ohm DRAM ODT |
| `CONFIG_ASPEED_DDR4_DRAM_ODT48` | 48 ohm DRAM ODT |
| `CONFIG_FPGA_ASPEED` | FPGA build target |
| `CONFIG_ASPEED_PALLADIUM` | Palladium simulation |
| `CONFIG_ASPEED_DEFAULT_SPI_FREQUENCY` | Use default SPI clock |