#!/usr/bin/env bash
# Copyright (c) 2026
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

TARGET_CODENAME="${1:-t2s}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$SRC_DIR"
source "$SRC_DIR/buildenv.sh" "$TARGET_CODENAME" > /dev/null

MODULE_ID="monsterrom_oneui9_patches"
MODULE_NAME="MonsterROM One UI 9 patches"
MODULE_VERSION="1.0-${ROM_VERSION:-local}"
MODULE_VERSION_CODE="$(date +%Y%m%d)"
MODULE_ROOT="$OUT_DIR/ksunext/$MODULE_ID"
ZIP_PATH="$OUT_DIR/ksunext/${MODULE_ID}_${TARGET_CODENAME}.zip"

copy_payload()
{
    local SRC_REL="$1"
    local DST_REL="$2"
    local SRC="$WORK_DIR/$SRC_REL"
    local DST="$MODULE_ROOT/$DST_REL"

    if [ ! -f "$SRC" ]; then
        echo "Missing payload: ${SRC//$SRC_DIR\//}" >&2
        return 1
    fi

    mkdir -p "$(dirname "$DST")"
    cp -a "$SRC" "$DST"
}

rm -rf "$MODULE_ROOT"
mkdir -p "$MODULE_ROOT"

cat > "$MODULE_ROOT/module.prop" <<EOF
id=$MODULE_ID
name=$MODULE_NAME
version=$MODULE_VERSION
versionCode=$MODULE_VERSION_CODE
author=Codex
description=Systemless MonsterROM One UI 9 feature patches with KernelSU Next EROFS bind fallback.
EOF

cat > "$MODULE_ROOT/customize.sh" <<'EOF'
ui_print "- Installing MonsterROM One UI 9 patches"
ui_print "- KernelSU Next/EROFS bind fallback is enabled via post-mount.sh"
ui_print "- Runtime repair service is enabled via service.sh"

set_perm_recursive "$MODPATH/system" 0 0 0755 0644 u:object_r:system_file:s0
set_perm_recursive "$MODPATH/vendor" 0 0 0755 0644 u:object_r:vendor_file:s0
set_perm_recursive "$MODPATH/system/lib64" 0 0 0755 0644 u:object_r:system_lib_file:s0
set_perm_recursive "$MODPATH/vendor/etc" 0 0 0755 0644 u:object_r:vendor_configs_file:s0
set_perm_recursive "$MODPATH/vendor/lib64" 0 0 0755 0644 u:object_r:vendor_file:s0
set_perm "$MODPATH/system.prop" 0 0 0644 u:object_r:system_file:s0
set_perm "$MODPATH/sepolicy.rule" 0 0 0644 u:object_r:system_file:s0
set_perm "$MODPATH/post-mount.sh" 0 0 0755 u:object_r:system_file:s0
set_perm "$MODPATH/service.sh" 0 0 0755 u:object_r:system_file:s0
EOF

cat > "$MODULE_ROOT/system.prop" <<'EOF'
# Newer Samsung Camera app parity flag from the supplied One UI feature set.
ro.camera.default_app_social_media_parity_enabled=true
ro.camera.disableHeicUltraHDR=true
ro.camera.enableCamera1MaxZsl=1
ro.sf.lcd_density=450
ro.sf.init.lcd_density=450
EOF

cat > "$MODULE_ROOT/sepolicy.rule" <<'EOF'
allow platform_app_36 SemInputDeviceManager_service service_manager find
allow platform_app_36 system_prop property_service set
allow keystore Hermes_service service_manager find
EOF

cat > "$MODULE_ROOT/post-mount.sh" <<'EOF'
#!/system/bin/sh

