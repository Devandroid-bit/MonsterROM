if [ ! "$(GET_PROP "system" "ro.unica.codename")" ]; then
    # Match latest Samsung's flagship device codename
    ROM_CODENAME="$(basename "$MODPATH")"
    SET_PROP "system" "ro.unica.codename" "${ROM_CODENAME^}"
    unset ROM_CODENAME
fi

if ! $TARGET_AUDIO_SUPPORT_ACH_RINGTONE; then
    LOG_STEP_IN "- Adding non-ACH audio fallback"
    SET_PROP "vendor" "ro.config.ringtone" "Galaxy_Bells.ogg"
    SET_PROP "vendor" "ro.config.notification_sound" "Brightline.ogg"
    SET_PROP "vendor" "ro.config.alarm_alert" "Morning_Xylophone.ogg"
    SET_PROP "vendor" "ro.config.media_sound" "Media_preview_Over_the_horizon.ogg"
    SET_PROP "vendor" "ro.config.ringtone_2" "Atomic_Bell.ogg"
    SET_PROP "vendor" "ro.config.notification_sound_2" "Three_Star.ogg"
    LOG_STEP_OUT
fi

if [ -f "$WORK_DIR/system/system/priv-app/SecSoundPicker/SecSoundPicker.apk" ]; then
    APPLY_PATCH "system" "system/priv-app/SecSoundPicker/SecSoundPicker.apk" \
        "$MODPATH/brandsound/SecSoundPicker.apk/0001-Enable-SUPPORT_SAMSUNG_BRAND_SOUND_ONEUI_7.patch"
fi
