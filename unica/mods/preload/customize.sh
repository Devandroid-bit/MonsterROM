# Samsung Internet Browser
# https://play.google.com/store/apps/details?id=com.sec.android.app.sbrowser
LOG "- Downloading Samsung Internet app"
DOWNLOAD_FILE "$(GET_GALAXY_STORE_DOWNLOAD_URL "com.sec.android.app.sbrowser")" \
    "$WORK_DIR/system/system/preload/SBrowser/SBrowser.apk"

VPL_LIST="$WORK_DIR/system/system/etc/vpl_apks_count_list.txt"
mkdir -p "$(dirname "$VPL_LIST")"
touch "$VPL_LIST"

while IFS= read -r i; do
    i="${i//$WORK_DIR\/system\//}"

    if [ -d "$WORK_DIR/system/$i" ]; then
        SET_METADATA "system" "$i" 0 0 755 "u:object_r:system_file:s0"
    else
        SET_METADATA "system" "$i" 0 0 644 "u:object_r:system_file:s0"
    fi

    if [[ "$i" == *".apk" ]] && \
            ! grep -qF "$i" "$VPL_LIST"; then
        LOG "- Adding \"$i\" to /system/system/etc/vpl_apks_count_list.txt"
        EVAL "echo \"$i\" >> \"$VPL_LIST\""
    fi
done <<< "$(find "$WORK_DIR/system/system/preload")"

LC_ALL=C sort -u -o "$VPL_LIST" "$VPL_LIST"
SET_METADATA "system" "system/etc/vpl_apks_count_list.txt" \
    0 0 644 "u:object_r:system_file:s0"