MODDIR=${0%/*}
BUSYBOX=/data/adb/ksu/bin/busybox
[ -x "$BUSYBOX" ] || BUSYBOX=/data/adb/magisk/busybox
[ -x "$BUSYBOX" ] || BUSYBOX=busybox

log_msg()
{
    echo "monsterrom_oneui9_patches: $*" > /dev/kmsg 2>/dev/null || true
}

fix_sensor_permissions()
{
    local NODE

    for NODE in \
        /sys/class/lcd/panel/smooth_dim \
        /sys/class/lcd/panel/screen_mode \
        /sys/class/lcd/panel/vrr_lfd \
        /sys/class/power_supply/battery/batt_after_manufactured \
        /sys/class/usb_notify/usb_control/usb_hw_param; do
        [ -e "$NODE" ] || continue
        chown system:system "$NODE" 2>/dev/null || true
        chmod 0664 "$NODE" 2>/dev/null || true
    done

    for NODE in /sys/class/sec/switch/afc_disable; do
        [ -e "$NODE" ] || continue
        chown system:radio "$NODE" 2>/dev/null || true
        chmod 0664 "$NODE" 2>/dev/null || true
    done

    for NODE in /sys/bbd/lk_enable; do
        [ -e "$NODE" ] || continue
        chown gps:system "$NODE" 2>/dev/null || true
        chmod 0664 "$NODE" 2>/dev/null || true
    done

    for NODE in \
        /sys/class/sensors/ssp_sensor/data_injection_enable \
        /sys/class/sensors/ssp_sensor/enable \
        /sys/class/sensors/ssp_sensor/enable_irq \
        /sys/class/sensors/ssp_sensor/mcu_sleep_test \
        /sys/class/sensors/ssp_sensor/mcu_test \
        /sys/class/sensors/ssp_sensor/sensor_dump \
        /sys/class/sensors/ssp_sensor/ssp_control; do
        [ -e "$NODE" ] || continue
        chown system:radio "$NODE" 2>/dev/null || true
        chmod 0664 "$NODE" 2>/dev/null || true
    done

    for NODE in \
        /sys/class/sensors/ssp_sensor/ssp_flush \
        /sys/class/sensors/sensor_dev/flush; do
        [ -e "$NODE" ] || continue
        chown system:radio "$NODE" 2>/dev/null || true
        chmod 0220 "$NODE" 2>/dev/null || true
    done

    for NODE in /sys/bus/iio/devices/iio:device*/poll_delay \
        /sys/bus/iio/devices/iio:device*/buffer/enable \
        /sys/bus/iio/devices/iio:device*/buffer/length; do
        [ -e "$NODE" ] || continue
        chown system:system "$NODE" 2>/dev/null || true
        chmod 0660 "$NODE" 2>/dev/null || true
    done
}

restart_sensors_after_mcu_ready()
{
    (
        local TRY

        stop vendor.sensors-hal-2-0-multihal >/dev/null 2>&1 \
            || setprop ctl.stop vendor.sensors-hal-2-0-multihal >/dev/null 2>&1 \
            || true

        TRY=0
        while [ "$TRY" -lt 24 ]; do
            dmesg 2>/dev/null | grep -q "Sensors of MCU are ready" && break
            TRY=$((TRY + 1))
            sleep 1
        done

        start vendor.sensors-hal-2-0-multihal >/dev/null 2>&1 \
            || setprop ctl.start vendor.sensors-hal-2-0-multihal >/dev/null 2>&1 \
            || true
        log_msg "sensor HAL start requested after sensorhub wait"
    ) &
}

