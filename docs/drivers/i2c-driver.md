# AST2700 I2C/SMBus and IPMI KCS Driver Analysis

## Overview

This document provides analysis of I2C/SMBus controllers and IPMI KCS (Keyboard Controller Style) interfaces in the AST2700 BMC chip. The AST2700 features an advanced architecture with 16 I2C controllers, multiple I3C controllers, and 16 KCS channels.

## 1. I2C Controller Configuration

### 1.1 Hardware Architecture

The AST2700 contains **16 I2C controllers** (i2c0-i2c15) with the following characteristics:

| Controller | Base Address | Interrupt | Description |
|------------|--------------|-----------|-------------|
| i2c0 | 0x14C0F100 | intc1_2:0 | SMB_PMBUS1_SCM |
| i2c1 | 0x14C0F200 | intc1_2:1 | SMB_IPMB_SCL1 |
| i2c2 | 0x14C0F300 | intc1_2:2 | SMB_CPLD_SCL2 |
| i2c3 | 0x14C0F400 | intc1_2:3 | SMB_PMBUS2_SCM |
| i2c4 | 0x14C0F500 | intc1_2:4 | SMB_PMBUS1_SCM |
| i2c5 | 0x14C0F600 | intc1_2:5 | SMB_TMP_BMC |
| i2c6 | 0x14C0F700 | intc1_2:6 | - |
| i2c7 | 0x14C0F800 | intc1_2:7 | - |
| i2c8 | 0x14C0F900 | intc1_2:8 | SMB_PCIE_SCM (MCTP) |
| i2c9 | 0x14C0FA00 | intc1_2:9 | SMB_HOST_BMC |
| i2c10 | 0x14C0FB00 | intc1_2:10 | SMB_HSBP_BMC (MCTP) |
| i2c11 | 0x14C0FC00 | intc1_2:11 | BMC_HPM_I3C_I2C_13 |
| i2c12 | 0x14C0FD00 | intc1_2:12 | - |
| i2c13 | 0x14C0FE00 | intc1_2:13 | - |
| i2c14 | 0x14C0FF00 | intc1_2:14 | - |
| i2c15 | 0x14C10000 | intc1_2:15 | - |

### 1.2 Register Map

Each I2C controller occupies two register blocks:
- **Device registers**: Base + 0x0-0x9F (160 bytes)
- **Clock/stretch registers**: Base + 0xC0-0xFF (64 bytes)

#### Key Registers

| Register | Offset | Description |
|----------|--------|-------------|
| ASPEED_I2C_FUN_CTRL_REG | 0x00 | Function control (master/slave enable, HDC mode) |
| ASPEED_I2C_AC_TIMING_REG1 | 0x04 | Clock and AC timing configuration |
| ASPEED_I2C_AC_TIMING_REG2 | 0x08 | Timeout and SCL low detection |
| ASPEED_I2C_INTR_CTRL_REG | 0x0C | Interrupt enable |
| ASPEED_I2C_INTR_STS_REG | 0x10 | Interrupt status |
| ASPEED_I2C_CMD_REG | 0x14 | Command/status register |
| ASPEED_I2C_DEV_ADDR_REG | 0x18 | Slave device address |
| ASPEED_I2C_BYTE_BUF_REG | 0x20 | Byte buffer register |

#### Function Control Register (0x00)
```
Bit 15: MULTI_MASTER_DIS   - Disable multi-master arbitration
Bit 8:  SDA_DRIVE_1T_EN    - SDA 1-time drive enable
Bit 7:  M_SDA_DRIVE_1T_EN  - Master SDA 1-time drive
Bit 6:  M_HIGH_SPEED_EN    - Master high speed mode
Bit 1:  SLAVE_EN           - Slave mode enable
Bit 0:  MASTER_EN          - Master mode enable
```

#### Interrupt Sources
```
BIT 14: SDA_DL_TIMEOUT     - SDA download timeout
BIT 13: BUS_RECOVER_DONE   - Bus recovery complete
BIT 7:  SLAVE_MATCH        - Slave address match
BIT 6:  SCL_TIMEOUT        - SCL timeout
BIT 5:  ABNORMAL           - Abnormal stop
BIT 4:  NORMAL_STOP        - Normal stop
BIT 3:  ARBIT_LOSS         - Arbitration loss
BIT 2:  RX_DONE            - Receive complete
BIT 1:  TX_NAK             - Transmit NAK
BIT 0:  TX_ACK             - Transmit ACK
```

### 1.3 Global I2C Registers

Located at `0x14C0F000`, the I2C global block provides:
- **0x00**: Global interrupt status register
- **0x08**: Interrupt target assignment for multi-host environments

