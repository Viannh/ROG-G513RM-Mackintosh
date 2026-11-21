#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] Run with sudo: sudo sh $0"
    exit 1
fi

echo "=== Configuring Safe Power Management (S0ix Workaround) for ASUS ROG Strix G513RM ==="
pmset -a sleep 0
pmset -a hibernatemode 0
pmset -a standby 0
pmset -a autopoweroff 0
pmset -a powernap 0
pmset -a proximitywake 0
pmset -a tcpkeepalive 0
pmset -a ttyskeepawake 0
pmset -b displaysleep 10
pmset -c displaysleep 15

if [ -f /var/vm/sleepimage ]; then
    rm -f /var/vm/sleepimage
fi

echo ""
echo "=== Current pmset configuration ==="
pmset -g custom
echo ""
echo "[OK] Done! Display Sleep is safely configured without S3/S0ix sleep crash."
