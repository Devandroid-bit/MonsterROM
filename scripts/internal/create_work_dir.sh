#!/usr/bin/env bash
# Copyright (c) 2025 Salvo Giangreco
# SPDX-License-Identifier: GPL-3.0-or-later

# [
source "$SRC_DIR/scripts/utils/build_utils.sh" || exit 1

SOURCE_FIRMWARE_PATH="$(cut -d "/" -f 1 -s <<< "$SOURCE_FIRMWARE")_$(cut -d "/" -f 2 -s <<< "$SOURCE_FIRMWARE")"
TARGET_FIRMWARE_PATH="$(cut -d "/" -f 1 -s <<< "$TARGET_FIRMWARE")_$(cut -d "/" -f 2 -s <<< "$TARGET_FIRMWARE")"

COPY_SOURCE_FIRMWARE()
{
    local SOURCE_FOLDERS="odm product system"
    for f in $SOURCE_FOLDERS; do
        if [ -d "$FW_DIR/$SOURCE_FIRMWARE_PATH/$f" ]; then
            LOG "- Copying /$f from source firmware"
            EVAL "rsync -a --mkpath --delete --exclude=\"*system_ext*\" \"$FW_DIR/$SOURCE_FIRMWARE_PATH/$f\" \"$WORK_DIR\"" || exit 1
            sed "/system_ext/d" "$FW_DIR/$SOURCE_FIRMWARE_PATH/file_context-$f" > "$WORK_DIR/configs/file_context-$f"
            sed "/system_ext/d" "$FW_DIR/$SOURCE_FIRMWARE_PATH/fs_config-$f" > "$WORK_DIR/configs/fs_config-$f"
            if [[ "$f" == "product" ]]; then
                LOG_STEP_IN
                SET_PROP "product" "ro.product.product.name" "$(GET_PROP "$FW_DIR/$TARGET_FIRMWARE_PATH/product/etc/build.prop" "ro.product.product.name")"
                LOG_STEP_OUT
            elif [[ "$f" == "system" ]]; then
                LOG_STEP_IN
                SET_PROP "system" "ro.product.device" "$(GET_PROP "$FW_DIR/$SOURCE_FIRMWARE_PATH/odm/etc/build.prop" "ro.product.odm.device")"
                LOG_STEP_OUT
            fi
        else
            [ -d "$WORK_DIR/$f" ] && rm -rf "${WORK_DIR:?}/$f"
            [ -f "$WORK_DIR/configs/file_context-$f" ] && rm -f "$WORK_DIR/configs/file_context-$f"
            [ -f "$WORK_DIR/configs/fs_config-$f" ] && rm -f "$WORK_DIR/configs/fs_config-$f"
        fi
    done

    if [ -d "$FW_DIR/$SOURCE_FIRMWARE_PATH/system_ext" ]; then
        if $TARGET_OS_BUILD_SYSTEM_EXT_PARTITION; then
            LOG_STEP_IN "- Copying /system_ext from source firmware"

            [ -L "$WORK_DIR/system/system_ext" ] && rm -f "$WORK_DIR/system/system_ext"
            [ -d "$WORK_DIR/system/system/system_ext" ] && rm -rf "$WORK_DIR/system/system/system_ext"

            EVAL "rsync -a --mkpath --delete \"$FW_DIR/$SOURCE_FIRMWARE_PATH/system_ext\" \"$WORK_DIR\"" || exit 1
            mkdir -p "$WORK_DIR/system/system_ext"
            EVAL "ln -sf \"/system_ext\" \"$WORK_DIR/system/system/system_ext\"" || exit 1
            SET_METADATA "system" "system_ext" 0 0 755 "u:object_r:system_file:s0"
            SET_METADATA "system" "system/system_ext" 0 0 644 "u:object_r:system_file:s0"
            EVAL "cp -a \"$FW_DIR/$SOURCE_FIRMWARE_PATH/file_context-system_ext\" \"$WORK_DIR/configs/file_context-system_ext\"" || exit 1
            EVAL "cp -a \"$FW_DIR/$SOURCE_FIRMWARE_PATH/fs_config-system_ext\" \"$WORK_DIR/configs/fs_config-system_ext\"" || exit 1

            LOG_STEP_OUT
        else
            LOG_STEP_IN "- Copying /system/system/system_ext from source firmware"

            [ -d "$WORK_DIR/system/system_ext" ] && rm -rf "$WORK_DIR/system/system_ext"
            [ -L "$WORK_DIR/system/system/system_ext" ] && rm -f "$WORK_DIR/system/system/system_ext"
            [ -d "$WORK_DIR/system_ext" ] && rm -rf "$WORK_DIR/system_ext"
            [ -f "$WORK_DIR/configs/file_context-system_ext" ] && rm -f "$WORK_DIR/configs/file_context-system_ext"
            [ -f "$WORK_DIR/configs/fs_config-system_ext" ] && rm -f "$WORK_DIR/configs/fs_config-system_ext"

            EVAL "rsync -a --mkpath --delete \"$FW_DIR/$SOURCE_FIRMWARE_PATH/system_ext\" \"$WORK_DIR/system/system\"" || exit 1
            EVAL "ln -sf \"/system/system_ext\" \"$WORK_DIR/system/system_ext\"" || exit 1
            SET_METADATA "system" "system_ext" 0 0 644 "u:object_r:system_file:s0"
            sed "s/^\/system_ext/\/system\/system_ext/g" "$FW_DIR/$SOURCE_FIRMWARE_PATH/file_context-system_ext" >> "$WORK_DIR/configs/file_context-system"
            sed "s/^system_ext/system\/system_ext/g" "$FW_DIR/$SOURCE_FIRMWARE_PATH/fs_config-system_ext" >> "$WORK_DIR/configs/fs_config-system"

            DELETE_FROM_WORK_DIR "system" "system/system_ext/etc/NOTICE.xml.gz"

            LOG_STEP_OUT
        fi
    elif [ -d "$FW_DIR/$SOURCE_FIRMWARE_PATH/system/system/system_ext" ]; then
        if $TARGET_OS_BUILD_SYSTEM_EXT_PARTITION; then
            LOG_STEP_IN "- Copying /system_ext from source firmware"

            [ -L "$WORK_DIR/system/system_ext" ] && rm -f "$WORK_DIR/system/system_ext"
            [ -d "$WORK_DIR/system/system/system_ext" ] && rm -rf "$WORK_DIR/system/system/system_ext"

            EVAL "rsync -a --mkpath --delete \"$FW_DIR/$SOURCE_FIRMWARE_PATH/system/system/system_ext\" \"$WORK_DIR\"" || exit 1
            mkdir -p "$WORK_DIR/system/system_ext"
            EVAL "ln -sf \"/system_ext\" \"$WORK_DIR/system/system/system_ext\"" || exit 1
            SET_METADATA "system" "system_ext" 0 0 755 "u:object_r:system_file:s0"
            SET_METADATA "system" "system/system_ext" 0 0 644 "u:object_r:system_file:s0"
            grep -F "system/system_ext" "$FW_DIR/$SOURCE_FIRMWARE_PATH/file_context-system" | sed "s/^\/system//" > "$WORK_DIR/configs/file_context-system_ext"
            grep -F "system/system_ext" "$FW_DIR/$SOURCE_FIRMWARE_PATH/fs_config-system" | sed "s/^system\///" > "$WORK_DIR/configs/fs_config-system_ext"
            sed -i "s/^system_ext /  /g" "$WORK_DIR/configs/fs_config-system_ext"

            LOG_STEP_OUT
        else
            LOG_STEP_IN "- Copying /system/system/system_ext from source firmware"

            [ -d "$WORK_DIR/system/system_ext" ] && rm -rf "$WORK_DIR/system/system_ext"
            [ -L "$WORK_DIR/system/system/system_ext" ] && rm -f "$WORK_DIR/system/system/system_ext"
            [ -d "$WORK_DIR/system_ext" ] && rm -rf "$WORK_DIR/system_ext"
            [ -f "$WORK_DIR/configs/file_context-system_ext" ] && rm -f "$WORK_DIR/configs/file_context-system_ext"
            [ -f "$WORK_DIR/configs/fs_config-system_ext" ] && rm -f "$WORK_DIR/configs/fs_config-system_ext"

            EVAL "rsync -a --mkpath --delete \"$FW_DIR/$SOURCE_FIRMWARE_PATH/system/system/system_ext\" \"$WORK_DIR/system/system\"" || exit 1
            EVAL "ln -sf \"/system/system_ext\" \"$WORK_DIR/system/system_ext\"" || exit 1
            grep -F "system_ext" "$FW_DIR/$SOURCE_FIRMWARE_PATH/file_context-system" >> "$WORK_DIR/configs/file_context-system"
            grep -F "system_ext" "$FW_DIR/$SOURCE_FIRMWARE_PATH/fs_config-system" >> "$WORK_DIR/configs/fs_config-system"

            LOG_STEP_OUT
        fi
    fi
}

# ]

mkdir -p "$WORK_DIR"
mkdir -p "$WORK_DIR/configs"
COPY_SOURCE_FIRMWARE

exit 0