mount_system_lib64_overlay()
{
    local SRC="$MODDIR/system/lib64/libpenguin.so"
    local BASE="/dev/monsterrom_oneui9_patches_system_lib64"
    local UPPER="$BASE/upper"
    local WORK="$BASE/work"

    [ -f "$SRC" ] || return 0
    [ -d /system/lib64 ] || return 0

    if [ -e /system/lib64/libpenguin.so ]; then
        return 0
    fi

    if grep -q " /system/lib64 " /proc/mounts 2>/dev/null; then
        return 0
    fi

    rm -rf "$BASE" 2>/dev/null || true
    mkdir -p "$BASE" 2>/dev/null || return 0
    mount -t tmpfs -o mode=0755,size=4m tmpfs "$BASE" 2>/dev/null || {
        log_msg "tmpfs upper mount failed for /system/lib64 overlay"
        return 0
    }

    mkdir -p "$UPPER" "$WORK" 2>/dev/null || {
        umount "$BASE" 2>/dev/null || true
        return 0
    }

    cp -af "$SRC" "$UPPER/libpenguin.so" 2>/dev/null || {
        umount "$BASE" 2>/dev/null || true
        return 0
    }
    chown 0:0 "$UPPER/libpenguin.so" 2>/dev/null || true
    chmod 0644 "$UPPER/libpenguin.so" 2>/dev/null || true
    chcon u:object_r:system_lib_file:s0 "$UPPER/libpenguin.so" 2>/dev/null || true

    mount -t overlay overlay \
        -o "lowerdir=/system/lib64,upperdir=$UPPER,workdir=$WORK,index=off,metacopy=off" \
        /system/lib64 2>/dev/null \
        || mount -t overlay overlay \
            -o "lowerdir=/system/lib64,upperdir=$UPPER,workdir=$WORK" \
            /system/lib64 2>/dev/null \
        || {
            log_msg "overlay failed: /system/lib64 libpenguin shim"
            umount "$BASE" 2>/dev/null || true
            return 0
        }

    log_msg "overlay mounted: /system/lib64 libpenguin shim"
}

mount_vendor_lib64_overlay()
{
    local BASE="/dev/monsterrom_oneui9_patches_vendor_lib64"
    local UPPER="$BASE/upper"
    local WORK="$BASE/work"
    local LIB
    local NEEDED=false
    local LIBS="
libAIQSolution_MPI.camera.samsung.so
libcdsprpc.so
"

    [ -d /vendor/lib64 ] || return 0

    for LIB in $LIBS; do
        [ -f "$MODDIR/vendor/lib64/$LIB" ] || continue
        [ -e "/vendor/lib64/$LIB" ] && continue
        NEEDED=true
    done
    $NEEDED || return 0

    if grep -q " /vendor/lib64 " /proc/mounts 2>/dev/null; then
        return 0
    fi

    rm -rf "$BASE" 2>/dev/null || true
    mkdir -p "$BASE" 2>/dev/null || return 0
    mount -t tmpfs -o mode=0755,size=4m tmpfs "$BASE" 2>/dev/null || {
        log_msg "tmpfs upper mount failed for /vendor/lib64 overlay"
        return 0
    }

    mkdir -p "$UPPER" "$WORK" 2>/dev/null || {
        umount "$BASE" 2>/dev/null || true
        return 0
    }

    for LIB in $LIBS; do
        [ -f "$MODDIR/vendor/lib64/$LIB" ] || continue
        [ -e "/vendor/lib64/$LIB" ] && continue
        cp -af "$MODDIR/vendor/lib64/$LIB" "$UPPER/$LIB" 2>/dev/null || {
            umount "$BASE" 2>/dev/null || true
            return 0
        }
        chown 0:0 "$UPPER/$LIB" 2>/dev/null || true
        chmod 0644 "$UPPER/$LIB" 2>/dev/null || true
        chcon u:object_r:vendor_file:s0 "$UPPER/$LIB" 2>/dev/null || true
    done

    mount -t overlay overlay \
        -o "lowerdir=/vendor/lib64,upperdir=$UPPER,workdir=$WORK,index=off,metacopy=off" \
        /vendor/lib64 2>/dev/null \
        || mount -t overlay overlay \
            -o "lowerdir=/vendor/lib64,upperdir=$UPPER,workdir=$WORK" \
            /vendor/lib64 2>/dev/null \
        || {
            log_msg "overlay failed: /vendor/lib64 camera libraries"
            umount "$BASE" 2>/dev/null || true
            return 0
        }

    log_msg "overlay mounted: /vendor/lib64 camera libraries"
}

