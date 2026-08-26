_LOG() { if $DEBUG; then LOGW "$1"; else ABORT "$1"; fi }

# Android 17 no longer ships the oldest framework compatibility matrices. Keep
# the target's compatibility floor when porting a newer system to an older
# vendor instead of silently relying on a matrix for a newer FCM level.
TARGET_FIRMWARE_PATH="$(cut -d "/" -f 1 -s <<< "$TARGET_FIRMWARE")_$(cut -d "/" -f 2 -s <<< "$TARGET_FIRMWARE")"
WORK_VINTF_DIR="$WORK_DIR/system/system/etc/vintf"
TARGET_VINTF_DIR="$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/etc/vintf"

# RESTORE_TARGET_FCM <level>
RESTORE_TARGET_FCM()
{
    local LEVEL="$1"
    local FILE="compatibility_matrix.$LEVEL.xml"

    if [ ! -f "$WORK_VINTF_DIR/$FILE" ] && [ -f "$TARGET_VINTF_DIR/$FILE" ]; then
        LOG "- Restoring /system/system/etc/vintf/$FILE from target firmware"
        ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/etc/vintf/$FILE" \
            0 0 644 "u:object_r:system_file:s0" || \
            ABORT "Failed to restore target framework compatibility matrix $FILE"
    fi
}

# VALIDATE_FRAMEWORK_MATRIX <level>
VALIDATE_FRAMEWORK_MATRIX()
{
    local LEVEL="$1"
    local FILE="$WORK_VINTF_DIR/compatibility_matrix.$LEVEL.xml"

    if [ ! -s "$FILE" ]; then
        ABORT "Missing framework compatibility matrix for target FCM level $LEVEL: ${FILE//$WORK_DIR/}"
    fi
    if ! grep -q '<compatibility-matrix' "$FILE" || \
            ! grep -q 'type="framework"' "$FILE" || \
            ! grep -q "level=\"$LEVEL\"" "$FILE"; then
        ABORT "Invalid framework compatibility matrix for target FCM level $LEVEL: ${FILE//$WORK_DIR/}"
    fi
    if command -v xmllint > /dev/null 2>&1 && ! xmllint --noout "$FILE"; then
        ABORT "Malformed framework compatibility matrix: ${FILE//$WORK_DIR/}"
    fi
}

# Restore the exact FCM level declared by the target vendor manifest first.
# The Android 17 source may not ship this older framework matrix.
TARGET_FCM_LEVEL="$(grep -o -m 1 'target-level="[0-9]*"' "$WORK_DIR/vendor/etc/vintf/manifest.xml" 2> /dev/null | \
                    cut -d '"' -f 2)"
if [ "$TARGET_FCM_LEVEL" ]; then
    RESTORE_TARGET_FCM "$TARGET_FCM_LEVEL"
fi
RESTORE_TARGET_FCM "5"
RESTORE_TARGET_FCM "6"

if [ -f "$SRC_DIR/target/$TARGET_CODENAME/vintf/compatibility_matrix.device.xml" ]; then
    LOG "- Adding /system/system/etc/vintf/compatibility_matrix.device.xml"
    EVAL "cp -a \"$SRC_DIR/target/$TARGET_CODENAME/vintf/compatibility_matrix.device.xml\" \"$WORK_DIR/system/system/etc/vintf/compatibility_matrix.device.xml\""
elif [[ "$SOURCE_PLATFORM_SDK_VERSION" == "$TARGET_PLATFORM_SDK_VERSION" ]]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/etc/vintf/compatibility_matrix.device.xml"
else
    _LOG "File not found: $SRC_DIR/target/$TARGET_CODENAME/vintf/compatibility_matrix.device.xml"
fi

if [ -f "$SRC_DIR/target/$TARGET_CODENAME/vintf/manifest.xml" ]; then
    LOG "- Adding /system/system/etc/vintf/manifest.xml"
    EVAL "cp -a \"$SRC_DIR/target/$TARGET_CODENAME/vintf/manifest.xml\" \"$WORK_DIR/system/system/etc/vintf/manifest.xml\""
elif [[ "$SOURCE_PLATFORM_SDK_VERSION" == "$TARGET_PLATFORM_SDK_VERSION" ]]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/etc/vintf/manifest.xml"
fi

TARGET_FCM_LEVEL="$(grep -o -m 1 'target-level="[0-9]*"' "$WORK_DIR/vendor/etc/vintf/manifest.xml" 2> /dev/null | \
                    cut -d '"' -f 2)"
if [ "$TARGET_FCM_LEVEL" ]; then
    VALIDATE_FRAMEWORK_MATRIX "$TARGET_FCM_LEVEL"
fi

unset TARGET_FIRMWARE_PATH WORK_VINTF_DIR TARGET_VINTF_DIR TARGET_FCM_LEVEL
unset -f _LOG RESTORE_TARGET_FCM VALIDATE_FRAMEWORK_MATRIX
