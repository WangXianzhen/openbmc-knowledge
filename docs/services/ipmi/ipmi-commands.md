# AST2700 IPMI Command Processing

## Overview

IPMI commands are processed through a layered architecture from hardware channels (KCS, LAN, BT) through the phosphor-ipmi-host daemon to provider libraries and D-Bus resources.

## IPMI Command Structure

### Standard IPMI Message Format

```
+----------------+------+--------+------+---------+------------------+
|   NetFn/LUN    | Cmd  |  Data  | Chk  | Response|   Response Data  |
+----------------+------+--------+------+---------+------------------+
     1 byte        1B    n bytes   1B       1B           n bytes
```

### Network Functions (NetFn)

| NetFn | Name                | Category        |
|-------|---------------------|-----------------|
| 0x06  | App                 | System interface|
| 0x0C  | Platform Event      | Event handling  |
| 0x30  | OEM                 | Vendor specific |
| 0x32  | Storage             | FRU/SEL/SDR     |
| 0x34  | Transport           | LAN/RMCP        |
| 0x28  | Sensor/Event        | Sensors         |

## Command Processing Flow

```
+----------------+
|  IPMI Request  |
|  (KCS/LAN/BT)  |
+--------+-------+ 
         |
         v
+--------+-------+ 
|  IPMI Router   |  phosphor-ipmi-host
+--------+-------+ 
         |
    +----+----+
    |         |
    v         v
+--------+ +--------+
|  NetFn | | Command|
| Handler| | Dispatch|
+--------+ +--------+
    |         |
    v         v
+--------+ +--------+
|  User  | | Provider|
|  Auth  | | Library |
+--------+ +--------+
    |         |
    +----+----+
         |
         v
+--------+-------+ 
|    D-Bus      |  
|   Resources   |  
+--------+-------+ 
         |
         v
+----------------+
|  IPMI Response |
+----------------+
```

## Supported IPMI Commands

### Application (NetFn 0x06)

| Command | Name | Description |
|---------|------|-------------|
| 0x01    | Get Device ID | Get BMC device information |
| 0x22    | Set ACPI Power State | Set system power state |
| 0x23    | Get ACPI Power State | Get system power state |
| 0x2E    | Get Device GUID | Get unique identifier |
| 0x2F    | Get Net Interface Capabilities | LAN config capabilities |
| 0x30    | Set Command EDF | Set Command EDF |
| 0x31    | Get Command EDF | Get Command EDF |
| 0x32    | Get Auth Capabilities | Authentication capabilities |
| 0x34    | Set Session Privilege | Set privilege level |
| 0x35    | Close Session | Terminate session |
| 0x38    | GetSession Info | Get active session info |
| 0x3C    | Get Auth Enabled | Get auth capabilities |
| 0x40    | Set User Access | Configure user permissions |
| 0x41    | Get User Access | Query user permissions |
| 0x42    | Set User Name | Set username |
| 0x43    | Get User Name | Get username |
| 0x44    | Set User Password | Set/validate password |
| 0x45    | Activate Session | Start IPMI session |
| 0x46    | Set BMCPassword | Set BMC password |
| 0x47    | Check PW Supported | Check password support |
| 0x48    | Get BT Capabilities | BT interface capabilities |

### Sensor/Event (NetFn 0x04)

| Command | Name | Description |
|---------|------|-------------|
| 0x01    | Get Sensor Reading | Read sensor value |
| 0x02    | Get Sensor Threshold | Get sensor thresholds |
| 0x03    | Set Sensor Threshold | Configure thresholds |
| 0x04    | Get Sensor Event Enable | Event enable status |
| 0x05    | Set Sensor Event Enable | Enable/disable events |
| 0x06    | Re-arm Sensor Events | Re-arm pending events |
| 0x08    | Get Sensor Reading Factors | Sensor reading factors |
| 0x20    | Platform Event | Event message (PES) |

### Storage (NetFn 0x34)

| Command | Name | Description |
|---------|------|-------------|
| 0x10    | Get FRU Inventory Area Info | FRU size info |
| 0x11    | Read FRU Data | Read FRU data |
| 0x12    | Write FRU Data | Write FRU data |
| 0x20    | Get SDR Repository Info | SDR repository info |
| 0x21    | Get SDR Repository Allocation | SDR allocation |
| 0x22    | Reserve SDR Repository | Reserve for partial read |
| 0x23    | Get SDR | Read SDR record |
| 0x24    | Add SDR | Add SDR record |
| 0x25    | Clear SDR | Clear repository |
| 0x28    | Get SDR Repository Time | Get SDR timestamp |
| 0x29    | Set SDR Repository Time | Set SDR timestamp |
| 0x2F    | Get FRU Inventory Area Info | Get FRU area info |
| 0x40    | Get SEL Info | SEL repository info |
| 0x41    | Get SEL Allocation | SEL allocation |
| 0x42    | Reserve SEL | Reserve for partial read |
| 0x43    | Get SEL Entry | Read SEL record |
| 0x44    | Add SEL Entry | Add SEL record |
| 0x45    | Delete SEL Entry | Remove SEL record |
| 0x46    | Clear SEL | Clear SEL repository |
| 0x47    | Get SEL Time | Get SEL timestamp |
| 0x48    | Set SEL Time | Set SEL timestamp |
| 0x49    | Get Auxiliary Log Status | Get log status |
| 0x5A    | Get SEL Time UTC Offset | Get UTC offset |