bind_file()
{
    local REL="$1"
    local SRC="$MODDIR/$REL"
    local DST="/$REL"
    local TRY
    local CONTEXT="u:object_r:system_file:s0"

    [ -f "$SRC" ] || return 0

    case "$REL" in
        system/lib64/*)
            CONTEXT="u:object_r:system_lib_file:s0"
            ;;
        vendor/etc/*)
            CONTEXT="u:object_r:vendor_configs_file:s0"
            ;;
        vendor/*)
            CONTEXT="u:object_r:vendor_file:s0"
            ;;
    esac

    TRY=0
    while [ "$TRY" -lt 5 ]; do
        [ -e "$DST" ] && break
        TRY=$((TRY + 1))
        sleep 1
    done

    if [ ! -e "$DST" ]; then
        log_msg "target missing, skipping $DST"
        return 0
    fi

    chmod 0644 "$SRC" 2>/dev/null || true
    chown 0:0 "$SRC" 2>/dev/null || true
    chcon "$CONTEXT" "$SRC" 2>/dev/null || true

    "$BUSYBOX" mount -o bind "$SRC" "$DST" 2>/dev/null \
        || mount -o bind "$SRC" "$DST" 2>/dev/null \
        || log_msg "bind failed: $SRC -> $DST"
}

clean_launcher_art_cache()
{
    local FILE

    for FILE in /data/dalvik-cache/*/system@priv-app@TouchWizHome_2017@TouchWizHome_2017.apk@classes*; do
        [ -e "$FILE" ] || continue
        rm -f "$FILE" 2>/dev/null || true
    done

    rm -rf \
        /data/system/package_cache/*/*TouchWizHome* \
        /data/system/package_cache/*/*com.sec.android.app.launcher* \
        /data/misc/profiles/cur/*/com.sec.android.app.launcher \
        /data/misc/profiles/ref/com.sec.android.app.launcher \
        2>/dev/null || true
}

fix_sensor_permissions
restart_sensors_after_mcu_ready
mount_system_lib64_overlay
mount_vendor_lib64_overlay
log_msg "early repairs applied"

for REL in \
    system/cameradata/camera-feature.xml \
    system/etc/floating_feature.xml \
    system/etc/public.libraries-camera.samsung.txt \
    system/framework/framework.jar \
    system/framework/services.jar \
    system/lib64/libFaceRestoration.camera.samsung.so \
    system/lib64/libpenguin.so \
    system/priv-app/SamsungSmartSuggestions/SamsungSmartSuggestions.apk \
    system/priv-app/TouchWizHome_2017/TouchWizHome_2017.apk \
    system/priv-app/wallpaper-res/wallpaper-res.apk \
    vendor/etc/public.libraries.txt \
    vendor/etc/sensors/hals.conf \
    vendor/lib64/libAIQSolution_MPI.camera.samsung.so \
    vendor/lib64/libcdsprpc.so \
    vendor/lib64/sensors.sensorhub.so
do
    bind_file "$REL"
done

clean_launcher_art_cache
EOF

cat > "$MODULE_ROOT/service.sh" <<'EOF'
#!/system/bin/sh

MODDIR=${0%/*}

log_msg()
{
    echo "monsterrom_oneui9_patches: $*" > /dev/kmsg 2>/dev/null || true
}

wait_for_boot()
{
    local TRY=0

    while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ] && [ "$TRY" -lt 90 ]; do
        TRY=$((TRY + 1))
        sleep 2
    done
}

fix_display_defaults()
{
    wm size reset >/dev/null 2>&1 || true
    wm density reset >/dev/null 2>&1 || true
    settings put system screen_mode_setting 4 >/dev/null 2>&1 || true
    settings put system display_color_mode 0 >/dev/null 2>&1 || true
    settings put secure accessibility_display_daltonizer_enabled 0 >/dev/null 2>&1 || true
}

fix_smartsuggestions_history()
{
    local USER_ID
    local APP_UID
    local BASE
    local FILE

    for USER_ID in $(cmd user list 2>/dev/null | sed -n 's/.*UserInfo{\([0-9][0-9]*\):.*/\1/p'); do
        APP_UID="$(cmd package list packages --user "$USER_ID" -U com.samsung.android.smartsuggestions 2>/dev/null \
            | sed -n 's/.*uid:\([0-9][0-9]*\).*/\1/p' | head -n 1)"
        [ -n "$APP_UID" ] || continue

        BASE="/storage/emulated/$USER_ID/Android/data/com.samsung.android.smartsuggestions"
        FILE="$BASE/files/searchHistory.txt"

        mkdir -p "$BASE/files" 2>/dev/null || continue
        touch "$FILE" 2>/dev/null || true
        chown "$APP_UID:ext_data_rw" "$BASE" "$BASE/files" "$FILE" 2>/dev/null \
            || chown "$APP_UID:1078" "$BASE" "$BASE/files" "$FILE" 2>/dev/null \
            || true
        chmod 2770 "$BASE" "$BASE/files" 2>/dev/null || true
        chmod 0660 "$FILE" 2>/dev/null || true
    done
}

