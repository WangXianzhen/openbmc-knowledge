# AST2700 KCS (Keyboard Controller Style) Channel Implementation

## Overview

KCS is a low-level IPMI interface that provides direct access between the host system and BMC through memory-mapped I/O registers. The AST2700 supports multiple KCS channels via both LPC and PCIe interfaces.

## KCS Channel Mapping

### AST2700 KCS Configuration

The AST2700 implements KCS channels via two bus interfaces:

| KCS Channel | Interface | Host Access | AST2700 Configuration |
|-------------|-----------|-------------|------------------------|
| KCS0-KCS3   | LPC       | Host 0      | LPC-KCS (legacy)       |
| KCS8-KCS11  | PCIe      | Host 0      | PCIe-KCS               |
| KCS12-KCS15 | PCIe      | Host 1      | PCIe-KCS (Host 1)      |

### AST2600 KCS Configuration

The AST2600 supports KCS1-KCS8:
- KCS1-4: LPC interface
- KCS5-8: PCIe interface

## Implementation Architecture

```
+------------------+
|   Host System    |
|   (x86/x64 CPU)  |
+------------------+
        |
        | I/O Port Access or Memory-Mapped I/O
        |
        v
+------------------+
|  BMC KCS Bridge  |
|  (LPC/PCIe HW)   |
+------------------+
        |
        | Interrupt (IRQ) + I/O Operations
        |
        v
+------------------+
|  kcsbridge       |
|  (phosphor-ipmi-kcs)
+------------------+
        |
        | D-Bus Messages
        |
        v
+------------------+
| phosphor-ipmi-host |
+------------------+
        |
        | Provider Libraries
        |
        v
+------------------+
| BMC Resources    |
+------------------+
```

## BitBake Configuration

### meta-phosphor Base Recipe

`phosphor-ipmi-kcs_git.bb`:
```bitbake
SUMMARY = "Phosphor OpenBMC KCS to DBUS"
SRC_URI = "git://github.com/openbmc/kcsbridge.git;branch=master;protocol=https"

SYSTEMD_SERVICE:${PN} = "${PN}@${KCS_DEVICE}.service"

KCS_DEVICE ?= "ipmi-kcs3"

PROVIDES += "virtual/obmc-host-ipmi-hw"
RPROVIDES:${PN} += "virtual-obmc-host-ipmi-hw"

RRECOMMENDS:${PN} += "phosphor-ipmi-host"
```

### meta-aspeed-sdk Override

`phosphor-ipmi-kcs_%.bbappend`:
```bitbake
# KCS1/2/3/4: LPC-KCS
# KCS5/6/7/8: PCIe-KCS

KCS_DEVICE = " \
    ipmi-kcs1 \
    ipmi-kcs2 \
    ipmi-kcs3 \
    ipmi-kcs4 \
    ipmi-kcs5 \
    ipmi-kcs6 \
    ipmi-kcs7 \
    ipmi-kcs8 \
"

SYSTEMD_SERVICE:${PN} = " \
    ${PN}@ipmi-kcs1.service \
    ${PN}@ipmi-kcs2.service \
    ${PN}@ipmi-kcs3.service \
    ${PN}@ipmi-kcs4.service \
    ${PN}@ipmi-kcs5.service \
    ${PN}@ipmi-kcs6.service \
    ${PN}@ipmi-kcs7.service \
    ${PN}@ipmi-kcs8.service \
"
```

### AST2700 Specific Override

`meta-ast2700-sdk/recipes-phosphor/ipmi/phosphor-ipmi-kcs_%.bbappend`:
```bitbake
# KCS0/1/2/3: Host0 LPC-KCS
# KCS8/9/10/11: Host0 PCIe-KCS
# KCS12/13/14/15: Host1 PCIe-KCS

KCS_DEVICE = " \
    ipmi-kcs0 \
    ipmi-kcs1 \
    ipmi-kcs2 \
    ipmi-kcs3 \
    ipmi-kcs8 \
    ipmi-kcs9 \
    ipmi-kcs10 \
    ipmi-kcs11 \
    ipmi-kcs12 \
    ipmi-kcs13 \
    ipmi-kcs14 \
    ipmi-kcs15 \
"
```

## Systemd Service Units

The kcsbridge creates one systemd service per KCS channel:
- `phosphor-ipmi-kcs@ipmi-kcs0.service`
- `phosphor-ipmi-kcs@ipmi-kcs1.service`
- ... (one per channel)

## KCS Register Interface

### Standard KCS Registers

| Register | Direction | Description |
|----------|-----------|-------------|
| DATA_IN  | Host->BMC | Write command/data to BMC |
| DATA_OUT | BMC->Host | Read response/data from BMC |
| COMMAND  | Host->BMC | Control commands |
| STATUS   | Bidirectional | Interface status flags |

### KCS Status Register Bits

