#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] Run with sudo: sudo sh $0"
    exit 1
fi

echo "=== Configuring Safe Power Management (S0ix Workaround + Battery Tuning) for G513RM ==="
pmset -a sleep 0
pmset -a hibernatemode 0
pmset -a standby 0
pmset -a autopoweroff 0
pmset -a powernap 0
pmset -a proximitywake 0
pmset -a tcpkeepalive 0
pmset -a ttyskeepawake 0

# Battery-saving profile
pmset -b lowpowermode 1
pmset -b lessbright 1
pmset -b displaysleep 5
pmset -b disksleep 5

# AC performance profile
pmset -c lowpowermode 0
pmset -c displaysleep 15
pmset -c disksleep 10

if [ -f /var/vm/sleepimage ]; then
    rm -f /var/vm/sleepimage
fi

echo ""
echo "=== Current pmset configuration ==="
pmset -g custom
echo ""
echo "[OK] Done! Safe Display Sleep and Battery Low Power Mode configured."
