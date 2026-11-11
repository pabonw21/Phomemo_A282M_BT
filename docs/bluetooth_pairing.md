# Bluetooth Discovery & Pairing Guide (BlueZ & CUPS)

This document explains how Bluetooth printer discovery and SDP service caching work in Linux (BlueZ), why you may have experienced discovery issues initially, and how the system now handles it automatically.

---

## 1. Technical Context: How BlueZ Manages Bluetooth Classic (SPP)

Phomemo and QY portable thermal printers communicate using **Bluetooth Classic RFCOMM (Serial Port Profile - SPP)** on Channel 1, rather than Bluetooth Low Energy (BLE GATT).

### Why wasn't the printer found on the first attempt without connecting?

In Linux, the Bluetooth stack (**BlueZ**) operates as follows:

1. **Inquiry Scan vs. Connected Device State:**
   - When a Bluetooth adapter is idling, it does not constantly listen for new Bluetooth Classic devices. A device turned on in the room will not appear in BlueZ's D-Bus registry (`org.bluez.Device1`) until an active scan (`inquiry`) is triggered.
   
2. **SDP (Service Discovery Protocol) Cache Delay:**
   - Even when BlueZ discovers a nearby Bluetooth Classic device by name/MAC address during an inquiry scan, it usually only captures the basic advertising data (Name, RSSI, Class of Device).
   - BlueZ often **defers the full SDP service record resolution** until an actual connection attempt or pairing exchange takes place.
   - Consequently, the `UUIDs` list on D-Bus (which contains the Serial Port Profile UUID `00001101-0000-1000-8000-00805f9b34fb`) remains empty (`[]`) until you attempt to connect.

3. **Legacy Strict Backend Filter:**
   - The original backend required `(has_spp or has_hcrp)` to be present in BlueZ's cached UUID array.
   - If the printer had only been seen in a scan but never connected to, `UUIDs` was empty, causing the backend to reject the printer as "not a known printer" even if its name was literally `A282M`!
   - Attempting to connect manually (`bluetoothctl connect <MAC>` or RFCOMM socket) forced BlueZ to perform the SDP inquiry, populate the SPP UUID in its local storage (`/var/lib/bluetooth/`), and allow the backend to finally detect it.

---

## 2. Improvements Introduced

We implemented several architectural improvements across the installer, CUPS backend, and CLI utility:

### A. Resilient Backend Discovery (`backend/phomemo-rfcomm`)
- **Name-based model matching**: The backend now checks if the device name matches supported printer families (`A282M`, `M08F`, `Phomemo`, `P831`, etc.) **without** requiring BlueZ to have already cached the SPP UUID.
- **Class-of-Device (CoD) awareness**: Properly filters by Bluetooth Imaging/Printer major class (0x06) while ignoring audio devices (headsets, speakers) that might also expose SPP.

### B. Automated Active Scan & Pairing Assistant (`install.sh`)
When you run `sudo ./install.sh`:
1. If the printer is already in BlueZ's cache, it configures it immediately.
2. If not detected initially:
   - Powers on the Bluetooth controller.
   - Runs a 5-second active discovery scan to locate nearby powered-on printers.
   - Automatically trusts (`trust`), pairs (`pair`), and performs an RFCOMM SPP channel 1 probe.
   - Registers the CUPS queue with the appropriate PPD driver without requiring manual `bluetoothctl` commands.
3. If multiple or unannounced devices are present, it allows entering the MAC address interactively.

### C. CLI Pairing & Scanning Helper (`phomemo-print`)
- `phomemo-print --scan`: Automatically scans known devices and falls back to an active scan if none are found.
- `phomemo-print --active`: Force an active 5-second scan.
- `phomemo-print --pair <MAC>`: One-step command to power on, trust, pair, and probe the printer's SPP channel.

---

## 3. Manual Pairing Reference (Fallback)

If you ever need to manually pair or debug via `bluetoothctl`:

```bash
# 1. Open bluetoothctl
bluetoothctl

# 2. Power on adapter and start scan
power on
scan on

# 3. Locate your printer MAC (e.g., 5E:76:58:2F:6C:A3)
# 4. Trust and pair
trust 5E:76:58:2F:6C:A3
pair 5E:76:58:2F:6C:A3

# 5. Exit
exit
```

Once paired, verify discovery with:
```bash
/usr/lib/cups/backend/phomemo-rfcomm
# or
phomemo-print --scan
```
