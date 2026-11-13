#!/usr/bin/env bash
#
# Uninstaller for Phomemo / QY Bluetooth CUPS Driver & CLI
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}  Phomemo / QY Linux Bluetooth Driver Uninstaller   ${NC}"
echo -e "${BLUE}====================================================${NC}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] This uninstaller must be run as root (use sudo ./uninstall.sh)${NC}"
    exit 1
fi

# Detect CUPS backend
CUPS_BACKEND_DIR=""
for dir in /usr/lib/cups/backend /usr/libexec/cups/backend /usr/local/lib/cups/backend; do
    if [ -f "$dir/phomemo-rfcomm" ]; then
        CUPS_BACKEND_DIR="$dir"
        break
    fi
done

echo -e "${YELLOW}[*] Removing CUPS print queues using phomemo-rfcomm...${NC}"
if command -v lpstat &>/dev/null; then
    lpstat -v 2>/dev/null | grep "phomemo-rfcomm://" | cut -d: -f1 | awk '{print $NF}' | while read -r queue; do
        if [ -n "$queue" ]; then
            echo "    Removing queue: $queue"
            lpadmin -x "$queue" || true
        fi
    done
fi

if [ -n "$CUPS_BACKEND_DIR" ] && [ -f "$CUPS_BACKEND_DIR/phomemo-rfcomm" ]; then
    echo -e "${YELLOW}[*] Removing backend ${CUPS_BACKEND_DIR}/phomemo-rfcomm...${NC}"
    rm -f "$CUPS_BACKEND_DIR/phomemo-rfcomm"
fi

if [ -f /usr/local/bin/phomemo-print ]; then
    echo -e "${YELLOW}[*] Removing /usr/local/bin/phomemo-print...${NC}"
    rm -f /usr/local/bin/phomemo-print
fi

# Clean up QY PPD directory
for model_dir in /usr/share/cups/model/qy /usr/share/ppd/qy /usr/local/share/cups/model/qy; do
    if [ -d "$model_dir" ]; then
        echo -e "${YELLOW}[*] Removing PPD directory ${model_dir}...${NC}"
        rm -rf "$model_dir"
    fi
done

echo -e "${YELLOW}[*] Restarting CUPS spooler...${NC}"
if systemctl is-active cups >/dev/null 2>&1; then
    systemctl restart cups
elif command -v service &>/dev/null; then
    service cups restart || true
fi

echo -e "${GREEN}[SUCCESS] Phomemo Bluetooth driver uninstalled successfully.${NC}"