### Transport (NetFn 0x0C)

| Command | Name | Description |
|---------|------|-------------|
| 0x01    | Set LAN Configuration | Configure LAN parameters |
| 0x02    | Get LAN Configuration | Query LAN parameters |
| 0x03    | Suspend BMC ARPs | Pause ARP generation |
| 0x04    | Get IP/UDP/RMCP Statistics | Network stats |

## Provider Implementation

### Provider Library Structure

```c
// Each provider implements this interface
struct ipmi_provider_t {
    const char* name;
    int (*accept)(struct ipmi_msg* msg);
    int (*process)(struct ipmi_msg* msg);
    void* user_data;
};
```

### Built-in Providers

```bitbake
# phosphor-ipmi-host_git.bb
HOSTIPMI_PROVIDER_LIBRARY += "libipmi20.so"
HOSTIPMI_PROVIDER_LIBRARY += "libsysintfcmds.so"
HOSTIPMI_PROVIDER_LIBRARY += "libusercmds.so"
HOSTIPMI_PROVIDER_LIBRARY += "libstrgfnhandler.so"

NETIPMI_PROVIDER_LIBRARY += "libipmi20.so"
NETIPMI_PROVIDER_LIBRARY += "libusercmds.so"
```

### libipmi20.so

Core IPMI 2.0 command handling:
- Device ID, device GUID
- Authentication capabilities
- Session management
- Channel authentication

### libsysintfcmds.so

System interface commands:
- Get/Set ACPI power state
- Get system restart cause
- Get system boot options

### libusercmds.so

User management commands:
- Set/Get user access permissions
- Set/Get user name
- Set user password
- User enable/disable

### libstrgfnhandler.so

Storage commands (phosphor-ipmi-host):
- FRU read/write (via phosphor-ipmi-fru-inventory)
- SEL read/write (via phosphor-ipmi-inventory-sel)
- SDR operations (via phosphor-ipmi-sensor-inventory)

## BitBake Build Configuration

### phosphor-ipmi-host Recipe

```bitbake
PACKAGECONFIG ??= " \
    allowlist \
    boot-flag-safe-mode \
    entity-manager-decorators \
    i2c-allowlist \
    libuserlayer \
    softoff \
    transport-null \
    oem-providers \
"

# Provider libraries
HOSTIPMI_PROVIDER_LIBRARY += "libstrgfnhandler.so"

# Systemd services
SYSTEMD_SERVICE:${PN} += "xyz.openbmc_project.Ipmi.Internal.SoftPowerOff.service phosphor-ipmi-host.service"
```

### Sensor YAML Generation

```bitbake
EXTRA_OEMESON = " \
    -Dsensor-yaml-gen=${STAGING_DIR_NATIVE}${sensor_datadir}/sensor.yaml \
    -Dinvsensor-yaml-gen=${STAGING_DIR_NATIVE}${sensor_datadir}/invsensor.yaml \
    -Dfru-yaml-gen=${STAGING_DIR_NATIVE}${config_datadir}/fru_config.yaml \
"
```

## FRU Command Processing

### FRU Read Flow

```
Get Device ID (0x30/0x01)
    |
    v
phosphor-ipmi-host (libstrgfnhandler)
    |
    v
phosphor-ipmi-fru-inventory (D-Bus)
    |
    v
D-Bus Inventory Objects
(/xyz/openbmc_project/inventory/)
    |
    v
FRU Data (EEPROM/Mapped Flash)
```

### FRU Configuration

```yaml
# config.yaml structure
fru:
  - name: "MB"
    type: "System Board"
    data:
      - key: "Board Product"
        value: "AST2700"
      - key: "Board Manufacturer"
        value: "ASPEED"
      - key: "Board Serial"
        path: "/xyz/openbmc_project/inventory/system/Board/Serial"
```

## SEL (System Event Log) Processing

### SEL Command Flow

```
Add SEL Entry (0x34/0x44)
    |
    v
phosphor-ipmi-host (libstrgfnhandler)
    |
    v
phosphor-ipmi-inventory-sel (D-Bus)
    |
    v
phosphor-sel-logger (File/Flash)
    |
    v
SEL Record Storage
```

### SEL Record Format

