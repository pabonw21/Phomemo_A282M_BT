# Phomemo & QY Bluetooth Thermal Printer Driver for Linux (CUPS & CLI)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Linux-blue.svg)](https://kernel.org)
[![CUPS Compatible](https://img.shields.io/badge/CUPS-2.x-green.svg)](https://openprinting.github.io/cups/)

Enables native **wireless Bluetooth printing on Linux** for **Phomemo A282M, M08F**, and other **QY-based thermal printers**. 

Historically, manufacturers restricted Bluetooth printing to their proprietary mobile applications (iOS/Android) and provided official Linux support only via a wired USB cable. This project breaks that limitation by implementing a native **CUPS Bluetooth RFCOMM backend** and a **standalone CLI printing tool**.

---

## 🌟 Features

- **Native CUPS Integration**: Shows up in your system printer list (Chrome, Firefox, LibreOffice, Evince PDF viewer, GIMP, etc.).
- **Automatic Device Discovery**: Seamlessly detects paired Bluetooth thermal printers via BlueZ D-Bus and populates CUPS (`lpinfo -v`).
- **Bidirectional Backchannel Support**: Implements CUPS `cupsSideChannel` and `cupsBackChannel` handling, properly answering the printer's status queries (`0x1F 0x11 0x07` -> `0x1A 0x07 0x02 0x00 0x03`).
- **Standalone CLI Utility (`phomemo-print`)**: Print images, text, and raw files directly from the terminal or scripts without needing CUPS configured.
- **Floyd-Steinberg Dithering**: High quality image dithering algorithm optimized for 203 DPI thermal print heads.
- **Wide Model Compatibility**: Works with over 45+ Phomemo and QY thermal printer models.

---

## 📋 Supported Printer Models

All printers that share the QY / `rastertoM08F` raster command set are supported:

| Series | Supported Models |
| :--- | :--- |
| **A-Series** | A281M, **A282M**, A285M, A28U, A886, A887 |
| **M-Series** | M08F, M08FS, M08F-WS, M08 pro, M08E, M08E-WS, M04S |
| **M8xx Series** | M831, M832, M832D, M833, M834, M835, M836 |
| **P-Series** | P831, P831Max, P832, P832Max, P833, PR20 |
| **Q-Series** | Q300, Q301, Q301Pro, Q302 |
| **S-Series** | S821, S821K, S821X, S822, S823, SP20 |
| **T/TP-Series** | T08A, T08FS, T831, TP81, TP82, TP83, TP84, TP85, TP86, TP87, TP88 |
| **G-Series** | G100, G100Pro |

---

## 🏗️ How It Works (Architecture)

Standard Linux CUPS printing separates rendering from transport:
1. **Document Rendering**: CUPS processes your document (PDF, image, text) through `pdftoraster` or `imagetoraster`.
2. **Printer Filter**: The raster data is processed by the manufacturer's filter (`rastertoM08F`), which outputs native thermal ESC/POS commands and bitmaps.
3. **Transport (Backend)**: Our custom backend `backend/phomemo-rfcomm` receives the raster stream, establishes a Bluetooth RFCOMM connection (Serial Port Profile, Channel 1) with the printer, synchronizes backchannel status, and transmits the print job wirelessly.

```
[ Application / PDF / Text ]
            │
            ▼
     [ CUPS Scheduler ]
            │
            ▼
    [ CUPS Raster Filter ]
            │
            ▼
 [ rastertoM08F Filter ]
            │ (Stdout: ESC/POS Raster stream)
            │ (FD 3/4: Bidirectional status query)
            ▼
  [ phomemo-rfcomm Backend ]
            │
            ▼ (Bluetooth RFCOMM SPP - Channel 1)
   (((( Wireless ))))
            │
            ▼
 [ Phomemo A282M / M08F Hardware ]
```

---

## 🚀 Installation & Setup

### Prerequisites

- **Linux** (Arch, Debian, Ubuntu, Fedora, Raspberry Pi OS, etc.)
- **CUPS** and `libcups`
- **BlueZ** (Bluetooth stack)
- **Python 3** (with standard `socket` and `dbus` module)
- **Ghostscript** (recommended for general PDF rendering in CUPS)
- **Pillow** (`pip install Pillow` or `python-pillow` package, for image/CLI printing)

On Arch Linux:
```bash
sudo pacman -S cups bluez bluez-utils python python-dbus ghostscript python-pillow
```

On Debian / Ubuntu / Raspberry Pi OS:
```bash
sudo apt-get install cups libcups2-dev bluez python3 python3-dbus ghostscript python3-pil
```

---

### Step 1: Run the Installer (Automatic Discovery & Pairing)

Make sure your Phomemo printer is **powered on** and nearby, then run `install.sh` as root:

```bash
git clone https://github.com/pabwal21/Phomemo_A282M_BT.git
cd Phomemo_A282M_BT
sudo ./install.sh
```

The installer will:
1. Verify system dependencies (`cups`, `python3-dbus`, `ghostscript`, etc.).
2. Copy the CUPS backend to `/usr/lib/cups/backend/phomemo-rfcomm`.
3. Install the PPD printer descriptions to `/usr/share/cups/model/qy/`.
4. Install the raster filter (`rastertoM08F`).
5. Install the standalone CLI utility `/usr/local/bin/phomemo-print`.
6. Restart the CUPS daemon.
7. **Automatically discover, pair, trust, and configure** your Bluetooth printer queue (e.g. `Phomemo_A282M_BT`). If not previously paired, it triggers an active Bluetooth scan or prompts for your printer's MAC address.

---

### Step 2 (Optional / Alternative): Manual Bluetooth Pairing

If you prefer to pair the printer manually before or after running the installer:

**Using the included CLI helper:**
```bash
phomemo-print --pair <YOUR_PRINTER_MAC>
```

**Or using `bluetoothctl`:**
```bash
bluetoothctl
[bluetooth]# power on
[bluetooth]# scan on
[bluetooth]# trust <YOUR_PRINTER_MAC>
[bluetooth]# pair <YOUR_PRINTER_MAC>
[bluetooth]# exit
```
*(Example MAC: `5E:76:58:2F:6C:A3`)*

See [docs/bluetooth_pairing.md](docs/bluetooth_pairing.md) for detailed information on how BlueZ handles SDP profiles and Classic Bluetooth RFCOMM.

---

## 🖨️ Printing

### Option 1: Printing from any Desktop Application
Open any document in Chrome, Firefox, LibreOffice, Evince, Okular, etc., press `Ctrl + P`, and select **Phomemo A282M (Bluetooth)**.

### Option 2: Printing via CUPS Command Line
```bash
lp -d Phomemo_A282M_BT document.pdf
```

### Option 3: Standalone CLI Tool (`phomemo-print`)
You can print images or text directly without going through CUPS:

```bash
# Scan for connected or nearby Bluetooth printers (includes automatic active scan)
phomemo-print --scan

# Force an active 5-second discovery scan
phomemo-print --scan --active

# Pair, trust, and initialize SDP cache for a printer in one command
phomemo-print --pair 5E:76:58:2F:6C:A3

# Print an image (auto-resizes with high-quality dithering)
phomemo-print receipt.png

# Print with specific paper profile (a4, 80mm, 110mm, 53mm)
phomemo-print --paper a4 document.jpg

# Print text directly
phomemo-print --text "Hello from Linux Bluetooth!"

# Print raw binary stream
phomemo-print --raw output.bin
```

---

## 🛠️ Troubleshooting

### Printer Not Discovered Initially (Why did connecting first help?)
In Linux (BlueZ), Bluetooth Classic RFCOMM devices (SPP) do not automatically publish their SDP service records (UUIDs) until an active connection or pairing handshake is made. Furthermore, BlueZ only knows about devices that have been actively scanned or paired.
- The installer now includes an **active scan and pairing assistant** that probes RFCOMM Channel 1 automatically.
- If your printer was not recognized, wake it up (it goes to sleep quickly to save battery), run `phomemo-print --pair <MAC>`, and run `sudo ./install.sh`.
- Detailed technical explanation: see [docs/bluetooth_pairing.md](docs/bluetooth_pairing.md).

### Job Stuck in Processing in CUPS
- Check CUPS error log:
  ```bash
  sudo tail -f /var/log/cups/error_log
  ```
- Test direct connection with CLI:
  ```bash
  phomemo-print --text "Test"
  ```
- Ensure `ghostscript` is installed if printing PDFs.

---

## 📜 Uninstallation

To cleanly remove the backend, queues, and CLI tool:
```bash
sudo ./uninstall.sh
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
Printer PPDs and command protocols remain the property of their respective manufacturers.
