if [ ! "$(GET_PROP "system" "ro.unica.version")" ]; then
    SET_PROP "system" "ro.unica.version" "$ROM_VERSION"
fi

LOG_STEP_IN "- Adding UN1CA Settings"

# Dynamically patch SecSettings
# - Add missing/non-xml files in place
# - Patch existing files
#   - Use the first line of the file to tell sed how to apply the rest of the content
#   - Exception made for files under *res/values* where the "resources" tag gets nuked
while IFS= read -r f; do
    f="${f//$MODPATH\/SecSettings.apk\//}"

    if [ ! -f "$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk/$f" ] || \
            [[ "$f" != *".xml" ]]; then
        LOG "- Adding \"$f\" to /system/system/priv-app/SecSettings.apk"
        EVAL "mkdir -p \"$(dirname "$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk/$f")\""
        EVAL "cp -a \"$MODPATH/SecSettings.apk/${f//\$/\\$}\" \"$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk/${f//\$/\\$}\""
    else
        LOG "- Patching \"$f\" in /system/system/priv-app/SecSettings.apk"
        if [[ "$f" == *"res/values"* ]]; then
            PATCH_INST="/<\/resources>/i"
            CONTENT="$(sed -e "/?xml/d" -e "/resources>/d" "$MODPATH/SecSettings.apk/$f")"
        else
            PATCH_INST="$(head -n 1 "$MODPATH/SecSettings.apk/$f")"
            CONTENT="$(tail -n +2 "$MODPATH/SecSettings.apk/$f")"
        fi
        CONTENT="$(sed -e "s/\"/\\\\\"/g" -e "s/\\$/\\\\$/g" -e "s/ /\\\ /g" -e "s/\\\\n/\\\\\\\\\n/g" <<< "$CONTENT")"
        CONTENT="$(sed -E ':a;N;$!ba;s/\r{0,1}\n/\\n/g' <<< "$CONTENT")"
        EVAL "sed -i \"$PATCH_INST $CONTENT\" \"$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk/$f\""
    fi
done < <(find "$MODPATH/SecSettings.apk" -type f)

# Add UN1CA Settings SearchIndexableData registrations
LOG "- Patching \"smali_classes2/com/android/settings/search/SearchFeatureProviderImpl\$\$ExternalSyntheticLambda0.smali\" in /system/system/priv-app/SecSettings.apk"
SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
    "smali_classes2/com/android/settings/search/SearchFeatureProviderImpl\$\$ExternalSyntheticLambda0.smali" "replace" \
    'invoke()Ljava/lang/Object;' \
    'return-object p0' \
    '    invoke-static {p0}, Lio/mesalabs/unica/search/UnicaSearchIndexableResources;->register(Lcom/android/settingslib/search/SearchIndexableResourcesBase;)V\n\n    return-object p0' \
    > /dev/null

DECODE_APK "system" "system/priv-app/SecSettingsIntelligence/SecSettingsIntelligence.apk"
LOG "- Patching \"smali_classes2/com/samsung/android/settings/intelligence/search/categorizing/TopLevelKeysCollector.smali\" in /system/system/priv-app/SecSettingsIntelligence/SecSettingsIntelligence.apk"
SMALI_PATCH "system" "system/priv-app/SecSettingsIntelligence/SecSettingsIntelligence.apk" \
    "smali_classes2/com/samsung/android/settings/intelligence/search/categorizing/TopLevelKeysCollector.smali" "replace" \
    '<init>(Landroid/content/Context;)V' \
    '.locals 37' \
    '.locals 38' \
    > /dev/null
SMALI_PATCH "system" "system/priv-app/SecSettingsIntelligence/SecSettingsIntelligence.apk" \
    "smali_classes2/com/samsung/android/settings/intelligence/search/categorizing/TopLevelKeysCollector.smali" "replace" \
    '<init>(Landroid/content/Context;)V' \
    'filled-new-array/range {v1 .. v36}, [Ljava/lang/String;' \
    '    const-string v37, "top_level_unica"\n\n    filled-new-array/range {v1 .. v37}, [Ljava/lang/String;' \
    > /dev/null

unset PATCH_INST CONTENT

LOG_STEP_OUT