### 1.4 Clock Configuration

Default configuration:
- **Clock Frequency**: 100kHz (standard mode)
- **Clock Source**: APB clock via SCU1
- **Reset**: SCU1_RESET_I2C

Timing calculation uses divisor based on `ASPEED_I2CD_TIME_BASE_DIVISOR_MASK`.

## 2. Address Mapping

### 2.1 I2C Bus Address Space

```
0x14C0F000 (0x1100 bytes)
├── I2C Global: 0x00-0xFF
├── i2c0:       0x100-0x19F, 0x1C0-0x1FF
├── i2c1:       0x200-0x29F, 0x2C0-0x2FF
├── ...
└── i2c15:      0x1000-0x109F, 0x10C0-0x10FF
```

### 2.2 BMC Interface to Host

The AST2700 supports multiple host interfaces:

#### LPC Interface (lpc0, lpc1)
- Base: `0x14C31000` (lpc0), `0x14C32000` (lpc1)
- KCS I/O addresses: 0xCA0-0xCA8 (configurable)

#### PCIe LPC Interface (pcie_lpc0, pcie_lpc1)
- Base: `0x12C19000` (pcie_lpc0), `0x12C19800` (pcie_lpc1)
- KCS I/O addresses: 0x3A0-0x3A8 (configurable)

## 3. Interrupt Handling

### 3.1 I2C Interrupts

Each I2C controller uses dedicated interrupts via `intc1_2` (interrupt controller 1, group 2):

| Controller | IRQ Number | Description |
|------------|------------|-------------|
| i2c0 | intc1_2:0 | Device 0 interrupt |
| i2c1 | intc1_2:1 | Device 1 interrupt |
| ... | ... | ... |
| i2c15 | intc1_2:15 | Device 15 interrupt |

The interrupt controller chain:
```
GIC SPI → intc0_11 → intc1_2 (I2C group)
```

### 3.2 KCS Interrupts

KCS channels generate SerIRQ interrupts. Configuration via:
- **HICR0**: LPC channel enable (bits 5-7 for channels 1-3)
- **HICR2**: Input buffer full interrupt enable
- **HICR5**: SerIRQ selection for channels 2-3
- **SIRQCR0**: Legacy IRQ assignment (deprecated in AST2600 A3+)

## 4. IPMI KCS Interface

### 4.1 KCS Channel Overview

The AST2700 supports **16 KCS channels** across multiple host interfaces:

| Interface | Channels | I/O Address | IRQ Range |
|-----------|----------|-------------|-----------|
| LPC0 | KCS0-3 | 0xCA0-0xCA8 | intc1_0:4-7 |
| LPC1 | KCS4-7 | 0xCA0-0xCA8 | intc1_1:4-7 |
| PCIe LPC0 | KCS8-11 | 0x3A0-0x3A8 | GIC_SPI 74-77 |
| PCIe LPC1 | KCS12-15 | 0x3A0-0x3A8 | GIC_SPI 87-90 |

### 4.2 KCS Register Map

Each KCS channel uses three I/O registers:

| Register | LPC Offset | PCIe LPC Offset | Description |
|----------|------------|-----------------|-------------|
| IDR (Input Data) | +0x24/28/2C | +0x24/28/2C | Host to BMC data |
| ODR (Output Data) | +0x30/34/38 | +0x30/34/38 | BMC to Host data |
| STR (Status) | +0x3C/40/44 | +0x3C/40/44 | Status/control |

#### KCS4 Additional Registers (AST2700)
| Register | Offset | Description |
|----------|--------|-------------|
| IDR4 | 0x114 | Channel 4 input data |
| ODR4 | 0x118 | Channel 4 output data |
| STR4 | 0x11C | Channel 4 status |
| HICRB | 0x100 | Channel 4 enable and config |

### 4.3 KCS Status Register Bits

```
BIT 7: OBF - Output Buffer Full (BMC wrote data)
BIT 6: IBF - Input Buffer Full (Host wrote data)
BIT 5: SMM - System Management Mode (not used)
BIT 4: TIMEOUT - Interface timeout
BIT 1: C/D - Command/Data (1=CMD, 0=DATA)
BIT 0: READY - KCS ready for operation
```

### 4.4 KCS Signal Flow

```
Host BMC
  Write IDR → [IBF=1] → BMC IRQ → Read IDR
                                    ↓
  BMC processes command
                                    ↓
  Write ODR → [OBF=1] → Host IRQ → Read ODR
```

### 4.5 DCSCM Configuration (ast2700-dcscm.dts)

