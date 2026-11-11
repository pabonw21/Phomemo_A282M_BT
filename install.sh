#!/usr/bin/env bash
#
# Installer for Phomemo / QY Bluetooth CUPS Driver & CLI
# Supports A282M, M08F, and other QY thermal printer models.
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}   Phomemo / QY Linux Bluetooth CUPS Driver Setup   ${NC}"
echo -e "${BLUE}====================================================${NC}"
echo

# 1. Root check
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] This installer must be run as root (use sudo ./install.sh)${NC}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 2. Check dependencies
echo -e "${YELLOW}[*] Checking system dependencies...${NC}"

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}[ERROR] Python 3 is required but not installed.${NC}"
    exit 1
fi

if ! python3 -c "import socket; assert hasattr(socket, 'AF_BLUETOOTH')" 2>/dev/null; then
    echo -e "${RED}[ERROR] Python 3 does not have AF_BLUETOOTH support in this kernel.${NC}"
    exit 1
fi

if ! python3 -c "import dbus" 2>/dev/null; then
    echo -e "${YELLOW}[!] Warning: python-dbus is not installed. Automatic Bluetooth printer discovery may be limited.${NC}"
    echo -e "${YELLOW}    Install it via: pacman -S python-dbus (Arch) or apt-get install python3-dbus (Debian/Ubuntu)${NC}"
fi

if ! command -v gs &> /dev/null; then
    echo -e "${RED}[!] WARNING: Ghostscript ('gs') is NOT installed!${NC}"
    echo -e "${RED}    CUPS needs Ghostscript to render PDF print jobs (from Firefox, Chrome, Evince, etc.).${NC}"
    echo -e "${YELLOW}    Install it with: sudo pacman -S ghostscript (Arch) or sudo apt-get install ghostscript (Ubuntu/Debian)${NC}"
fi

# Detect CUPS paths
CUPS_BACKEND_DIR=""
for dir in /usr/lib/cups/backend /usr/libexec/cups/backend /usr/local/lib/cups/backend; do
    if [ -d "$dir" ]; then
        CUPS_BACKEND_DIR="$dir"
        break
    fi
done

CUPS_FILTER_DIR=""
for dir in /usr/lib/cups/filter /usr/libexec/cups/filter /usr/local/lib/cups/filter; do
    if [ -d "$dir" ]; then
        CUPS_FILTER_DIR="$dir"
        break
    fi
done

CUPS_MODEL_DIR=""
for dir in /usr/share/cups/model /usr/share/ppd /usr/local/share/cups/model; do
    if [ -d "$dir" ]; then
        CUPS_MODEL_DIR="$dir/qy"
        break
    fi
done

if [ -z "$CUPS_BACKEND_DIR" ] || [ -z "$CUPS_FILTER_DIR" ]; then
    echo -e "${RED}[ERROR] CUPS directories not found. Please install CUPS (e.g. cups, libcups).${NC}"
    exit 1
fi

echo -e "    CUPS Backend Directory: ${CUPS_BACKEND_DIR}"
echo -e "    CUPS Filter Directory:  ${CUPS_FILTER_DIR}"
echo -e "    CUPS Model Directory:   ${CUPS_MODEL_DIR}"
echo

# 3. Install filter (rastertoM08F)
echo -e "${YELLOW}[*] Setting up raster filter...${NC}"
ARCH="$(uname -m)"
FILTER_SRC=""

if [ -f "$CUPS_FILTER_DIR/rastertoM08F" ]; then
    echo -e "    ${GREEN}✓ Found existing rastertoM08F filter in ${CUPS_FILTER_DIR}${NC}"
else
    # Check filters directory
    if [ -f "$SCRIPT_DIR/filters/rastertoM08F" ]; then
        FILTER_SRC="$SCRIPT_DIR/filters/rastertoM08F"
    elif [ -f "$SCRIPT_DIR/filters/$ARCH/rastertoM08F" ]; then
        FILTER_SRC="$SCRIPT_DIR/filters/$ARCH/rastertoM08F"
    elif [ -d "$SCRIPT_DIR/QY_Printer-2.1.0.3/$ARCH" ]; then
        FILTER_SRC="$SCRIPT_DIR/QY_Printer-2.1.0.3/$ARCH/rastertoM08F"
    fi

    if [ -n "$FILTER_SRC" ] && [ -f "$FILTER_SRC" ]; then
        echo -e "    Copying rastertoM08F (${ARCH}) to ${CUPS_FILTER_DIR}..."
        cp "$FILTER_SRC" "$CUPS_FILTER_DIR/rastertoM08F"
        chmod 755 "$CUPS_FILTER_DIR/rastertoM08F"
        chown root:root "$CUPS_FILTER_DIR/rastertoM08F"
        echo -e "    ${GREEN}✓ Filter installed successfully.${NC}"
    else
        echo -e "${YELLOW}[!] Warning: rastertoM08F binary for $ARCH not found.${NC}"
        echo -e "    Make sure the official QY driver or filter is installed."
    fi
