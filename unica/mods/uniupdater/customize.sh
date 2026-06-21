LOG_STEP_IN "- Patching SecSettings to use UniUpdater"

DECODE_APK "system" "system/priv-app/SecSettings/SecSettings.apk"

FTP="
system/priv-app/SecSettings/SecSettings.apk/smali_classes3/com/samsung/android/settings/softwareupdate/SoftwareUpdateMenuProvider.smali
system/priv-app/SecSettings/SecSettings.apk/smali_classes3/com/samsung/android/settings/softwareupdate/SoftwareUpdateUtils.smali
system/priv-app/SecSettings/SecSettings.apk/smali_classes3/com/samsung/android/settings/softwareupdate/UpdateHistoryDBHelper\$\$ExternalSyntheticLambda0.smali
system/priv-app/SecSettings/SecSettings.apk/smali_classes3/com/samsung/android/settings/softwareupdate/SoftwareUpdateSettings\$1.smali
system/priv-app/SecSettings/SecSettings.apk/smali_classes3/com/samsung/android/settings/softwareupdate/SoftwareUpdateVariant.smali
system/priv-app/SecSettings/SecSettings.apk/smali_classes3/com/samsung/android/settings/homepage/TopLevelSoftwareUpdatePreferenceController.smali
"

for f in $FTP; do
    if [ -f "$APKTOOL_DIR/$f" ]; then
        sed -i "s/com.wssyncmldm.UserInitEntryActivity/com.universal.updater.MainActivity/g" "$APKTOOL_DIR/$f"
        sed -i "s/com.wssyncmldm.LastUpdateActivity/com.universal.updater.MainActivity/g" "$APKTOOL_DIR/$f"
        sed -i "s/com.wssyncmldm/com.universal.updater/g" "$APKTOOL_DIR/$f"
    fi
done

LOG_STEP_OUT