fix_sensor_permissions()
{
    local NODE

    for NODE in \
        /sys/class/lcd/panel/smooth_dim \
        /sys/class/lcd/panel/screen_mode \
        /sys/class/lcd/panel/vrr_lfd \
        /sys/class/power_supply/battery/batt_after_manufactured \
        /sys/class/usb_notify/usb_control/usb_hw_param; do
        [ -e "$NODE" ] || continue
        chown system:system "$NODE" 2>/dev/null || true
        chmod 0664 "$NODE" 2>/dev/null || true
    done

    for NODE in /sys/class/sec/switch/afc_disable; do
        [ -e "$NODE" ] || continue
        chown system:radio "$NODE" 2>/dev/null || true
        chmod 0664 "$NODE" 2>/dev/null || true
    done

    for NODE in /sys/bbd/lk_enable; do
        [ -e "$NODE" ] || continue
        chown gps:system "$NODE" 2>/dev/null || true
        chmod 0664 "$NODE" 2>/dev/null || true
    done

    for NODE in \
        /sys/class/sensors/ssp_sensor/data_injection_enable \
        /sys/class/sensors/ssp_sensor/enable \
        /sys/class/sensors/ssp_sensor/enable_irq \
        /sys/class/sensors/ssp_sensor/mcu_sleep_test \
        /sys/class/sensors/ssp_sensor/mcu_test \
        /sys/class/sensors/ssp_sensor/sensor_dump \
        /sys/class/sensors/ssp_sensor/ssp_control; do
        [ -e "$NODE" ] || continue
        chown system:radio "$NODE" 2>/dev/null || true
        chmod 0664 "$NODE" 2>/dev/null || true
    done

    for NODE in \
        /sys/class/sensors/ssp_sensor/ssp_flush \
        /sys/class/sensors/sensor_dev/flush; do
        [ -e "$NODE" ] || continue
        chown system:radio "$NODE" 2>/dev/null || true
        chmod 0220 "$NODE" 2>/dev/null || true
    done

    for NODE in /sys/bus/iio/devices/iio:device*/poll_delay \
        /sys/bus/iio/devices/iio:device*/buffer/enable \
        /sys/bus/iio/devices/iio:device*/buffer/length; do
        [ -e "$NODE" ] || continue
        chown system:system "$NODE" 2>/dev/null || true
        chmod 0660 "$NODE" 2>/dev/null || true
    done
}

