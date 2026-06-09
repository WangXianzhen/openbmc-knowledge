# U-Boot SPL (Secondary Program Loader) Design

## File Overview

The SPL (Secondary Program Loader) is the first-stage bootloader running on the main ARM core, responsible for:
1. Initial platform setup
2. DRAM initialization
3. Loading and verifying the main U-Boot image

## Source File

`/mnt/d/code/aspped-github/u-boot/arch/arm/mach-aspeed/ast2600/spl.c`

## Key Constants

```c
#define AST_BOOTMODE_SPI    0   // Boot from SPI flash
#define AST_BOOTMODE_EMMC   1   // Boot from eMMC
#define AST_BOOTMODE_UART   2   // Boot via UART (Xmodem)

#define SCU_BASE           0x1e6e2000
#define SCU_SMP_SEC_ENTRY  (SCU_BASE + 0x1bc)  // Secure entry point
#define SCU_WPROT2         (SCU_BASE + 0xf04)  // Write protection 2
```

## Main Functions

### `board_init_f()` - SPL Entry Point

```c
void board_init_f(ulong dummy)
{
    struct udevice *dev;
    
    spl_early_init();                    // Early SPL initialization
    timer_init();                        // Initialize ARM timer
    uclass_get_device(UCLASS_PINCTRL, 0, &dev);  // Initialize pinctrl
    preloader_console_init();            // UART console setup
    dram_init();                         // DRAM initialization
    aspeed_mmc_init();                   // eMMC controller init
    spl_boot_from_uart_wdt_disable();    // Disable WDT for UART boot
}
```

### `spl_board_init()` - Board-Specific Init

```c
#ifdef CONFIG_SPL_BOARD_INIT
void spl_board_init(void)
{
    struct udevice *dev;
    
    // Initialize HACE (Hash and Crypto Engine) if enabled
    if (IS_ENABLED(CONFIG_ASPEED_HACE) &&
        uclass_get_device_by_driver(UCLASS_MISC,
                    DM_GET_DRIVER(aspeed_hace),
                    &dev)) {
        debug("Warning: HACE initialization failure\n");
    }
}
#endif
```

### `spl_boot_device()` - Boot Device Selection

```c
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
        break;
    }
    return BOOT_DEVICE_NONE;
}
```

### `spl_start_uboot()` - OS Boot Decision

```c
#ifdef CONFIG_SPL_OS_BOOT
int spl_start_uboot(void)
{
    // Always boot U-Boot (not directly to Linux)
    return 0;
}
#endif
```

### `spl_fit_images_get_uboot_entry()` - FIT Image Parsing

```c
int spl_fit_images_get_uboot_entry(void *blob, uintptr_t *entry)
{
    int parent, node, ndepth;
    const void *data;
    
    // Find /fit-images node
    parent = fdt_path_offset(blob, "/fit-images");
    if (parent < 0)
        return -FDT_ERR_NOTFOUND;
    
    // Search for U-Boot image
    for (node = fdt_next_node(blob, parent, &ndepth);
         (node >= 0) && (ndepth > 0);
         node = fdt_next_node(blob, node, &ndepth)) {
        if (ndepth != 1)
            continue;
        
        data = fdt_getprop(blob, node, FIT_OS_PROP, NULL);
        if (!data)
            continue;
        
        if (genimg_get_os_id(data) == IH_OS_U_BOOT)
            break;
    }
    
    *entry = fdt_getprop_u32(blob, node, "entry-point");
    if (*entry == FDT_ERROR)
        *entry = fdt_getprop_u32(blob, node, "load-addr");
    
    return 0;
}
```

### `spl_optee_entry()` - OP-TEE OS Loading