| Bit | Name | Description |
|-----|------|-------------|
| 0   | OF   | Output Full - BMC has data for host |
| 1   | IF   | Input Full - Host has data for BMC |
| 2   | SA   | Send Status (abort/error) |
| 3   | CMD  | Command/Data selector |
| 4   | S0   | State bit 0 |
| 5   | S1   | State bit 1 |
| 6   | SUS  | Suspend Bit |
| 7   | -    | Reserved |

### KCS State Machine

```
IDLE (S1=0,S0=0)
   |
   | IF=1, CMD=0 → WRITE_START
   |
WRITE_START (S1=0,S0=1)
   |
   | (auto-transition after write) → WRITE
   |
WRITE (S1=1,S0=0)
   |
   | IF=0 → IDLE (if CMD=0) or READ
   | IF=1, CMD=1 → READ_START
   |
READ_START (S1=1,S0=1)
   |
   | (auto-transition after read) → READ
   |
READ (S1=0,S0=1)
   |
   | OF=0 → IDLE
```

## kcsbridge Architecture

### Source Code

The kcsbridge component is maintained externally:
- Repository: `git://github.com/openbmc/kcsbridge.git`
- Branch: `master`
- Commit: `9867112ceb0ae372851384f8c580ebea6ba67217`

### Functionality

1. **Hardware Access Layer**
   - Polls or interrupts on KCS registers
   - Implements KCS state machine
   - Handles DATA_IN/DATA_OUT transfers

2. **Protocol Layer**
   - Parses IPMI message format (NetFn, LUN, Cmd, Data)
   - Validates message structure
   - Calculates/validates checksums

3. **D-Bus Bridge**
   - Publishes incoming messages to D-Bus
   - Subscribes to D-Bus for responses
   - Routes IPMI responses back through KCS

### IPMI Message Format

```
+------+-------+-----+-----+----------+--------+
| NetFn | LUN  | Cmd | Data... | Checksum |
+------+-------+-----+-----+----------+--------+
  1B     2b     1B    nB           1B
```

- **NetFn**: Network function (e.g., 0x06 for Application, 0x30 for OEM)
- **LUN**: Logical Unit Number (usually 0)
- **Cmd**: Command code
- **Data**: Command-specific payload
- **Checksum**: Message checksum

## Channel Configuration

The channel_config.json maps KCS channels to logical channel numbers:

```json
"4" : {
    "name" : "ipmi_kcs1",
    "is_valid" : true,
    "active_sessions" : 0,
    "channel_info" : {
        "medium_type" : "system-interface",
        "protocol_type" : "kcs",
        "session_supported" : "session-less",
        "is_ipmi" : true
    }
}
```

## LPC vs PCIe KCS

### LPC-KCS
- Uses legacy LPC bus interface
- I/O port mapped (0xCA0-0xCA3 for KCS1)
- Lower bandwidth, simpler interface
- Shared with other LPC devices

### PCIe-KCS
- Uses PCIe BAR (Base Address Register) memory mapping
- Higher bandwidth
- Dedicated interrupt support
- Supports multiple KCS channels per PCIe function

## Interrupt Handling

The kcsbridge uses systemd service with interrupt-driven operation:

1. BMC hardware generates interrupt when IF (Input Full) is set
2. kcsbridge service receives interrupt notification
3. Reads DATA_IN register to get command
4. Processes command and sends response
5. Sets OF (Output Full) flag for host

## Configuration in Machine Files

`ast2700-default.conf`:
```bitbake
PREFERRED_PROVIDER_virtual/obmc-host-ipmi-hw = "phosphor-ipmi-kcs"
```

This tells the system to use KCS as the primary host IPMI hardware interface.

## Relevant Files

| Path | Description |
|------|-------------|
| `meta-phosphor/recipes-phosphor/ipmi/phosphor-ipmi-kcs_git.bb` | Base KCS recipe |
| `meta-aspeed-sdk/recipes-phosphor/ipmi/phosphor-ipmi-kcs_%.bbappend` | AST2600 KCS config |
| `meta-aspeed-sdk/meta-ast2700-sdk/recipes-phosphor/ipmi/phosphor-ipmi-kcs_%.bbappend` | AST2700 KCS config |
| `meta-aspeed-sdk/recipes-phosphor/ipmi/phosphor-ipmi-config/channel_config.json` | Channel definitions |

## Troubleshooting

### Check KCS Status
```bash
# View KCS service status
systemctl status phosphor-ipmi-kcs@ipmi-kcs1.service

# View KCS logs
journalctl -u phosphor-ipmi-kcs@ipmi-kcs1.service -f
```

### Common Issues
1. **Host not receiving responses**: Check OF flag, verify DATA_OUT register
2. **BMC not receiving commands**: Check IF flag, verify DATA_IN register
3. **Service not starting**: Check KCS device name, verify hardware access permissions