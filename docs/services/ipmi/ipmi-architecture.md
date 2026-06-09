# AST2700 IPMI Architecture Analysis

## Overview

The AST2700 IPMI implementation follows the OpenBMC Phosphor architecture, providing standard IPMI 2.0 interface for system management. This document details the architecture of the IPMI subsystem on the AST2700 platform.

## High-Level Architecture

```
+------------------+     +------------------+     +------------------+
|   Host System    |     |      BMC         |     |   External LAN   |
|   (x86 Server)   |     |   (AST2700)      |     |   (RMCP+)        |
+------------------+     +------------------+     +------------------+
        |                        |                        |
        |<---- KCS (LPC/PCIe) --->|                        |
        |                        |                        |
        |<----------- BT (Block Transfer) ------------>|   |
        |                        |                        |
        |                        |<---------- eth0/eth1 -->|
        |                        |                        |
        |<---- IPMB (I2C) ------>|                        |
        |                        |                        |
        |<---- SSIF (SMBus) ---->|                        |
        |                        |                        |
        |                        +------------------------+


                    +------------------+
                    |   IPMI Services  |
                    +------------------+
                    | phosphor-ipmi-host |
                    | phosphor-ipmi-fru  |
                    | phosphor-ipmi-sel  |
                    | phosphor-ipmi-sensor|
                    +------------------+
                            |
                    +------------------+
                    |   D-Bus Bus      |
                    +------------------+
                            |
                    +------------------+
                    |   BMC Resources  |
                    |   (Sensors,      |
                    |   Inventory,     |
                    |   Controls)      |
                    +------------------+
```

## Channel Configuration

AST2700 supports 16 IPMI channels (0-15), as defined in `channel_config.json`:

| Channel | Name         | Medium Type      | Protocol  | Session Type    |
|---------|--------------|------------------|-----------|-----------------|
| 0       | Ipmb         | IPMB             | IPMB-1.0  | Session-less    |
| 1       | eth0         | LAN-802.3        | IPMI-1.0  | Multi-session   |
| 2       | eth1         | LAN-802.3        | IPMI-1.0  | Multi-session   |
| 3       | ipmi_ssif    | System Interface | IPMI-SMBus| Session-less    |
| 4       | ipmi_kcs1    | System Interface | KCS       | Session-less    |
| 5       | ipmi_kcs2    | System Interface | KCS       | Session-less    |
| 6       | ipmi_kcs3    | System Interface | KCS       | Session-less    |
| 7       | ipmi_kcs4    | System Interface | KCS       | Session-less    |
| 8       | INTRABMC     | OEM              | OEM       | Session-less    |
| 9       | ipmi_kcs5    | System Interface | KCS       | Session-less    |
| 10      | ipmi_kcs6    | System Interface | KCS       | Session-less    |
| 11      | ipmi_kcs7    | System Interface | KCS       | Session-less    |
| 12      | ipmi_kcs8    | System Interface | KCS       | Session-less    |
| 13      | RESERVED     | Reserved         | N/A       | N/A             |
| 14      | SELF         | IPMB             | IPMB-1.0  | Session-less    |
| 15      | RESERVED     | Reserved         | N/A       | N/A             |

## Component Layers

### 1. Hardware Abstraction Layer (KCS Bridge)

```
phosphor-ipmi-kcs (kcsbridge)
    |
    +-- kcs-service@ipmi-kcs{N}.service
    +-- Accesses LPC/PCIe registers directly
    +-- Bridges KCS interrupt/status to D-Bus
```

Source: `git://github.com/openbmc/kcsbridge.git`

### 2. IPMI Daemon (phosphor-ipmi-host)

The main IPMI daemon provides:
- **Host IPMI provider** - Handles commands from KCS/BT channels
- **Net IPMI provider** - Handles commands from LAN (RMCP+)
- **Storage handlers** - FRU, SEL, SDR management
- **Sensor handlers** - Sensor data repository access
- **User management** - User authentication and authorization

### 3. Provider Libraries

The IPMI daemon uses plugin architecture with provider libraries:

| Library               | Functionality                |
|-----------------------|------------------------------|
| libipmi20.so          | IPMI 2.0 command handling    |
| libsysintfcmds.so     | System interface commands    |
| libusercmds.so        | User management commands     |
| libstrgfnhandler.so   | Storage commands (FRU/SEL)   |

