_TARGET_FIRMWARE_PATH="$(cut -d "/" -f 1 -s <<< "$TARGET_FIRMWARE")_$(cut -d "/" -f 2 -s <<< "$TARGET_FIRMWARE")"

_ADD_TARGET_BLOB_IF_EXISTS()
{
    local PARTITION="$1"
    local FILE="$2"
    local BLOB_UID="$3"
    local BLOB_GID="$4"
    local MODE="$5"
    local CONTEXT="$6"

    if [ -f "$FW_DIR/$_TARGET_FIRMWARE_PATH/$PARTITION/$FILE" ]; then
        ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "$PARTITION" "$FILE" "$BLOB_UID" "$BLOB_GID" "$MODE" "$CONTEXT"
    fi
}

LOG_STEP_IN "- Adding stock SoundBooster libs"
if [[ "$TARGET_CODENAME" == "r9s"  ]]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/lib_SoundBooster_ver1070.so" 0 0 644 "u:object_r:system_lib_file:s0"
else
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/lib_SoundBooster_ver1050.so" 0 0 644 "u:object_r:system_lib_file:s0"
fi
if [ -f "$FW_DIR/$_TARGET_FIRMWARE_PATH/system/system/lib64/lib_SAG_EQ_ver2090.so" ]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/lib_SAG_EQ_ver2090.so" 0 0 644 "u:object_r:system_lib_file:s0"
else
    DELETE_FROM_WORK_DIR "system" "system/lib64/lib_SAG_EQ_ver2090.so"
fi
DELETE_FROM_WORK_DIR "system" "system/lib64/lib_SoundBooster_ver2090.so"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/lib_SoundAlive_play_plus_ver500.so" 0 0 644 "u:object_r:system_lib_file:s0"
DELETE_FROM_WORK_DIR "system" "system/lib64/lib_SoundAlive_play_plus_ver900.so"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libaudiosaplus_sec_legacy.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libsamsungSoundbooster_plus_legacy.so" 0 0 644 "u:object_r:system_lib_file:s0"
if [ -f "$FW_DIR/$_TARGET_FIRMWARE_PATH/system/system/lib64/libpenguin.so" ]; then
    _ADD_TARGET_BLOB_IF_EXISTS "system" "system/lib64/libpenguin.so" 0 0 644 "u:object_r:system_lib_file:s0"
else
    LOG "- Adding generated libpenguin.so shim because the target firmware does not ship it"
    ADD_TO_WORK_DIR "platform/exynos2100/patches/blobs" "system" "system/lib64/libpenguin.so" 0 0 644 "u:object_r:system_lib_file:s0"
fi
LOG_STEP_OUT

if grep -q 'stream type="sec_voice_communication"' "$WORK_DIR/vendor/etc/audio_effects_sec.xml" 2>/dev/null; then
    LOG "- Removing unsupported sec_voice_communication audio effect stream"
    sed -i '/<stream type="sec_voice_communication">/,/<\/stream>/d' "$WORK_DIR/vendor/etc/audio_effects_sec.xml"
fi

LOG_STEP_IN "- Removing Qualcomm GNSS service blobs"
DELETE_FROM_WORK_DIR "system" "system/system_ext/bin/loc_sys_service"
DELETE_FROM_WORK_DIR "system" "system/system_ext/etc/init/loc_sys_service.rc"
DELETE_FROM_WORK_DIR "system" "system/lib64/vendor.qti.gnss-V8-cpp.so"
LOG_STEP_OUT

LOG_STEP_IN "- Adding OK Google Hotword Enrollment blobs"
DELETE_FROM_WORK_DIR "product" "priv-app/HotwordEnrollmentXGoogleEx6_WIDEBAND_LARGE"
DELETE_FROM_WORK_DIR "product" "priv-app/HotwordEnrollmentYGoogleEx6_WIDEBAND_LARGE"
ADD_TO_WORK_DIR "r9sxxx" "product" "priv-app/HotwordEnrollmentOKGoogleEx3CORTEXM4/HotwordEnrollmentOKGoogleEx3CORTEXM4.apk" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "r9sxxx" "product" "priv-app/HotwordEnrollmentXGoogleEx3CORTEXM4/HotwordEnrollmentXGoogleEx3CORTEXM4.apk" 0 0 644 "u:object_r:system_file:s0"
LOG_STEP_OUT

if [[ "$TARGET_CODENAME" == "r9s"  ]]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/etc/init/rscmgr_s21fe.rc" 0 0 644 "u:object_r:system_file:s0"
fi

ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/etc/permissions/android.hardware.sensor.hifi_sensors.xml" 0 0 644 "u:object_r:system_file:s0"
_ADD_TARGET_BLOB_IF_EXISTS "vendor" "lib64/sensors.bio.so" 0 0 644 "u:object_r:vendor_file:s0"
_ADD_TARGET_BLOB_IF_EXISTS "vendor" "etc/hyper/config_model.json" 0 0 644 "u:object_r:vendor_configs_file:s0"

unset _TARGET_FIRMWARE_PATH
unset -f _ADD_TARGET_BLOB_IF_EXISTS
