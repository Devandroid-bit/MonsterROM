LAUNCHER_APK="system/priv-app/TouchWizHome_2017/TouchWizHome_2017.apk"
INPUT_CONSUMER_SMALI="smali_classes2/com/android/systemui/shared/system/InputConsumerController.smali"
SCREEN_STATE_OBSERVER_SMALI="smali_classes5/com/samsung/app/honeyspace/edge/edgepanel/data/repository/visibility/ScreenStateObserver.smali"

DECODE_APK "system" "$LAUNCHER_APK" || return 1

LAUNCHER_APKTOOL_DIR="$APKTOOL_DIR/system/priv-app/TouchWizHome_2017/TouchWizHome_2017.apk"

LOG "- Applying One UI 9 launcher input consumer compatibility"
if grep -q 'createInputConsumer(Landroid/os/IBinder;Ljava/lang/String;ILandroid/view/InputChannel;)V' "$LAUNCHER_APKTOOL_DIR/$INPUT_CONSUMER_SMALI"; then
    sed -E -i \
        's#invoke-interface \{([^,]+), ([^,]+), ([^,]+), ([^,]+), ([^}]+)\}, Landroid/view/IWindowManager;->createInputConsumer\(Landroid/os/IBinder;Ljava/lang/String;ILandroid/view/InputChannel;\)V#invoke-interface {\1, \2, \3, \4}, Landroid/view/IWindowManager;->createInputConsumer(Landroid/os/IBinder;Ljava/lang/String;I)Landroid/view/InputChannel;\n\n    move-result-object \5#g' \
        "$LAUNCHER_APKTOOL_DIR/$INPUT_CONSUMER_SMALI"
fi

SMALI_PATCH "system" "$LAUNCHER_APK" "$INPUT_CONSUMER_SMALI" "replace" \
    'registerInputConsumer()V' \
    'throw p0' \
    'goto :goto_0' \
    > /dev/null || true
SMALI_PATCH "system" "$LAUNCHER_APK" "$INPUT_CONSUMER_SMALI" "replace" \
    'registerSubDisplayInputConsumer()V' \
    'throw p0' \
    'goto :goto_0' \
    > /dev/null || true

LOG "- Fixing launcher screen-state receiver verifier issue"
SMALI_PATCH "system" "$LAUNCHER_APK" "$SCREEN_STATE_OBSERVER_SMALI" "replace" \
    'registerScreenStateBr()V' \
    '.locals 7' \
    '.locals 8' \
    > /dev/null || true
SMALI_PATCH "system" "$LAUNCHER_APK" "$SCREEN_STATE_OBSERVER_SMALI" "replace" \
    'registerScreenStateBr()V' \
    'iget-object p0, p0, Lcom/samsung/app/honeyspace/edge/edgepanel/data/repository/visibility/ScreenStateObserver;->context:Landroid/content/Context;' \
    'iget-object v7, p0, Lcom/samsung/app/honeyspace/edge/edgepanel/data/repository/visibility/ScreenStateObserver;->context:Landroid/content/Context;' \
    > /dev/null || true
SMALI_PATCH "system" "$LAUNCHER_APK" "$SCREEN_STATE_OBSERVER_SMALI" "replace" \
    'registerScreenStateBr()V' \
    'invoke-direct {p0, p0, v4}, Lcom/samsung/app/honeyspace/edge/edgepanel/data/repository/visibility/ScreenStateObserver;->getPendingIntent(Landroid/content/Context;Ljava/lang/String;)Landroid/app/PendingIntent;' \
    'invoke-direct {p0, v7, v4}, Lcom/samsung/app/honeyspace/edge/edgepanel/data/repository/visibility/ScreenStateObserver;->getPendingIntent(Landroid/content/Context;Ljava/lang/String;)Landroid/app/PendingIntent;' \
    > /dev/null || true
SMALI_PATCH "system" "$LAUNCHER_APK" "$SCREEN_STATE_OBSERVER_SMALI" "replace" \
    'registerScreenStateBr()V' \
    'const/4 p0, 0x0' \
    'const/4 v7, 0x0' \
    > /dev/null || true
SMALI_PATCH "system" "$LAUNCHER_APK" "$SCREEN_STATE_OBSERVER_SMALI" "replace" \
    'registerScreenStateBr()V' \
    'invoke-virtual {v5, v6, v4, v2, p0}, Lcom/samsung/android/sepunion/SemEventDelegationManager;->registerPendingIntent(Landroid/content/IntentFilter;Landroid/app/PendingIntent;ILjava/util/List;)V' \
    'invoke-virtual {v5, v6, v4, v2, v7}, Lcom/samsung/android/sepunion/SemEventDelegationManager;->registerPendingIntent(Landroid/content/IntentFilter;Landroid/app/PendingIntent;ILjava/util/List;)V' \
    > /dev/null || true

awk '
    /^\.method/ && index($0, "registerScreenStateBr()V") {
        print
        print "    .locals 0"
        print ""
        print "    return-void"
        inside = 1
        changed = 1
        next
    }
    inside && /^\.end method/ {
        print
        inside = 0
        next
    }
    inside {
        next
    }
    {
        print
    }
    END {
        if (!changed) {
            exit 1
        }
    }
' "$LAUNCHER_APKTOOL_DIR/$SCREEN_STATE_OBSERVER_SMALI" \
    > "$LAUNCHER_APKTOOL_DIR/$SCREEN_STATE_OBSERVER_SMALI.tmp" \
    && mv "$LAUNCHER_APKTOOL_DIR/$SCREEN_STATE_OBSERVER_SMALI.tmp" "$LAUNCHER_APKTOOL_DIR/$SCREEN_STATE_OBSERVER_SMALI" \
    || {
        rm -f "$LAUNCHER_APKTOOL_DIR/$SCREEN_STATE_OBSERVER_SMALI.tmp"
        ABORT "Failed to replace launcher registerScreenStateBr with One UI 9 safe stub"
    }

unset LAUNCHER_APK INPUT_CONSUMER_SMALI SCREEN_STATE_OBSERVER_SMALI LAUNCHER_APKTOOL_DIR
