# [
_LOG() { if $DEBUG; then LOGW "$1"; else ABORT "$1"; fi }

SET_NFC_CONF()
{
    local FILE="$1"
    local KEY="$2"
    local VALUE="$3"

    [ -f "$FILE" ] || return 0

    if grep -q "^#*${KEY}=" "$FILE"; then
        LOG "- Replacing NFC config \"$KEY\" with \"$VALUE\" in ${FILE//$WORK_DIR/}"
        sed -i "s|^#*${KEY}=.*|${KEY}=${VALUE}|" "$FILE"
    else
        LOG "- Adding NFC config \"$KEY\" with \"$VALUE\" in ${FILE//$WORK_DIR/}"
        printf "\n%s=%s\n" "$KEY" "$VALUE" >> "$FILE"
    fi
}
# ]

TARGET_FIRMWARE_PATH="$(cut -d "/" -f 1 -s <<< "$TARGET_FIRMWARE")_$(cut -d "/" -f 2 -s <<< "$TARGET_FIRMWARE")"

if [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/etc/libnfc-nci.conf" ]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/etc/libnfc-nci.conf" 0 0 644 "u:object_r:system_file:s0"
else
    DELETE_FROM_WORK_DIR "system" "system/etc/libnfc-nci.conf"
fi
if [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/etc/libnfc-nci_temp.conf" ]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/etc/libnfc-nci_temp.conf" 0 0 644 "u:object_r:system_file:s0"
else
    DELETE_FROM_WORK_DIR "system" "system/etc/libnfc-nci_temp.conf"
fi
if [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/etc/libnfc-nci-NXP_SN100U.conf" ]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/etc/libnfc-nci-NXP_SN100U.conf" 0 0 644 "u:object_r:system_file:s0"
fi
if [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/etc/libnfc-nci-NXP_PN553.conf" ]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/etc/libnfc-nci-NXP_PN553.conf" 0 0 644 "u:object_r:system_file:s0"
fi
if [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/etc/libnfc-nci-SLSI.conf" ]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/etc/libnfc-nci-SLSI.conf" 0 0 644 "u:object_r:system_file:s0"
fi
if [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/etc/libnfc-nci-STM_ST21.conf" ]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/etc/libnfc-nci-STM_ST21.conf" 0 0 644 "u:object_r:system_file:s0"
fi

NFC_NCI_CONF="$WORK_DIR/system/system/etc/libnfc-nci.conf"
if [ -f "$NFC_NCI_CONF" ]; then
    SET_NFC_CONF "$NFC_NCI_CONF" "OPTIMIZE_ROUTING_TABLE_UPDATE" "0x01"
    SET_NFC_CONF "$NFC_NCI_CONF" "T4T_NDEF_NFCEE_AID" "{F4:10:00:00:09:4E:46:43:54:41:47:49:4E:46:4F}"
    SET_NFC_CONF "$NFC_NCI_CONF" "DEFAULT_NDEF_NFCEE_ROUTE" "0x10"
    SET_NFC_CONF "$NFC_NCI_CONF" "NFCEE_EVENT_RF_DISCOVERY_OPTION" "0x01"
    SET_NFC_CONF "$NFC_NCI_CONF" "NFA_EE_ROUTE_DEBOUNCE_TIMER" "0x00"
    SET_NFC_CONF "$NFC_NCI_CONF" "KOVIO_PRESENCE_CHECK_TYPE" "0x01"
    SET_NFC_CONF "$NFC_NCI_CONF" "HOST_LISTEN_TECH_MASK" "0x07"
    SET_NFC_CONF "$NFC_NCI_CONF" "MUTE_TECH_ROUTE_OPTION" "0x01"
    SET_NFC_CONF "$NFC_NCI_CONF" "ALWAYS_ON_SET_EE_POWER_AND_LINK_CONF" "0x03"
    SET_NFC_CONF "$NFC_NCI_CONF" "DISABLE_ALWAYS_ON_SET_EE_POWER_AND_LINK_CONF" "0x01"
    if [[ "$TARGET_COMMON_SUPPORT_EMBEDDED_SIM" == "true" ]]; then
        SET_NFC_CONF "$NFC_NCI_CONF" "EUICC_MEP_MODE" "0x01"
    else
        SET_NFC_CONF "$NFC_NCI_CONF" "EUICC_MEP_MODE" "0x00"
    fi
fi

if [ "$(GET_PROP "vendor" "ro.vendor.nfc.feature.chipname")" ]; then
    if [[ "$(GET_PROP "vendor" "ro.vendor.nfc.feature.chipname")" == "NXP_PN553" ]]; then
        SET_PROP "vendor" "ro.vendor.nfc.feature.chipname" "NXP_SN100U"
    fi
    if ! [[ "$(GET_PROP "vendor" "ro.vendor.nfc.feature.chipname")" =~ NXP_SN100U|SLSI|STM_ST21 ]]; then
        _LOG "Unknown NFC chip name: $(GET_PROP "vendor" "ro.vendor.nfc.feature.chipname")"
        return 0
    fi
fi

NFC_ANTENNA_POSITION="$(GET_PROP "vendor" "ro.vendor.nfc.info.antpos")"
NFC_FEATURE_ANTENNA_POSITION="$(GET_FLOATING_FEATURE_CONFIG "SEC_PRODUCT_FEATURE_NFC_CONFIG_ANTENNA_POSITION")"
if [ "$NFC_ANTENNA_POSITION" ] && [ "$NFC_FEATURE_ANTENNA_POSITION" ] && \
        [[ "$NFC_FEATURE_ANTENNA_POSITION" != "$NFC_ANTENNA_POSITION" ]]; then
    LOG "- Aligning NFC antenna position with target vendor"
    SET_FLOATING_FEATURE_CONFIG "SEC_PRODUCT_FEATURE_NFC_CONFIG_ANTENNA_POSITION" "$NFC_ANTENNA_POSITION"
fi
if [ "$NFC_ANTENNA_POSITION" ]; then
    SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
        "smali_classes3/com/samsung/android/settings/nfc/NfcSettings.smali" "replace" \
        "populateViewForOrientation(Lcom/android/settingslib/widget/LayoutPreference;)V" \
        "29" "$NFC_ANTENNA_POSITION"
    SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
        "smali_classes3/com/samsung/android/settings/nfc/NfcAntennaGuideDialog.smali" "replace" \
        "onCreate(Landroid/os/Bundle;)V" \
        "29" "$NFC_ANTENNA_POSITION"
fi

# SEC_PRODUCT_FEATURE_NFC_CHIP_NAME:=NXP_SN100U/NXP_PN553
# - API 35 and below: libnfc_nxpsn_jni.so/libnfc_nxppn_jni.so
# - API 36: libnfc_nci_jni.so
#
# Use NXP_SN100U blobs for devices with legacy NXP_PN553 impl.
if [ -f "$WORK_DIR/system/system/lib/libnfc_nci_jni.so" ]; then
    if [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib/libnfc_nci_jni.so" ] && \
            [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_nxppn_jni.so" ] && \
            [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_nxpsn_jni.so" ] && \
            [ ! -f "$WORK_DIR/vendor/lib/nfc_nci_nxpsn.so" ] && \
            [ ! -f "$WORK_DIR/vendor/lib/nfc_nci_nxp.so" ] && \
            [ ! -f "$WORK_DIR/vendor/lib64/nfc_nci_nxpsn.so" ] && \
            [ ! -f "$WORK_DIR/vendor/lib64/nfc_nci_nxp.so" ]; then
        DELETE_FROM_WORK_DIR "system" "system/lib/libnfc_nci_jni.so"
        DELETE_FROM_WORK_DIR "system" "system/lib/libnfc_prop_extn.so"
        DELETE_FROM_WORK_DIR "system" "system/lib/libnfc_vendor_extn.so"
    fi
elif [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib/libnfc_nci_jni.so" ]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib/libnfc_nci_jni.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib/libnfc_prop_extn.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib/libnfc_vendor_extn.so" 0 0 644 "u:object_r:system_lib_file:s0"
elif [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_nxpsn_jni.so" ]; then
    # Skip when source uses APEX-based NFC (no standalone JNI libs to backfill)
    _SRC_FW_PATH="$(cut -d "/" -f 1 -s <<< "$SOURCE_FIRMWARE")_$(cut -d "/" -f 2 -s <<< "$SOURCE_FIRMWARE")"
    if [ ! -f "$FW_DIR/$_SRC_FW_PATH/system/system/lib/libnfc_nci_jni.so" ] && \
            [ ! -f "$FW_DIR/$_SRC_FW_PATH/system/system/lib64/libnfc_nci_jni.so" ]; then
        : # APEX-based NFC source, no lib32 JNI needed
    else
        _LOG "Missing prebuilt blobs for NXP_SN100U NFC chip"
        return 0
    fi
    unset _SRC_FW_PATH
fi
if [ -f "$WORK_DIR/system/system/lib64/libnfc_nci_jni.so" ]; then
    if [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_nci_jni.so" ] && \
            [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_nxppn_jni.so" ] && \
            [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_nxpsn_jni.so" ] && \
            [ ! -f "$WORK_DIR/vendor/lib64/nfc_nci_nxpsn.so" ] && \
            [ ! -f "$WORK_DIR/vendor/lib64/nfc_nci_nxp.so" ]; then
        DELETE_FROM_WORK_DIR "system" "system/lib64/libnfc_nci_jni.so"
        DELETE_FROM_WORK_DIR "system" "system/lib64/libnfc_prop_extn.so"
        DELETE_FROM_WORK_DIR "system" "system/lib64/libnfc_vendor_extn.so"
    fi
elif [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_nci_jni.so" ]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libnfc_nci_jni.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libnfc_prop_extn.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libnfc_vendor_extn.so" 0 0 644 "u:object_r:system_lib_file:s0"
elif [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_nxpsn_jni.so" ]; then
    # Skip when source uses APEX-based NFC (no standalone JNI libs to backfill)
    _SRC_FW_PATH="$(cut -d "/" -f 1 -s <<< "$SOURCE_FIRMWARE")_$(cut -d "/" -f 2 -s <<< "$SOURCE_FIRMWARE")"
    if [ -f "$FW_DIR/$_SRC_FW_PATH/system/system/lib/libnfc_nci_jni.so" ] || \
            [ -f "$FW_DIR/$_SRC_FW_PATH/system/system/lib64/libnfc_nci_jni.so" ]; then
        unset _SRC_FW_PATH
        _LOG "Missing prebuilt blobs for NXP_SN100U NFC chip"
        return 0
    fi
    unset _SRC_FW_PATH
fi

# SEC_PRODUCT_FEATURE_NFC_CHIP_NAME:=STM_ST21
# - API 35 and below: libnfc_st_jni.so
# - API 36: libstnfc_nci_jni.so
if [ -f "$WORK_DIR/system/system/lib/libstnfc_nci_jni.so" ]; then
    if [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib/libstnfc_nci_jni.so" ] && \
            [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_st_jni.so" ]; then
        DELETE_FROM_WORK_DIR "system" "system/lib/libnfc_vendor_extn_st.so"
        DELETE_FROM_WORK_DIR "system" "system/lib/libstnfc_nci_jni.so"
    fi
elif [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib/libstnfc_nci_jni.so" ]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib/libnfc_vendor_extn_st.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib/libstnfc_nci_jni.so" 0 0 644 "u:object_r:system_lib_file:s0"
elif [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_st_jni.so" ]; then
    ADD_TO_WORK_DIR "a17xxx" "system" "system/lib/libnfc_vendor_extn_st.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "a17xxx" "system" "system/lib/libstnfc_nci_jni.so" 0 0 644 "u:object_r:system_lib_file:s0"
fi
if [ -f "$WORK_DIR/system/system/lib64/libstnfc_nci_jni.so" ]; then
    if [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libstnfc_nci_jni.so" ] && \
            [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_st_jni.so" ]; then
        DELETE_FROM_WORK_DIR "system" "system/lib64/libnfc_vendor_extn_st.so"
        DELETE_FROM_WORK_DIR "system" "system/lib64/libstnfc_nci_jni.so"
    fi
elif [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libstnfc_nci_jni.so" ]; then
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libnfc_vendor_extn_st.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libstnfc_nci_jni.so" 0 0 644 "u:object_r:system_lib_file:s0"
elif [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_st_jni.so" ]; then
    ADD_TO_WORK_DIR "a17xxx" "system" "system/lib64/libnfc_vendor_extn_st.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "a17xxx" "system" "system/lib64/libstnfc_nci_jni.so" 0 0 644 "u:object_r:system_lib_file:s0"
fi

# SEC_PRODUCT_FEATURE_NFC_CHIP_NAME:=SLSI
# - Same lib name as before, check for TARGET_PLATFORM_SDK_VERSION instead
if [ -f "$WORK_DIR/system/system/lib/libnfc_sec_jni.so" ]; then
    if [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib/libnfc_sec_jni.so" ] && \
            [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_sec_jni.so" ] && \
            [ ! -f "$WORK_DIR/vendor/lib/nfc_nci_sec.so" ] && \
            [ ! -f "$WORK_DIR/vendor/lib64/nfc_nci_sec.so" ]; then
        DELETE_FROM_WORK_DIR "system" "system/lib/libnfc_sec_jni.so"
    fi
elif [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib/libnfc_sec_jni.so" ] || \
        [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_sec_jni.so" ]; then
    if [ "$TARGET_PLATFORM_SDK_VERSION" -ge "36" ]; then
        ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib/libnfc_sec_jni.so" 0 0 644 "u:object_r:system_lib_file:s0"
    else
        ADD_TO_WORK_DIR "r11sxxx" "system" "system/lib/libnfc_sec_jni.so" 0 0 644 "u:object_r:system_lib_file:s0"
    fi
fi
if [ -f "$WORK_DIR/system/system/lib64/libnfc_sec_jni.so" ]; then
    if [ ! -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_sec_jni.so" ] && \
            [ ! -f "$WORK_DIR/vendor/lib64/nfc_nci_sec.so" ]; then
        DELETE_FROM_WORK_DIR "system" "system/lib64/libnfc_sec_jni.so"
    fi
elif [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/lib64/libnfc_sec_jni.so" ]; then
    if [ "$TARGET_PLATFORM_SDK_VERSION" -ge "36" ]; then
        ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libnfc_sec_jni.so" 0 0 644 "u:object_r:system_lib_file:s0"
    else
        ADD_TO_WORK_DIR "r11sxxx" "system" "system/lib64/libnfc_sec_jni.so" 0 0 644 "u:object_r:system_lib_file:s0"
    fi
fi

unset TARGET_FIRMWARE_PATH NFC_NCI_CONF NFC_ANTENNA_POSITION NFC_FEATURE_ANTENNA_POSITION
unset -f _LOG SET_NFC_CONF