fi

# 4. Install PPD files
echo -e "${YELLOW}[*] Installing PPD descriptions...${NC}"
mkdir -p "$CUPS_MODEL_DIR"
if [ -d "$SCRIPT_DIR/ppd" ]; then
    cp "$SCRIPT_DIR/ppd/"*.ppd "$CUPS_MODEL_DIR/"
    chmod 644 "$CUPS_MODEL_DIR/"*.ppd
    chown -R root:root "$CUPS_MODEL_DIR"
    echo -e "    ${GREEN}✓ Installed $(ls -1 "$SCRIPT_DIR/ppd/"*.ppd | wc -l) PPD files to ${CUPS_MODEL_DIR}${NC}"
fi

# 5. Install CUPS backend
echo -e "${YELLOW}[*] Installing CUPS Bluetooth backend...${NC}"
cp "$SCRIPT_DIR/backend/phomemo-rfcomm" "$CUPS_BACKEND_DIR/phomemo-rfcomm"
chown root:root "$CUPS_BACKEND_DIR/phomemo-rfcomm"
chmod 755 "$CUPS_BACKEND_DIR/phomemo-rfcomm"
echo -e "    ${GREEN}✓ Installed ${CUPS_BACKEND_DIR}/phomemo-rfcomm${NC}"

# 6. Install CLI tool
echo -e "${YELLOW}[*] Installing standalone CLI tool...${NC}"
cp "$SCRIPT_DIR/cli/phomemo-print" /usr/local/bin/phomemo-print
chmod 755 /usr/local/bin/phomemo-print
echo -e "    ${GREEN}✓ Installed /usr/local/bin/phomemo-print${NC}"

# 7. Restart CUPS
echo -e "${YELLOW}[*] Restarting CUPS spooler...${NC}"
if systemctl is-active cups >/dev/null 2>&1 || systemctl is-enabled cups >/dev/null 2>&1; then
    systemctl restart cups
elif command -v service &>/dev/null; then
    service cups restart || true
fi
sleep 1
echo -e "    ${GREEN}✓ CUPS restarted.${NC}"
echo

# 8. Discovery and queue setup
echo -e "${YELLOW}[*] Discovering Bluetooth printers...${NC}"
DISCOVERED_OUTPUT=$("$CUPS_BACKEND_DIR/phomemo-rfcomm" 2>/dev/null || true)

PRINTER_URI=$(echo "$DISCOVERED_OUTPUT" | grep -m1 "direct phomemo-rfcomm://" | awk '{print $2}' || true)
PRINTER_NAME=$(echo "$DISCOVERED_OUTPUT" | grep -m1 "direct phomemo-rfcomm://" | cut -d'"' -f2 || true)

# If not immediately discovered in BlueZ cache, run active discovery and pairing helper
if [ -z "$PRINTER_URI" ]; then
    echo -e "${YELLOW}[!] No printer detected in current BlueZ cache.${NC}"
    echo -e "${YELLOW}[*] Ensuring Bluetooth controller is powered on...${NC}"

    if command -v systemctl &>/dev/null; then
        systemctl start bluetooth >/dev/null 2>&1 || true
    elif command -v service &>/dev/null; then
        service bluetooth start >/dev/null 2>&1 || true
    fi
    bluetoothctl power on >/dev/null 2>&1 || true

    echo -e "${YELLOW}[*] Scanning for nearby Bluetooth printers (5 seconds)...${NC}"
    if command -v timeout &>/dev/null; then
        timeout 5 bluetoothctl scan on >/dev/null 2>&1 || true
    else
        bluetoothctl --timeout 5 scan on >/dev/null 2>&1 || true
    fi

    # Check backend discovery again
    DISCOVERED_OUTPUT=$("$CUPS_BACKEND_DIR/phomemo-rfcomm" 2>/dev/null || true)
    PRINTER_URI=$(echo "$DISCOVERED_OUTPUT" | grep -m1 "direct phomemo-rfcomm://" | awk '{print $2}' || true)
    PRINTER_NAME=$(echo "$DISCOVERED_OUTPUT" | grep -m1 "direct phomemo-rfcomm://" | cut -d'"' -f2 || true)

    # If still not found, check bluetoothctl devices for candidate names
    CANDIDATE_MAC=""
    CANDIDATE_NAME=""
    if [ -z "$PRINTER_URI" ]; then
        CANDIDATES=$(bluetoothctl devices 2>/dev/null | grep -iE "a28|m08|phomemo|d50|m110|m120|m220|p83|m83|s82|t08|tp8|qy|printer" || true)
        if [ -n "$CANDIDATES" ]; then
            CANDIDATE_MAC=$(echo "$CANDIDATES" | head -n1 | awk '{print $2}')
            CANDIDATE_NAME=$(echo "$CANDIDATES" | head -n1 | cut -d' ' -f3-)
            echo -e "${GREEN}[+] Found nearby candidate printer:${NC} ${CANDIDATE_NAME} (${CANDIDATE_MAC})"
        fi

        # If interactive terminal and no candidate auto-found, prompt user
        if [ -z "$CANDIDATE_MAC" ] && [ -t 0 ]; then
            echo
            echo -e "${YELLOW}[?] Make sure your Phomemo printer is powered ON and nearby.${NC}"
            echo -e "    You can enter its Bluetooth MAC address now (e.g. 5E:76:58:2F:6C:A3) to pair automatically."
            read -r -p "    Enter MAC address [or press Enter to skip]: " USER_MAC
            if [ -n "$USER_MAC" ]; then
                CANDIDATE_MAC=$(echo "$USER_MAC" | tr -d ' ' | tr 'a-f' 'A-F')
                CANDIDATE_NAME="A282M"
            fi
        fi

        # If we have a candidate MAC, pair, trust and probe RFCOMM channel 1 to register SDP
        if [ -n "$CANDIDATE_MAC" ]; then
            echo -e "${YELLOW}[*] Trusting and pairing ${CANDIDATE_MAC}...${NC}"
            bluetoothctl trust "$CANDIDATE_MAC" >/dev/null 2>&1 || true
            bluetoothctl pair "$CANDIDATE_MAC" >/dev/null 2>&1 || true

            echo -e "${YELLOW}[*] Probing RFCOMM SPP channel to register BlueZ services...${NC}"
            python3 -c "
