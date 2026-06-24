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

set_perm_recursive "$MODPATH/system" 0 0 0755 0644 u:object_r:system_file:s0
set_perm "$MODPATH/system.prop" 0 0 0644 u:object_r:system_file:s0
set_perm "$MODPATH/post-mount.sh" 0 0 0755 u:object_r:system_file:s0
EOF

cat > "$MODULE_ROOT/system.prop" <<'EOF'
# Newer Samsung Camera app parity flag from the supplied One UI feature set.
ro.camera.default_app_social_media_parity_enabled=true
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

bind_file()
{
    local REL="$1"
    local SRC="$MODDIR/$REL"
    local DST="/$REL"
    local TRY

    [ -f "$SRC" ] || return 0

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
    chcon u:object_r:system_file:s0 "$SRC" 2>/dev/null || true

    "$BUSYBOX" mount -o bind "$SRC" "$DST" 2>/dev/null \
        || mount -o bind "$SRC" "$DST" 2>/dev/null \
        || log_msg "bind failed: $SRC -> $DST"
}

for REL in \
    system/etc/floating_feature.xml \
    system/framework/framework.jar \
    system/priv-app/SamsungSmartSuggestions/SamsungSmartSuggestions.apk \
    system/priv-app/TouchWizHome_2017/TouchWizHome_2017.apk \
    system/priv-app/wallpaper-res/wallpaper-res.apk
do
    bind_file "$REL"
done
EOF

chmod 0644 "$MODULE_ROOT/module.prop" "$MODULE_ROOT/customize.sh" "$MODULE_ROOT/system.prop"
chmod 0755 "$MODULE_ROOT/post-mount.sh"

copy_payload "system/system/etc/floating_feature.xml" \
    "system/etc/floating_feature.xml"
copy_payload "system/system/framework/framework.jar" \
    "system/framework/framework.jar"
copy_payload "system/system/priv-app/SamsungSmartSuggestions/SamsungSmartSuggestions.apk" \
    "system/priv-app/SamsungSmartSuggestions/SamsungSmartSuggestions.apk"
copy_payload "system/system/priv-app/TouchWizHome_2017/TouchWizHome_2017.apk" \
    "system/priv-app/TouchWizHome_2017/TouchWizHome_2017.apk"
copy_payload "system/system/priv-app/wallpaper-res/wallpaper-res.apk" \
    "system/priv-app/wallpaper-res/wallpaper-res.apk"

mkdir -p "$(dirname "$ZIP_PATH")"
rm -f "$ZIP_PATH"
(cd "$MODULE_ROOT" && zip -r9 "$ZIP_PATH" . > /dev/null)

echo "$ZIP_PATH"