```c
void spl_optee_entry(void *arg0, void *arg1, void *arg2, void *arg3)
{
    uintptr_t optee_ns_ep;
    int rc;
    
    // Get non-secure entry point from FIT image
    rc = spl_fit_images_get_uboot_entry(arg2, &optee_ns_ep);
    if (rc)
        goto err_hang;
    
    // Jump to OP-TEE
    asm volatile(
        "mov lr, %[ns_ep]\n\t"
        "mov r0, %[a0]\n\t"
        "mov r1, %[a1]\n\t"
        "mov r2, %[a2]\n\t"
        "bx %[a3]\n\t"
        : [ns_ep]"r" (optee_ns_ep), [a0]"r" (arg0), [a1]"r" (arg1), [a2]"r" (arg2), [a3]"r" (arg3)
        : "lr", "r0", "r1", "r2"
    );
    
err_hang:
    debug("cannot find NS image entry for OPTEE\n");
    hang();
}
```

### `board_fit_image_post_process()` - TEE Secure Entry

```c
void board_fit_image_post_process(const void *fit, int node, void **p_image, size_t *p_size)
{
    ulong s_ep;
    uint8_t os;
    
    // Only process TEE images
    fit_image_get_os(fit, node, &os);
    if (os != IH_OS_TEE)
        return;
    
    // Get secure entry point
    fit_image_get_entry(fit, node, &s_ep);
    
    // Set & lock secure entry point for secondary cores
    writel(s_ep, SCU_SMP_SEC_ENTRY);
    writel(BIT(17) | BIT(18) | BIT(19), SCU_WPROT2);
}
```

### `spl_boot_from_uart_wdt_disable()` - UART Boot WDT

```c
static void spl_boot_from_uart_wdt_disable(void)
{
    int boot_mode = aspeed_bootmode();
    
    // Disable ABR WDT for SPI flash and eMMC ABR
    if (boot_mode == AST_BOOTMODE_UART) {
        writel(0, 0x1e620064);      // FMC WDT
        writel(0, 0x1e6f20a0);      // eMMC WDT
    }
}
```

## SPL Boot Flow

```
+------------------------------------------+
|           SPL Boot Sequence              |
+------------------------------------------+
|                                          |
|  1. Reset Handler                        |
|     - Initial stack setup                |
|     - Low-level init (platform.S)        |
|                                          |
|  2. board_init_f()                       |
|     - spl_early_init()                   |
|     - timer_init()                       |
|     - pinctrl init                       |
|     - preloader_console_init()           |
|     - dram_init()                        |
|     - aspeed_mmc_init()                  |
|                                          |
|  3. Load FIT Image                       |
|     - Read from boot device              |
|     - Verify FIT signature               |
|                                          |
|  4. board_fit_image_post_process()       |
|     - Set secure entry point             |
|     - Configure TEE (if present)         |
|                                          |
|  5. Jump to U-Boot or TEE                |
|                                          |
+------------------------------------------+
```

## Dependencies

| Header | Purpose |
|--------|---------|
| `common.h` | Common definitions |
| `debug_uart.h` | Debug UART support |
| `spl.h` | SPL framework |
| `dm.h` | Driver model |
| `mmc.h` | MMC/eMMC support |
| `asm/io.h` | I/O operations |
| `asm/arch/aspeed_verify.h` | Image verification |

## Configuration Options

| Option | Description |
|--------|-------------|
| `CONFIG_SPL` | Enable SPL support |
| `CONFIG_SPL_BOARD_INIT` | Call spl_board_init() |
| `CONFIG_SPL_OS_BOOT` | Support direct OS boot |
| `CONFIG_ASPEED_HACE` | Enable HACE crypto engine |
| `CONFIG_SPL_MMC` | MMC boot support |
| `CONFIG_SPL_SPI` | SPI boot support |
| `CONFIG_SPL_UART` | UART boot support (Xmodem) |

## Memory Layout

```
0x00000000  +------------------+  ROM (BootROM)
            | BootROM          |
0x10000000  +------------------+  SPI Flash
            | FMC Region 0     |
0x1e620000  +------------------+  FMC Registers
0x1e6e2000  +------------------+  SCU Registers
0x1e6f2000  +------------------+  Security Engine
0x1e780000  +------------------+  GPIO Registers
0x80000000  +------------------+  DRAM
            | Kernel/DTB       |
            +------------------+
```