import socket
s = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
s.settimeout(2.5)
try:
    s.connect(('$CANDIDATE_MAC', 1))
    s.close()
except Exception:
    pass
" >/dev/null 2>&1 || true

            # Check backend discovery one last time
            DISCOVERED_OUTPUT=$("$CUPS_BACKEND_DIR/phomemo-rfcomm" 2>/dev/null || true)
            PRINTER_URI=$(echo "$DISCOVERED_OUTPUT" | grep -m1 "direct phomemo-rfcomm://" | awk '{print $2}' || true)
            PRINTER_NAME=$(echo "$DISCOVERED_OUTPUT" | grep -m1 "direct phomemo-rfcomm://" | cut -d'"' -f2 || true)

            if [ -z "$PRINTER_URI" ]; then
                DASH_MAC="${CANDIDATE_MAC//:/-}"
                PRINTER_URI="phomemo-rfcomm://${DASH_MAC}/1"
                PRINTER_NAME="${CANDIDATE_NAME:-A282M}"
            fi
        fi
    fi
fi

if [ -n "$PRINTER_URI" ]; then
    echo -e "${GREEN}[+] Configured printer target:${NC} ${PRINTER_NAME} at ${PRINTER_URI}"
    QUEUE_NAME="Phomemo_${PRINTER_NAME// /_}_BT"
    
    # Try finding matching PPD
    MATCH_PPD="qy/${PRINTER_NAME}.ppd"
    if ! lpinfo -m 2>/dev/null | grep -q "$MATCH_PPD"; then
        # Default to A282M or M08F
        MATCH_PPD="qy/A282M.ppd"
    fi

    echo -e "${YELLOW}[*] Registering printer in CUPS queue: ${QUEUE_NAME}...${NC}"
    lpadmin -p "$QUEUE_NAME" -E -v "$PRINTER_URI" -m "$MATCH_PPD" -D "Phomemo ${PRINTER_NAME} (Bluetooth)" -L "Wireless"
    cupsenable "$QUEUE_NAME" 2>/dev/null || true
    cupsaccept "$QUEUE_NAME" 2>/dev/null || true

    echo -e "${GREEN}[SUCCESS] Printer configured!${NC}"
    echo -e "Queue:     ${QUEUE_NAME}"
    echo -e "Device:    ${PRINTER_URI}"
    echo -e "Driver:    ${MATCH_PPD}"
    echo
    echo -e "You can now print from any Linux application (Chrome, LibreOffice, Evince, etc.)!"
else
    echo -e "${YELLOW}[!] No powered-on Bluetooth printer was configured.${NC}"
    echo -e "    Driver and backend were successfully installed."
    echo -e "    To add your printer later once powered on and in range:"
    echo -e "    1. Pair easily via CLI:  phomemo-print --pair <MAC>"
    echo -e "    2. Re-run setup:        sudo ./install.sh"
    echo -e "    Or manually via CUPS:"
    echo -e "    lpadmin -p Phomemo_A282M_BT -E -v phomemo-rfcomm://<MAC-WITH-DASHES>/1 -m qy/A282M.ppd"
fi

echo
echo -e "${BLUE}====================================================${NC}"
echo -e "${GREEN}   Installation complete!                          ${NC}"
echo -e "${BLUE}====================================================${NC}"