## IPMI Recipe Structure

### meta-phosphor Recipes

```
meta-phosphor/recipes-phosphor/ipmi/
    |
    +-- phosphor-ipmi-host_git.bb
    |       Main IPMI daemon
    |       Provides: phosphor-ipmi-host
    |
    +-- phosphor-ipmi-fru_git.bb
    |       FRU (Field Replaceable Unit) inventory
    |       Provides: phosphor-ipmi-fru-inventory
    |
    +-- phosphor-ipmi-fru-properties_%.bbappend
    |       FRU property handlers
    |
    +-- phosphor-ipmi-inventory-sel/
    |       System Event Log (SEL) inventory
    |
    +-- phosphor-ipmi-sensor-inventory/
    |       Sensor Data Repository (SDR) management
    |
    +-- phosphor-ipmi-kcs_git.bb
    |       KCS hardware bridge (kcsbridge)
    |
    +-- phosphor-ipmi-bt/
    |       Block Transfer channel
    |
    +-- phosphor-ipmi-ssif/
    |       SMBus IPMI interface
    |
    +-- phosphor-ipmi-ipmb/
    |       IPMB (IPMI over I2C) bridge
```

### meta-aspeed-sdk Overrides

```
meta-aspeed-sdk/recipes-phosphor/ipmi/
    |
    +-- phosphor-ipmi-kcs_%.bbappend
    |       Enable KCS1-8 for AST2600
    |
    +-- phosphor-ipmi-host_%.bbappend
    |       AST2600 specific configuration
    |
    +-- phosphor-ipmi-bt_%.bbappend
    |       BT channel for host-BMC communication
    |
    +-- phosphor-ipmi-config/
    |       +-- channel_config.json (channel definitions)
    |       +-- dev_id.json (device ID information)
    |
    +-- phosphor-ipmi-net_%.bbappend
    |       LAN channel configuration
    |
    +-- phosphor-ipmi-ssif_%.bbappend
    |       SSIF configuration
```

## Device Identity

Defined in `dev_id.json`:
```json
{
    "id": 32,
    "revision": 1,
    "addn_dev_support": 11,
    "manuf_id": 21862,
    "prod_id": 9728,
    "aux": 1792
}
```

- **Manufacturer ID**: 21862 (0x5568) - OpenBMC Project
- **Product ID**: 9728 (0x2600) - AST2600/AST2700 series
- **Device Revision**: 1

## Build Configuration

In `ast2700-default.conf`:
```
MACHINE_FEATURES += "obmc-host-ipmi"
PREFERRED_PROVIDER_virtual/obmc-host-ipmi-hw = "phosphor-ipmi-kcs"
```

## Security Considerations

1. **Session-less channels**: KCS, BT, SSIF, IPMB are session-less
2. **LAN session security**: RMCP+ with authentication (MD2/MD5/RMCP+)
3. **User privileges**: Configurable privilege levels (Admin, Operator, User)
4. **IPMI 2.0 features**: Platform Event Filter, ARP/Discovery support

## Data Flow

### Host-to-BMC (KCS/BT):
```
Host BMC Driver → KCS Register → kcsbridge → D-Bus → phosphor-ipmi-host → Provider Library → Resources
```

### External (LAN):
```
RMCP+ Client → Network → phosphor-ipmi-host (LAN) → Provider Library → Resources
```

## Relevant Source Files

| Path | Description |
|------|-------------|
| `/mnt/d/code/aspped-github/openbmc/meta-phosphor/recipes-phosphor/ipmi/` | Core IPMI recipes |
| `/mnt/d/code/aspped-github/openbmc/meta-aspeed-sdk/recipes-phosphor/ipmi/` | AST2700 IPMI customizations |
| `/mnt/d/code/aspped-github/openbmc/meta-aspeed-sdk/meta-ast2700-sdk/recipes-phosphor/ipmi/` | AST2700 specific KCS config |
| `/mnt/d/code/aspped-github/openbmc/meta-aspeed-sdk/recipes-phosphor/ipmi/phosphor-ipmi-config/channel_config.json` | Channel definitions |
| `/mnt/d/code/aspped-github/openbmc/meta-aspeed-sdk/recipes-phosphor/ipmi/phosphor-ipmi-config/dev_id.json` | Device ID |