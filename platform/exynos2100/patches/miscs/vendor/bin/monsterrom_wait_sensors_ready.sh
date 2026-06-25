#!/system/bin/sh

TRY=0

while [ "$TRY" -lt 24 ]; do
    dmesg 2>/dev/null | grep -q "Sensors of MCU are ready" && break
    TRY=$((TRY + 1))
    sleep 1
done

setprop vendor.monsterrom.sensors_ready 1
