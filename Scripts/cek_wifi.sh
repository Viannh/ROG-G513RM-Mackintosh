#!/bin/sh
echo "=== 1. Hardware Ports ==="
networksetup -listallhardwareports
echo "=== 2. Kext Loaded ==="
kextstat 2>/dev/null | grep -iE 'mtk|80211|skywalk' || true
echo "=== 3. IOReg MT7922 ==="
ioreg -r -c IOPCIDevice -d 1 | grep -iE -B2 -A12 '14c3|7922|AirportItlwm|MtkHal' | head -n 45
echo "=== 4. Kernel Log (MtkWlan/mwx) ==="
log show --last 5m --predicate 'eventMessage CONTAINS[c] "SimpleMtkWlan" OR eventMessage CONTAINS[c] "AirportMtkWlan" OR eventMessage CONTAINS[c] "mwx"' --style compact 2>/dev/null | tail -n 35
