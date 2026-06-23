_LOG() { if $DEBUG; then LOGW "$1"; else ABORT "$1"; fi }

_REMOVE_VINTF_HAL_BLOCK()
{
    local FILE="$1"
    local FORMAT="$2"
    local NAME="$3"
    local TMP_FILE

    [ -f "$FILE" ] || return 0
    grep -Fq "<name>$NAME</name>" "$FILE" || return 0

    LOG "- Removing unsupported VINTF HAL \"$NAME\" from ${FILE//$WORK_DIR/}"
    TMP_FILE="${FILE}.tmp"
    awk -v format="$FORMAT" -v name="$NAME" '
        BEGIN {
            in_hal = 0
            depth = 0
            drop = 0
            block = ""
        }
        {
            if (!in_hal && index($0, "<hal ") && index($0, "format=\"" format "\"")) {
                in_hal = 1
                depth = 0
                drop = 0
                block = ""
            }

            if (in_hal) {
                block = block $0 ORS
                if (index($0, "<name>" name "</name>")) {
                    drop = 1
                }
                if (index($0, "<hal ") || index($0, "<hal>")) {
                    depth++
                }
                if (index($0, "</hal>")) {
                    depth--
                    if (depth == 0) {
                        if (!drop) {
                            printf "%s", block
                        }
                        in_hal = 0
                        drop = 0
                        block = ""
                    }
                }
                next
            }

            print
        }
        END {
            if (in_hal && !drop) {
                printf "%s", block
            }
        }
    ' "$FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$FILE"
}

_CLEAN_LEGACY_EXYNOS_VINTF_MATRICES()
{
    local FILE

    [ "$TARGET_PLATFORM" = "exynos2100" ] || return 0

    for FILE in "$WORK_DIR/system/system/etc/vintf"/compatibility_matrix*.xml; do
        [ -f "$FILE" ] || continue
        _REMOVE_VINTF_HAL_BLOCK "$FILE" "aidl" "android.hardware.boot"
        _REMOVE_VINTF_HAL_BLOCK "$FILE" "aidl" "android.hardware.dumpstate"
        _REMOVE_VINTF_HAL_BLOCK "$FILE" "aidl" "android.hardware.audio.core"
        _REMOVE_VINTF_HAL_BLOCK "$FILE" "aidl" "android.hardware.audio.effect"
        _REMOVE_VINTF_HAL_BLOCK "$FILE" "aidl" "android.hardware.graphics.allocator"
        _REMOVE_VINTF_HAL_BLOCK "$FILE" "aidl" "android.hardware.graphics.composer3"
        _REMOVE_VINTF_HAL_BLOCK "$FILE" "aidl" "android.hardware.security.keymint"
    done
}

_COPY_TARGET_VENDOR_VINTF_FRAGMENTS()
{
    local DIR="$SRC_DIR/target/$TARGET_CODENAME/vintf/vendor_manifest"
    local FILE

    [ -d "$DIR" ] || return 0

    EVAL "mkdir -p \"$WORK_DIR/vendor/etc/vintf/manifest\""
    for FILE in "$DIR"/*.xml; do
        [ -f "$FILE" ] || continue
        LOG "- Adding /vendor/etc/vintf/manifest/$(basename "$FILE")"
        EVAL "cp -a \"$FILE\" \"$WORK_DIR/vendor/etc/vintf/manifest/$(basename "$FILE")\""
    done
}

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

_COPY_TARGET_VENDOR_VINTF_FRAGMENTS
_CLEAN_LEGACY_EXYNOS_VINTF_MATRICES

unset -f _LOG _REMOVE_VINTF_HAL_BLOCK _CLEAN_LEGACY_EXYNOS_VINTF_MATRICES _COPY_TARGET_VENDOR_VINTF_FRAGMENTS
