AIRCOMMAND_APK="system/priv-app/AirCommand/AirCommand.apk"

if [ -f "$WORK_DIR/system/$AIRCOMMAND_APK" ]; then
    LOG_STEP_IN "- Applying AirCommand S Pen logic patch"

    SMALI_PATCH "system" "$AIRCOMMAND_APK" \
        "smali/b5/q.smali" \
        "return" \
        "a(Landroid/content/pm/PackageManager;)I" \
        "70"

    SMALI_PATCH "system" "$AIRCOMMAND_APK" \
        "smali/b5/b.smali" \
        "return" \
        "c()I" \
        "70"

    APPLY_PATCH "system" "$AIRCOMMAND_APK" \
        "$SRC_DIR/unica/patches/spen/AirCommand.apk/0001-Add-AirCommand-shortcut-detach-simulator.patch"

    LOG_STEP_OUT
else
    LOGW "AirCommand.apk is not present in work_dir. Skipping AirCommand logic patch"
fi

LOG_STEP_IN "- Applying S Pen floating feature config"
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_FRAMEWORK_CONFIG_SPEN_GARAGE_SPEC" "type=insert, bundled=true"
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_FRAMEWORK_CONFIG_SPEN_VERSION" "70"
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_SETTINGS_SUPPORT_S_PEN_HOVERING_N_DETACHMENT" "TRUE"
LOG_STEP_OUT

unset AIRCOMMAND_APK