fix_launcher_compile_cache()
{
    local APK="/system/priv-app/TouchWizHome_2017/TouchWizHome_2017.apk"
    local STATE_DIR="/data/adb/monsterrom_oneui9_patches"
    local HASH_FILE="$STATE_DIR/launcher.sha256"
    local HASH
    local OLD_HASH

    [ -f "$APK" ] || return 0

    HASH="$(sha256sum "$APK" 2>/dev/null | awk '{ print $1 }')"
    [ -n "$HASH" ] || return 0
    OLD_HASH="$(cat "$HASH_FILE" 2>/dev/null || true)"
    [ "$HASH" != "$OLD_HASH" ] || return 0

    rm -rf \
        /data/system/package_cache/*/*TouchWizHome* \
        /data/system/package_cache/*/*com.sec.android.app.launcher* \
        /data/dalvik-cache/*/system@priv-app@TouchWizHome_2017@TouchWizHome_2017.apk@classes* \
        /data/misc/profiles/cur/*/com.sec.android.app.launcher \
        /data/misc/profiles/ref/com.sec.android.app.launcher \
        2>/dev/null || true

    cmd package compile --reset com.sec.android.app.launcher >/dev/null 2>&1 || true
    am force-stop com.sec.android.app.launcher >/dev/null 2>&1 || true
    monkey -p com.sec.android.app.launcher 1 >/dev/null 2>&1 || true

    mkdir -p "$STATE_DIR" 2>/dev/null || true
    echo "$HASH" > "$HASH_FILE" 2>/dev/null || true
    log_msg "launcher compile cache reset for patched APK"
}

wait_for_boot
fix_display_defaults
fix_smartsuggestions_history
fix_sensor_permissions
fix_launcher_compile_cache
log_msg "runtime repairs applied"
EOF

chmod 0644 "$MODULE_ROOT/module.prop" "$MODULE_ROOT/customize.sh" "$MODULE_ROOT/system.prop" "$MODULE_ROOT/sepolicy.rule"
chmod 0755 "$MODULE_ROOT/post-mount.sh" "$MODULE_ROOT/service.sh"

copy_payload "system/system/etc/floating_feature.xml" \
    "system/etc/floating_feature.xml"
copy_payload "system/system/cameradata/camera-feature.xml" \
    "system/cameradata/camera-feature.xml"
copy_payload "system/system/etc/public.libraries-camera.samsung.txt" \
    "system/etc/public.libraries-camera.samsung.txt"
copy_payload "system/system/framework/framework.jar" \
    "system/framework/framework.jar"
copy_payload "system/system/framework/services.jar" \
    "system/framework/services.jar"
copy_payload "system/system/lib64/libFaceRestoration.camera.samsung.so" \
    "system/lib64/libFaceRestoration.camera.samsung.so"
copy_payload "system/system/lib64/libpenguin.so" \
    "system/lib64/libpenguin.so"
copy_payload "system/system/priv-app/SamsungSmartSuggestions/SamsungSmartSuggestions.apk" \
    "system/priv-app/SamsungSmartSuggestions/SamsungSmartSuggestions.apk"
copy_payload "system/system/priv-app/TouchWizHome_2017/TouchWizHome_2017.apk" \
    "system/priv-app/TouchWizHome_2017/TouchWizHome_2017.apk"
copy_payload "system/system/priv-app/wallpaper-res/wallpaper-res.apk" \
    "system/priv-app/wallpaper-res/wallpaper-res.apk"
copy_payload "vendor/etc/public.libraries.txt" \
    "vendor/etc/public.libraries.txt"
copy_payload "vendor/etc/sensors/hals.conf" \
    "vendor/etc/sensors/hals.conf"
copy_payload "vendor/lib64/libAIQSolution_MPI.camera.samsung.so" \
    "vendor/lib64/libAIQSolution_MPI.camera.samsung.so"
copy_payload "vendor/lib64/libcdsprpc.so" \
    "vendor/lib64/libcdsprpc.so"
copy_payload "vendor/lib64/sensors.sensorhub.so" \
    "vendor/lib64/sensors.sensorhub.so"

mkdir -p "$(dirname "$ZIP_PATH")"
rm -f "$ZIP_PATH"
(cd "$MODULE_ROOT" && zip -r9 "$ZIP_PATH" . > /dev/null)

echo "$ZIP_PATH"