Default DCSCM enables KCS channels 0-3 via LPC0:

```dts
&lpc0_kcs0 {
    status = "okay";
    kcs-io-addr = <0xca0>;
    kcs-channel = <0>;
};

&lpc0_kcs1 {
    status = "okay";
    kcs-io-addr = <0xca8>;
    kcs-channel = <1>;
};

&lpc0_kcs2 {
    status = "okay";
    kcs-io-addr = <0xca2>;
    kcs-channel = <2>;
};

&lpc0_kcs3 {
    status = "okay";
    kcs-io-addr = <0xca4>;
    kcs-channel = <3>;
};
```

### 4.6 OpenBMC KCS Service Configuration

The `phosphor-ipmi-kcs` service uses systemd instances for each KCS channel:

```
/lib/systemd/system/phosphor-ipmi-kcs@.service
```

Services spawned:
- `phosphor-ipmi-kcs@ipmi-kcs0.service`
- `phosphor-ipmi-kcs@ipmi-kcs1.service`
- ... (up to ipmi-kcs15)

Device nodes:
- `/dev/ipmi-kcs0` through `/dev/ipmi-kcs15`

## 5. I3C Controllers (Extended I2C)

AST2700 includes **16 I3C controllers** (i3c0-i3c15) that support:
- I3C protocol (improved I2C with higher speed)
- Backward compatible with I2C

### I3C Controller Map

| Controller | Base Address | Description |
|------------|--------------|-------------|
| i3c0 | 0x14C20000 | BMC_HPM_I3C_I2C_14 |
| i3c1 | 0x14C21000 | BMC_I2C_I3C1_SCL1 |
| i3c2 | 0x14C22000 | BMC_I2C_I3C2_SCL2 |
| i3c3 | 0x14C23000 | I3C_DBG_SCM |
| i3c4 | 0x14C24000 | I3C_PFR_BMC (target) |
| i3c5 | 0x14C25000 | I3C_MNG_BMC_SCM |
| i3c6 | 0x14C26000 | I3C_SPD_SCM |
| i3c7-i3c15 | 0x14C27000-0x14C2F000 | Reserved |

Note: i3c4 is configured as target device (PID 0x7EC) for MCTP over I3C.

## 6. Driver Source Files

### Kernel Drivers
```
drivers/i2c/busses/i2c-aspeed.c       - I2C controller driver
drivers/char/ipmi/kcs_bmc_aspeed.c    - KCS BMC driver
drivers/irqchip/irq-aspeed-i2c-ic.c   - I2C interrupt controller
```

### Device Tree Bindings
```
Documentation/devicetree/bindings/i2c/aspeed,i2c.yaml
Documentation/devicetree/bindings/ipmi/aspeed,ast2400-kcs-bmc.yaml
Documentation/devicetree/bindings/interrupt-controller/aspeed,ast2400-i2c-ic.yaml
```

## 7. Build Configuration

### Kernel Config Options
```
CONFIG_I2C_ASPEED           - I2C controller support
CONFIG_IPMI_KCS_BMC_ASPEED  - KCS device driver
CONFIG_I2C_DESIGNWARE_CORE  - DesignWare I2C (if used)
```

### OpenBMC Packages
```
phosphor-ipmi-kcs           - IPMI KCS daemon
i2c-tools                   - I2C debugging utilities
i2cdev                      - I2C dev driver
```

## 8. Usage Examples

### 8.1 I2C Bus Access
```bash
# List I2C buses
ls /sys/bus/i2c/devices/

# Scan bus for devices
i2cdetect -y 0

# Read from device
i2cget -y 0 0x50 0x00

# Write to device
i2cset -y 0 0x50 0x00 0xAA
```

### 8.2 KCS Device Access
```bash
# Check KCS devices
ls /dev/ipmi-kcs*

# Monitor KCS interface via IPMI
ipmitool mc info
```

## 9. References

- `/mnt/d/code/aspped-github/linux/arch/arm64/boot/dts/aspeed/aspeed-g7.dtsi`
- `/mnt/d/code/aspped-github/linux/arch/arm64/boot/dts/aspeed/ast2700-dcscm.dts`
- `/mnt/d/code/aspped-github/linux/drivers/i2c/busses/i2c-aspeed.c`
- `/mnt/d/code/aspped-github/linux/drivers/char/ipmi/kcs_bmc_aspeed.c`
- `/mnt/d/code/aspped-github/openbmc/meta-aspeed-sdk/meta-ast2700-sdk/recipes-phosphor/ipmi/phosphor-ipmi-kcs_%.bbappend`