```c
struct sel_record {
    uint16_t record_id;     // Record ID
    uint8_t  record_type;   // 0x02 = System Event
    uint32_t timestamp;     // Unix timestamp
    uint16_t generator_id;  // Event source
    uint8_t  evm_rev;       // Event format version
    uint8_t  sensor_type;   // Sensor type
    uint8_t  sensor_num;    // Sensor number
    uint8_t  event_dir;     // Direction (assert/deassert)
    uint8_t  event_data[3]; // Event-specific data
} __attribute__((packed));
```

## Sensor Command Processing

### Get Sensor Reading (0x04/0x01)

```
Get Sensor Reading
    |
    v
phosphor-ipmi-host (D-Bus subscription)
    |
    v
dbus-sensors (phosphor-ipmi-sensor-inventory)
    |
    v
Sensor D-Bus Objects
(/xyz/openbmc_project/sensors/)
    |
    v
Sensor HW/I2C/ADC
```

## OEM Extensions

### Aspeed OEM NetFn

AST2700 may implement OEM commands under NetFn 0x30:

| Command | Name | Description |
|---------|------|-------------|
| 0x00    | OEM Get Version | Get firmware version |
| 0x01    | OEM Flash Update | Initiate flash update |
| 0x02    | OEM Boot Control | Control boot source |

### OEM Provider Configuration

```bitbake
OBMC_ORG_IPMI_OEM_PROVIDERS ?= "aspeed"
```

## D-Bus Interface

### IPMI D-Bus Service

```
Service: xyz.openbmc_project.Ipmi.Host@0

Object: /xyz/openbmc_project/Ipmi/Host/0
Interface: xyz.openbmc_project.Ipmi.Host
  - void sendCommand(uint8_t netFn, uint8_t lun, uint8_t cmd, byte[] data)
  - signal command(uint8_t netFn, uint8_t lun, uint8_t cmd, byte[] data)

Object: /xyz/openbmc_project/Ipmi/Internal/SoftPowerOff
Interface: xyz.openbmc_project.Ipmi.Internal.SoftPowerOff
  - void requestSoftPowerOff()
```

### FRU Inventory Interface

```
Service: phosphor-ipmi-fru-inventory

Object: /xyz/openbmc_project/inventory/system/Board
Interface: xyz.openbmc_project.Inventory.Item
  - string Present
  - string PrettyName

Object: /xyz/openbmc_project/inventory/system/Board
Interface: xyz.openbmc_project.Inventory.Item.System
  - string SerialNumber
  - string Model
  - string Manufacturer
```

## Security

### Authentication

1. **Session-less (KCS/BT/SSIF)**: No authentication required
2. **LAN Session (RMCP+)**: 
   - MD2/MD5 password hash
   - RMCP+ (RADIUS-based authentication)
   - Session privilege level enforcement

### Authorization

| Privilege Level | Capabilities |
|-----------------|--------------|
| Callback        | View-only, no configuration |
| User            | Basic sensor reading |
| Operator        | Event configuration, user management |
| Administrator   | Full access |
| OEM             | Vendor-specific extended access |

### User Configuration

```bitbake
# User access configuration via IPMI commands
Set User Access (0x40)
  - Channel number
  - User ID
  - Privilege level
  - Enable/Disable

Set User Password (0x44)
  - User ID
  - Password (16 bytes max for IPMI 2.0)
  - Operation (set/validate/delete)
```

## Troubleshooting

### Common Issues

1. **Command not supported**
   ```bash
   # Check if command is in whitelist
   cat /etc/ipmi/whitelist.d/*.conf
   ```

2. **User authentication failure**
   ```bash
   # View IPMI user configuration
   ipmitool user list 1
   # Reset password
   ipmitool user set password <uid> <password>
   ```

3. **SEL full**
   ```bash
   # View SEL usage
   ipmitool sel info
   # Clear SEL
   ipmitool sel clear
   ```

### Debug Commands

```bash
# Raw IPMI command
ipmitool raw 0x06 0x01    # Get Device ID

# View all sensors
ipmitool sensor list

# View SEL entries
ipmitool sel list

# Read FRU data
ipmitool fru print
```

## Relevant Files

| Path | Description |
|------|-------------|
| `meta-phosphor/recipes-phosphor/ipmi/phosphor-ipmi-host_git.bb` | Main IPMI daemon |
| `meta-phosphor/recipes-phosphor/ipmi/phosphor-ipmi-fru_git.bb` | FRU inventory |
| `meta-phosphor/recipes-phosphor/ipmi/phosphor-ipmi-inventory-sel/` | SEL inventory |
| `meta-phosphor/recipes-phosphor/ipmi/phosphor-ipmi-sensor-inventory/` | Sensor SDR |
| `meta-aspeed-sdk/recipes-phosphor/ipmi/phosphor-ipmi-config/dev_id.json` | Device ID |