LOG_STEP_IN "- Setting FUSE passthrough"
SET_PROP "vendor" "persist.sys.fuse.passthrough.enable" "true"
LOG_STEP_OUT

LOG "- Disabling encryption"
# Encryption
LINE=$(sed -n "/^\/dev\/block\/by-name\/userdata/=" "$WORK_DIR/vendor/etc/fstab.exynos2100")
sed -i "${LINE}s/,fileencryption=aes-256-xts:aes-256-cts:v2//g" "$WORK_DIR/vendor/etc/fstab.exynos2100"

# ODE
sed -i -e "/ODE/d" -e "/keydata/d" -e "/keyrefuge/d" "$WORK_DIR/vendor/etc/fstab.exynos2100"

LOG_STEP_IN "- Fixing vendor display props"
# DPI
LCD_DENSITY="$(GET_PROP "vendor" "ro.sf.lcd_density")"
if [ "$LCD_DENSITY" ]; then
    SET_PROP "vendor" "ro.sf.init.lcd_density" "$LCD_DENSITY"
else
    ABORT "ro.sf.lcd_density prop not found in vendor"
fi
LOG_STEP_OUT

LOG_STEP_IN "- Removing unsupported Qualcomm location/QCC stack"
GET_SYSTEM_EXT()
{
    if $TARGET_OS_BUILD_SYSTEM_EXT_PARTITION; then
        echo "system_ext"
    else
        echo "system/system/system_ext"
    fi
}

_SED_DELETE_IF_EXISTS()
{
    local FILE="$1"
    shift

    [ -f "$FILE" ] || return 0
    sed -i "$@" "$FILE"
}

_FOR_EACH_EXYNOS_INIT()
{
    local SED_EXPR="$1"
    local INIT_RC

    for INIT_RC in \
        "$WORK_DIR/vendor/etc/init/init.exynos2100.rc"; do
        _SED_DELETE_IF_EXISTS "$INIT_RC" "$SED_EXPR"
    done
}

_DISABLE_PERFETTO_TRACED()
{
    local PERFETTO_RC="$WORK_DIR/system/system/etc/init/perfetto.rc"

    [ -f "$PERFETTO_RC" ] || return 0

    LOG "- Disabling Perfetto traced daemon for legacy Exynos kernel"
    sed -i \
        -e 's/^\([[:space:]]*\)setprop persist\.traced\.enable 1$/\1# setprop persist.traced.enable 1/g' \
        -e 's/^\([[:space:]]*\)start traced$/\1# start traced/g' \
        -e 's/^\([[:space:]]*\)start traced_relay$/\1# start traced_relay/g' \
        -e 's/^\([[:space:]]*\)start traced_probes$/\1# start traced_probes/g' \
        -e 's/^\([[:space:]]*\)wait_for_prop sys\.trace\.traced_started 1$/\1# wait_for_prop sys.trace.traced_started 1/g' \
        "$PERFETTO_RC"
    SET_PROP_IF_DIFF "system" "persist.traced.enable" "0"
}

_FIX_STRONGBOX_KEYMASTER_RC()
{
    local RC="$WORK_DIR/vendor/etc/init/android.hardware.keymaster@4.0_strongbox-service.rc"

    [ -f "$RC" ] || return 0

    if ! grep -q "^    interface android\.hardware\.keymaster@4\.0::IKeymasterDevice strongbox$" "$RC"; then
        sed -i \
            "/^service vendor\.keymaster-4-0_strongbox /a\\    interface android.hardware.keymaster@4.0::IKeymasterDevice strongbox" \
            "$RC"
    fi
}

_DISABLE_STALE_KEYMASTER_WAIT()
{
    LOG "- Disabling stale wait_for_keymaster init hook"
    _FOR_EACH_EXYNOS_INIT 's/^\([[:space:]]*\)exec_start wait_for_keymaster$/\1# exec_start wait_for_keymaster/g'
}

_PATCH_SENSORHUB_SYSFS_LOG_NOISE()
{
    local SENSORHUB="$WORK_DIR/vendor/lib64/sensors.sensorhub.so"

    [ -f "$SENSORHUB" ] || return 0

    LOG "- Suppressing noisy sensorhub sysfs write error logs"
    HEX_PATCH "$SENSORHUB" \
        "c0008052e30316aae503142a245d0094e00315aa" \
        "c0008052e30316aae503142a1f2003d5e00315aa" || true
    HEX_PATCH "$SENSORHUB" \
        "c0008052e30313aae503142a115d0094" \
        "c0008052e30313aae503142a1f2003d5" || true
}

_DROP_MISSING_SENSOR_HAL_BLOBS()
{
    local HALS_CONF="$WORK_DIR/vendor/etc/sensors/hals.conf"
    local HAL_BLOB
    local HAL_PATTERN

    [ -f "$HALS_CONF" ] || return 0

    for HAL_BLOB in sensors.bio.so; do
        [ ! -f "$WORK_DIR/vendor/lib64/$HAL_BLOB" ] || continue
        HAL_PATTERN="${HAL_BLOB//./\\.}"

        if grep -q "$HAL_BLOB" "$HALS_CONF"; then
            LOG "- Removing absent $HAL_BLOB from vendor sensors hals.conf"
            sed -i "/$HAL_PATTERN/d" "$HALS_CONF"
        fi
    done
}

_DISABLE_SURFACEFLINGER_SHADER_CACHE()
{
    local INIT_RC="$WORK_DIR/system/system/etc/init/hw/init.rc"
    local PROP

    [ -f "$INIT_RC" ] || return 0

    if grep -q "^[[:space:]]*setprop service\.sf\.cache_dir_available 1$" "$INIT_RC"; then
        LOG "- Disabling SurfaceFlinger shader cache priming for legacy gralloc"
        sed -i \
            's/^\([[:space:]]*\)setprop service\.sf\.cache_dir_available 1$/\1# setprop service.sf.cache_dir_available 1/g' \
            "$INIT_RC"
    fi

    LOG "- Disabling SurfaceFlinger prime shader cache"
    SET_PROP "product" "service.sf.cache_dir_available" "0"
    SET_PROP "product" "service.sf.prime_shader_cache" "0"

    for PROP in \
        debug.sf.prime_shader_cache.clipped_dimmed_image_layers \
        debug.sf.prime_shader_cache.clipped_layers \
        debug.sf.prime_shader_cache.edge_extension_shader \
        debug.sf.prime_shader_cache.hole_punch \
        debug.sf.prime_shader_cache.image_dimmed_layers \
        debug.sf.prime_shader_cache.image_layers \
        debug.sf.prime_shader_cache.pip_image_layers \
        debug.sf.prime_shader_cache.shadow_layers \
        debug.sf.prime_shader_cache.solid_dimmed_layers \
        debug.sf.prime_shader_cache.solid_layers \
        debug.sf.prime_shader_cache.transparent_image_dimmed_layers; do
        SET_PROP "product" "$PROP" "0"
    done
}

_DISABLE_UNSUPPORTED_MAINLINE_FEATURES()
{
    LOG "- Disabling UFFD GC and RKP paths unsupported by Exynos2100 vendor"
    SET_PROP "product" "ro.dalvik.vm.enable_uffd_gc" "false"
    SET_PROP "product" "persist.device_config.runtime_native_boot.enable_uffd_gc" "false"
    SET_PROP "product" "remote_provisioning.enable_rkpd" "false"
    SET_PROP "product" "remote_provisioning.tee.rkp_only" "0"
    DELETE_FROM_WORK_DIR "system" "system/apex/com.google.android.rkpd_compressed.apex"
    _SED_DELETE_IF_EXISTS "$WORK_DIR/system/system/etc/irremovable_list.txt" "/com\.\(android\|google\.android\)\.rkpd/d"
    _SED_DELETE_IF_EXISTS "$WORK_DIR/system/system/etc/permissions/platform.xml" "/com\.android\.rkpdapp/d"
}

_DISABLE_UNSUPPORTED_BT_OFFLOAD()
{
    LOG "- Disabling Bluetooth audio offload paths unsupported by Exynos2100 vendor"
    SET_PROP "product" "persist.bluetooth.a2dp_offload.disabled" "true"
    SET_PROP "product" "persist.bluetooth.leaudio_offload.disabled" "true"
    SET_PROP "product" "persist.vendor.bt.a2dp_offload.disabled" "true"
    SET_PROP "product" "persist.vendor.bluetooth.a2dp_offload.disabled" "true"
    SET_PROP "product" "ro.bluetooth.leaudio_offload.supported" "false"
    SET_PROP "product" "persist.bluetooth.samsung.a2dp_offload.cap" --delete
    SET_PROP "product" "persist.bluetooth.samsung.a2dp.cap" "SBC,AAC"
    SET_PROP "product" "persist.bluetooth.samsung.leaudio.livecast" "false"
    SET_PROP "product" "media.stagefright.enable-fma2dp" "false"
    SET_PROP "product" "ro.bluetooth.library_name" --delete
    SET_PROP "product" "bluetooth.a2dp.source.sbc_priority.config" "1001"
    SET_PROP "product" "bluetooth.a2dp.source.aac_priority.config" "900000"
    SET_PROP "product" "bluetooth.a2dp.source.aptx_priority.config" "-1"
    SET_PROP "product" "bluetooth.a2dp.source.aptx_hd_priority.config" "-1"
    SET_PROP "product" "bluetooth.a2dp.source.ldac_priority.config" "-1"
    SET_PROP "product" "bluetooth.a2dp.source.opus_priority.config" "-1"
    SET_PROP "product" "bluetooth.a2dp.source.lhdcv5_priority.config" "-1"
    SET_PROP "product" "audio.offload.disable" "1"
    SET_PROP "product" "audio.offload.video" "false"
    SET_PROP "product" "audio.deep_buffer.media" "false"
    SET_PROP "product" "tunnel.audio.encode" "false"
    SET_PROP "product" "media.stagefright.audio.deep" "false"
}

_DISABLE_UNSUPPORTED_OUI9_INIT_WRITES()
{
    LOG "- Removing One UI 9 init writes rejected by the Exynos2100 kernel"
    _SED_DELETE_IF_EXISTS "$WORK_DIR/system/system/etc/init/init.memory.rc" "/\/sys\/kernel\/mm\/transparent_hugepage\/khugepaged\/max_ptes_shared/d"
    _SED_DELETE_IF_EXISTS "$WORK_DIR/system/system/etc/init/atrace.rc" "/\/sys\/kernel\/tracing\/synthetic_events/d"
    _SED_DELETE_IF_EXISTS "$WORK_DIR/system/system/etc/init/hw/init.rc" \
        -e "/\/dev\/blkio\/blkio\.weight/d" \
        -e "/\/dev\/blkio\/background\/blkio\.weight/d" \
        -e "/\/dev\/blkio\/background\/blkio\.bfq\.weight/d" \
        -e "/\/dev\/blkio\/blkio\.group_idle/d" \
        -e "/\/dev\/blkio\/background\/blkio\.group_idle/d" \
        -e "/\/dev\/blkio\/background\/blkio\.prio\.class/d" \
        -e "/\/dev\/blkio\/top\/blkio\.ssg\.boost_on/d" \
        -e "/\/dev\/blkio\/high\/blkio\.ssg\.max_available_ratio/d" \
        -e "/\/dev\/blkio\/normal\/blkio\.ssg\.max_available_ratio/d" \
        -e "/\/dev\/blkio\/low\/blkio\.ssg\.max_available_ratio/d" \
        -e "/\/sys\/class\/sensors\/grip_sensor\/grip_request_firmware/d" \
        -e "/\/dev\/sys\/fs\/by-name\/userdata\/seq_file_ra_mul/d" \
        -e "/\/sys\/class\/power_supply\/battery\/batt_update_data/d"
    _SED_DELETE_IF_EXISTS "$WORK_DIR/system/system/etc/init/init.sec-charger.rc" "/\/sys\/class\/power_supply\/battery\/batt_update_data/d"
    _SED_DELETE_IF_EXISTS "$WORK_DIR/vendor/etc/init/init.exynos2100.rc" \
        -e "/\/dev\/freezer\/frozen\/freezer\.killable/d" \
        -e "/\/dev\/cpuctl\/foreground\/cpu\.rt_runtime_us/d" \
        -e "/\/dev\/cpuctl\/background\/cpu\.rt_runtime_us/d" \
        -e "/\/dev\/cpuctl\/top-app\/cpu\.rt_runtime_us/d" \
        -e "/\/proc\/sys\/net\/core\/netdev_max_backlog/d"
    _SED_DELETE_IF_EXISTS "$WORK_DIR/vendor/etc/init/init.baseband.rc" "/\/proc\/sys\/net\/core\/netdev_max_backlog/d"
    _SED_DELETE_IF_EXISTS "$WORK_DIR/vendor/etc/init/init.nfc.samsung.rc" "/\/sys\/class\/nfc_sec\/pvdd/d"
}

_SET_LOG_TAG_LEVEL()
{
    local TAG="$1"
    local LEVEL="$2"

    SET_PROP "product" "log.tag.$TAG" "$LEVEL"
    SET_PROP "product" "persist.log.tag.$TAG" "$LEVEL"
}

_QUIET_VISIBLE_LOGFOX_NOISE()
{
    LOG "- Quieting non-fatal One UI 9 debug log spam"

    SET_PROP "system" "ro.logd.kernel" "false"
    SET_PROP "product" "debug.sf.show_refresh_rate_overlay_render_rate" "false"
    SET_PROP "product" "persist.debug.wfd.enable" "0"
    SET_PROP "product" "nfc.nxp_log_level_global" "0"
    SET_PROP "product" "persist.vendor.nfc.log.index" "0"
    SET_PROP "product" "persist.log.level" "0xFFFFFFFF"
    SET_PROP "product" "persist.log.semlevel" "0xFFFFFF00"
    SET_PROP "product" "log.tag" "E"
    SET_PROP "product" "persist.log.tag" "E"

    _SET_LOG_TAG_LEVEL "SurfaceFlinger" "F"
    _SET_LOG_TAG_LEVEL "WifiDisplayAdapter" "W"
    _SET_LOG_TAG_LEVEL "WifiDisplayController" "W"
    _SET_LOG_TAG_LEVEL "DisplayManagerService" "W"
    _SET_LOG_TAG_LEVEL "NxpGenExtn" "F"
    _SET_LOG_TAG_LEVEL "RILJ" "F"
    _SET_LOG_TAG_LEVEL "SEM_RILJ" "F"
    _SET_LOG_TAG_LEVEL "RILD" "F"
    _SET_LOG_TAG_LEVEL "RILD2" "F"
    _SET_LOG_TAG_LEVEL "Multi-Client" "F"
    _SET_LOG_TAG_LEVEL "Multi-Client2" "F"
    _SET_LOG_TAG_LEVEL "BSOHChargingDataCollector" "W"
    _SET_LOG_TAG_LEVEL "PackageConfigPersister" "E"
    _SET_LOG_TAG_LEVEL "GlassesApi" "F"
    _SET_LOG_TAG_LEVEL "cnka" "F"
    _SET_LOG_TAG_LEVEL "LockPatternUtils" "E"
    _SET_LOG_TAG_LEVEL "usb_notify" "W"
    _SET_LOG_TAG_LEVEL "APM_AudioPolicyManager" "E"
    _SET_LOG_TAG_LEVEL "vendor.samsung.bluetooth.audio.BTAudioProvider" "W"
    _SET_LOG_TAG_LEVEL "BatteryService_BatteryPropertiesRegistrar" "W"
    _SET_LOG_TAG_LEVEL "SemWifiIntelligentTrainingManager" "W"
    _SET_LOG_TAG_LEVEL "Settings" "E"
    _SET_LOG_TAG_LEVEL "PackageManager" "E"
    _SET_LOG_TAG_LEVEL "Binder" "E"
    _SET_LOG_TAG_LEVEL "SemWallpaperColorsArea" "E"
    _SET_LOG_TAG_LEVEL "SmartFaceManager" "F"
    _SET_LOG_TAG_LEVEL "SmartFaceService" "F"
    _SET_LOG_TAG_LEVEL "SmartFaceServiceStarter" "F"
    _SET_LOG_TAG_LEVEL "ExynosCameraNode" "E"
    _SET_LOG_TAG_LEVEL "CameraDeviceClient" "E"
    _SET_LOG_TAG_LEVEL "CAE" "E"
    _SET_LOG_TAG_LEVEL "Sensors" "F"
    _SET_LOG_TAG_LEVEL "SensorService" "F"
    _SET_LOG_TAG_LEVEL "SemContext.CaeProvider" "F"
    _SET_LOG_TAG_LEVEL "LocalDisplayAdapter" "E"
    _SET_LOG_TAG_LEVEL "display" "F"
    _SET_LOG_TAG_LEVEL "ShellTransitions" "F"
    _SET_LOG_TAG_LEVEL "NativeCustomFrequencyManager" "F"
    _SET_LOG_TAG_LEVEL "AODManagerService" "F"
    _SET_LOG_TAG_LEVEL "libprocessgroup" "E"
    _SET_LOG_TAG_LEVEL "DeviceStorageMonitorService" "E"
    _SET_LOG_TAG_LEVEL "AccountTypeLoader" "E"
    _SET_LOG_TAG_LEVEL "System" "E"
    _SET_LOG_TAG_LEVEL "keymaster_tee" "E"
    _SET_LOG_TAG_LEVEL "ConnectivityService" "W"
    _SET_LOG_TAG_LEVEL "ConnectivityManager" "W"
    _SET_LOG_TAG_LEVEL "BLASTSyncEngine" "E"
    _SET_LOG_TAG_LEVEL "bt_btm_pm" "E"
    _SET_LOG_TAG_LEVEL "bluetooth" "E"
    _SET_LOG_TAG_LEVEL "ProcessStats" "E"
    _SET_LOG_TAG_LEVEL "Netd" "E"
    _SET_LOG_TAG_LEVEL "AlarmManager" "E"
    _SET_LOG_TAG_LEVEL "id.app.launcher" "E"
    _SET_LOG_TAG_LEVEL "Watchdog" "F"
    _SET_LOG_TAG_LEVEL "DBManager" "F"
    _SET_LOG_TAG_LEVEL "AbsSettings" "F"
    _SET_LOG_TAG_LEVEL "WallpaperResourcesInfo" "E"
    _SET_LOG_TAG_LEVEL "getBitmap" "F"
    _SET_LOG_TAG_LEVEL "FuseDaemon" "F"
    _SET_LOG_TAG_LEVEL "ActivityManager" "F"
    _SET_LOG_TAG_LEVEL "roid.themestore" "F"
    _SET_LOG_TAG_LEVEL "ThemeCenter_ThemeManagerService" "F"
    _SET_LOG_TAG_LEVEL "PermissionService" "E"
    _SET_LOG_TAG_LEVEL "AdvertisingIdSettings" "E"
    _SET_LOG_TAG_LEVEL "AODSettingsHelper" "F"
    _SET_LOG_TAG_LEVEL "Kumiho-Kumiho" "E"
    _SET_LOG_TAG_LEVEL "NearbyMediums" "E"
    _SET_LOG_TAG_LEVEL "NearbyConnections" "E"
    _SET_LOG_TAG_LEVEL "NearbySharing" "E"
    _SET_LOG_TAG_LEVEL "NearbyDiscovery" "E"
    _SET_LOG_TAG_LEVEL "BtGatt.AdvertiseManager" "E"
    _SET_LOG_TAG_LEVEL "BluetoothMetrics" "E"
    _SET_LOG_TAG_LEVEL "rfcomm_port_utils" "E"
    _SET_LOG_TAG_LEVEL "AppOpService" "F"
    _SET_LOG_TAG_LEVEL "AppOps" "F"
    _SET_LOG_TAG_LEVEL "PlayIntegrityHooks" "F"
    _SET_LOG_TAG_LEVEL "QueryBuilder" "F"
    _SET_LOG_TAG_LEVEL "RemoteWorkerFactory" "E"
    _SET_LOG_TAG_LEVEL "JobInfo" "E"
    _SET_LOG_TAG_LEVEL "MetadataRetrieverClient" "F"
    _SET_LOG_TAG_LEVEL "CMHProvider" "F"
    _SET_LOG_TAG_LEVEL "SatelliteController" "F"
    _SET_LOG_TAG_LEVEL "CmcServiceHelper" "F"
    _SET_LOG_TAG_LEVEL "ImsUri" "F"
    _SET_LOG_TAG_LEVEL "SecImsServiceConnector" "F"
    _SET_LOG_TAG_LEVEL "ContextImpl" "E"
    _SET_LOG_TAG_LEVEL "NSLocationMonitor" "E"
    _SET_LOG_TAG_LEVEL "NetworkManager_FLP" "E"
    _SET_LOG_TAG_LEVEL "resolv" "E"
    _SET_LOG_TAG_LEVEL "View" "E"
    _SET_LOG_TAG_LEVEL "KeyguardSecurityViewFlipper" "E"
    _SET_LOG_TAG_LEVEL "CCTFlatFileLogStore" "E"
    _SET_LOG_TAG_LEVEL "SQLiteLog" "F"
    _SET_LOG_TAG_LEVEL "SQLiteCursor" "F"
    _SET_LOG_TAG_LEVEL "SensorsGrip" "F"
    _SET_LOG_TAG_LEVEL "SSS@search" "F"
    _SET_LOG_TAG_LEVEL "SemSupplicantStaIfaceHalHidlImpl" "F"
    _SET_LOG_TAG_LEVEL "power" "F"
    _SET_LOG_TAG_LEVEL "WM-WorkerWrapper" "F"
    _SET_LOG_TAG_LEVEL "MediaContentSyncTask" "F"
    _SET_LOG_TAG_LEVEL "ControllerEventHandler" "F"
    _SET_LOG_TAG_LEVEL "FileSyncManager" "F"
    _SET_LOG_TAG_LEVEL "WorkerUtils" "F"
    _SET_LOG_TAG_LEVEL "UnifiedCropper" "F"
    _SET_LOG_TAG_LEVEL "ArcSoft_C" "F"
    _SET_LOG_TAG_LEVEL "tflite" "F"
    _SET_LOG_TAG_LEVEL "kcgz" "F"
    _SET_LOG_TAG_LEVEL "SemanticLocation" "E"
    _SET_LOG_TAG_LEVEL "SLocation" "E"
    _SET_LOG_TAG_LEVEL "RequestManager_FLP" "F"
    _SET_LOG_TAG_LEVEL "wificond" "E"
    _SET_LOG_TAG_LEVEL "IE_Capabilities" "E"
    _SET_LOG_TAG_LEVEL "SemThroughputPredictor" "F"
    _SET_LOG_TAG_LEVEL "DIAGMON_SDK" "F"
    _SET_LOG_TAG_LEVEL "SystemServiceRegistry" "F"
    _SET_LOG_TAG_LEVEL "PersonalSafety" "E"
    _SET_LOG_TAG_LEVEL "TelephonyCallback" "E"
    _SET_LOG_TAG_LEVEL "SemBatteryUsageStatsProvider" "E"
    _SET_LOG_TAG_LEVEL "Finsky" "E"
    _SET_LOG_TAG_LEVEL "ActivityThread" "E"
    _SET_LOG_TAG_LEVEL "GAEEngine" "E"
    _SET_LOG_TAG_LEVEL "SyncManager" "E"
    _SET_LOG_TAG_LEVEL "Controller" "F"
    _SET_LOG_TAG_LEVEL "SDMConfig" "E"
    _SET_LOG_TAG_LEVEL "qr_barcode_decoder" "F"
    _SET_LOG_TAG_LEVEL "GmsTaskScheduler" "F"

    for TAG in \
        "Moneta" "DataMlSdk" "NowBarCardViewModel" "SEMS" "RILClient" \
        "GsmCdmaPhone" "GoogleApiManager" "kbit" "LockWidgetData" \
        "LockCalendarHelper" "SafetyCenterManagerWrap" "TNP" \
        "CalendarSyncAdapter" "RILC" "rild" "DNC-0" "DNC-1" \
        "NetworkTypeController" "SemGsmCdmaPhone" "TelephonyAnalyticsSubId" \
        "NowBrief.LLMPolicy" "ConfigUpdater" "AppIconSolution" \
        "FSA2_SyncUpPhotoCursor" "simagent.HttpRequest" "engmode_client_aidl" \
        "SLocation" "SDHMS" "BluetoothCastAdapterService" \
        "BluetoothRemoteDevices" "BluetoothAdapterService" "CachedBluetoothDevice" \
        "BTAudioHalDeviceProxy" "BTAudioHalStream" "BTAudioA2dpHIDL" \
        "BTAudioClientHIDL" "A2dpService" "BluetoothActiveDeviceManager" \
        "bt_btif_storage" "bt_btu_hcif" "bluetooth-a2dp" \
        "BUPlugin_BudsLogManager" "DlbSpatializerEffectContext" \
        "AS.AudioDeviceInventory" "AS.AudioService" "AS.SpatializerHelper" \
        "BluetoothBDTestService" "BluetoothUtils" "SemWifiApSmartBleScanner" \
        "CameraService_worker" "cameraserver" "ExynosCameraInterface" \
        "ExynosCameraMetadataConverterVendor" "SveCamera" "LockGuard" \
        "GameTools" "GoogleSettingsUtils" "MediaProvider" \
        "SatelliteModemInterface" "AppSearchIcing" "BRListParser" \
        "PdeNotificationListenerService" "MemoryLeakHandler" "mAFPC_ABC" \
        "NotificationService" "LpaConnector" "CustomCpuInfoReader" \
        "DigitalHorizontalClockView_LOCK_SCREEN_2@218" \
        "DigitalHorizontalClockView_LOCK_SCREEN_2@115" \
        "ClockBlurManager@355_parent@218" "SecVibrator-HAL-AIDL-CORE" \
        "SecVibrator-HAL-AIDL-EXT" "pageboostd" "KeyguardFingerPrintSwipe" \
        "WorkSourceUtil" "AOD_CONFIG@AODConfigurationController" \
        "HoneySpace.ReflectionUtils" "HoneySpace.OnBoardingUtil" \
        "SettingsToPropertiesMapper" "AutofillManagerServiceImpl" \
        "GuestManager" "PocketModeEvent" "PocketMotionManager" \
        "AutomaticBrightnessController" "DreamController" "LSO_LSOInterface" \
        "NotifRow" "MODManager" "bauth_FPQCBAuthSensorControl" \
        "FaceServiceStorage" "BiometricScheduler" "MotionRecognitionService" \
        "WifiGuiderService" "TransitionChain" "ConsumerBase"; do
        _SET_LOG_TAG_LEVEL "$TAG" "F"
    done
}

_PATCH_CONST_BEFORE_BOOL_IPUT()
{
    local FILE="$1"
    local FIELD="$2"
    local COUNT

    awk -v FIELD="$FIELD" '
        { line[NR] = $0 }
        END {
            for (i = 1; i <= NR; i++) {
                if (index(line[i], FIELD) && line[i] ~ /iput-boolean/) {
                    for (j = i - 1; j >= 1 && j >= i - 6; j--) {
                        if (line[j] ~ /^[[:space:]]*const\/4 [vp][0-9]+, 0x1$/) {
                            sub(/0x1$/, "0x0", line[j])
                            changed++
                            break
                        }
                    }
                }
            }
            for (i = 1; i <= NR; i++) print line[i]
            if (!changed) exit 2
            print changed > "/dev/stderr"
        }
    ' "$FILE" > "$FILE.tmp" 2> "$FILE.count" && mv "$FILE.tmp" "$FILE" || {
        rm -f "$FILE.tmp" "$FILE.count"
        ABORT "Failed to patch boolean assignment for $FIELD in ${FILE//$SRC_DIR\//}"
    }

    COUNT="$(cat "$FILE.count")"
    rm -f "$FILE.count"
    LOG "- Patched $COUNT boolean assignment(s) for $FIELD"
}

_PATCH_BOOL_METHOD_RETURN()
{
    local FILE="$1"
    local METHOD="$2"
    local VALUE="$3"
    local HEX="0x0"

    [ "$VALUE" = "true" ] && HEX="0x1"

    awk -v METHOD="$METHOD" -v HEX="$HEX" '
        BEGIN { inside = 0; changed = 0 }
        /^\.method/ && index($0, METHOD) {
            print
            print "    .locals 1"
            print ""
            print "    const/4 v0, " HEX
            print ""
            print "    return v0"
            inside = 1
            changed = 1
            next
        }
        inside && /^\.end method/ {
            print
            inside = 0
            next
        }
        inside { next }
        { print }
        END { if (!changed) exit 2 }
    ' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE" || {
        rm -f "$FILE.tmp"
        ABORT "Failed to patch method $METHOD in ${FILE//$SRC_DIR\//}"
    }

    LOG "- Forced $METHOD to return $VALUE"
}

_PATCH_A2DP_LEGACY_CODEC_PRIORITIES()
{
    local SMALI="$1"

    [ -f "$SMALI" ] || ABORT "A2dpCodecConfig.smali not found"

    if grep -q "MonsterROM One UI 9 legacy BT codec guard" "$SMALI"; then
        LOG "- A2DP legacy codec priorities already patched"
        return 0
    fi

    awk '
        {
            print
            if ($0 ~ /iput v1, p0, Lcom\/android\/bluetooth\/a2dp\/A2dpCodecConfig;->mA2dpSourceCodecPrioritySscUhq:I/) {
                print ""
                print "    # MonsterROM One UI 9 legacy BT codec guard"
                print "    const/16 v0, 0x3e9"
                print "    iput v0, p0, Lcom/android/bluetooth/a2dp/A2dpCodecConfig;->mA2dpSourceCodecPrioritySbc:I"
                print ""
                print "    const v0, 0xdbba0"
                print "    iput v0, p0, Lcom/android/bluetooth/a2dp/A2dpCodecConfig;->mA2dpSourceCodecPriorityAac:I"
                print ""
                print "    const/4 v0, -0x1"
                print "    iput v0, p0, Lcom/android/bluetooth/a2dp/A2dpCodecConfig;->mA2dpSourceCodecPriorityAptx:I"
                print "    iput v0, p0, Lcom/android/bluetooth/a2dp/A2dpCodecConfig;->mA2dpSourceCodecPriorityAptxHd:I"
                print "    iput v0, p0, Lcom/android/bluetooth/a2dp/A2dpCodecConfig;->mA2dpSourceCodecPriorityLdac:I"
                print "    iput v0, p0, Lcom/android/bluetooth/a2dp/A2dpCodecConfig;->mA2dpSourceCodecPriorityOpus:I"
                print "    iput v0, p0, Lcom/android/bluetooth/a2dp/A2dpCodecConfig;->mA2dpSourceCodecPriorityLhdcv5:I"
                print "    iput v0, p0, Lcom/android/bluetooth/a2dp/A2dpCodecConfig;->mA2dpSourceCodecPrioritySsc:I"
                print "    iput v0, p0, Lcom/android/bluetooth/a2dp/A2dpCodecConfig;->mA2dpSourceCodecPrioritySscUhq:I"
                patched = 1
            }
        }
        END { if (!patched) exit 2 }
    ' "$SMALI" > "$SMALI.tmp" && mv "$SMALI.tmp" "$SMALI" || {
        rm -f "$SMALI.tmp"
        ABORT "Failed to patch A2DP legacy codec priorities"
    }

    LOG "- Forced A2DP codec priorities to AAC/SBC and disabled LDAC/SSC/aptX"
}

_PATCH_AUDIO_MUTE_AWAIT_CONNECTION_DUPLICATE()
{
    local SMALI
    local COUNT

    LOG "- Making duplicate Bluetooth mute-await requests non-fatal"
    DECODE_APK "system" "system/framework/services.jar" || ABORT "Failed to decode services.jar"

    SMALI="$APKTOOL_DIR/system/framework/services.jar/smali/com/android/server/audio/AudioService.smali"
    [ -f "$SMALI" ] || ABORT "AudioService.smali not found in decoded services.jar"

    if ! grep -q "muteAwaitConnection already in progress" "$SMALI"; then
        LOG "- AudioService duplicate mute-await branch already patched"
        return 0
    fi

    awk '
        BEGIN {
            inside = 0
            skip_throw_branch = 0
            cleanup_catch = 0
            patched = 0
        }
        /^\.method/ && index($0, "muteAwaitConnection([ILandroid/media/AudioDeviceAttributes;J)V") {
            inside = 1
        }
        inside && index($0, "new-instance p0, Ljava/lang/IllegalStateException;") {
            print "    monitor-exit v1"
            print "    :try_end_1"
            print "    .catchall {:try_start_1 .. :try_end_1} :catchall_0"
            print ""
            print "    return-void"
            print ""
            skip_throw_branch = 1
            patched = 1
            next
        }
        inside && skip_throw_branch {
            if ($0 ~ /^[[:space:]]*:goto_0/) {
                print
                skip_throw_branch = 0
                cleanup_catch = 1
            }
            next
        }
        inside && cleanup_catch && ($0 ~ /^[[:space:]]*:try_end_1$/ || index($0, ".catchall {:try_start_1 .. :try_end_1} :catchall_0")) {
            next
        }
        inside && /^\.end method/ {
            inside = 0
            cleanup_catch = 0
        }
        { print }
        END {
            if (!patched) exit 2
            print patched > "/dev/stderr"
        }
    ' "$SMALI" > "$SMALI.tmp" 2> "$SMALI.count" && mv "$SMALI.tmp" "$SMALI" || {
        rm -f "$SMALI.tmp" "$SMALI.count"
        ABORT "Failed to patch AudioService duplicate mute-await branch"
    }

    COUNT="$(cat "$SMALI.count")"
    rm -f "$SMALI.count"
    LOG "- Patched $COUNT AudioService duplicate mute-await branch"
}

_APEX_PAYLOAD_COPY_OUT()
{
    local PAYLOAD="$1"
    local SRC="$2"
    local DST="$3"

    if command -v e2cp > /dev/null 2>&1; then
        EVAL "e2cp \"$PAYLOAD:$SRC\" \"$DST\""
    elif command -v debugfs > /dev/null 2>&1; then
        EVAL "debugfs -R \"dump -p $SRC $DST\" \"$PAYLOAD\""
    else
        ABORT "Neither e2cp nor debugfs is available to unpack APEX image"
    fi
}

_APEX_PAYLOAD_COPY_IN()
{
    local SRC="$1"
    local PAYLOAD="$2"
    local DST="$3"

    if command -v e2cp > /dev/null 2>&1 && command -v e2rm > /dev/null 2>&1; then
        EVAL "e2rm \"$PAYLOAD:$DST\""
        EVAL "e2cp \"$SRC\" \"$PAYLOAD:$DST\""
    elif command -v debugfs > /dev/null 2>&1; then
        debugfs -w -R "rm $DST" "$PAYLOAD" >/dev/null 2>&1 || true
        EVAL "debugfs -w -R \"write $SRC $DST\" \"$PAYLOAD\""
    else
        ABORT "Neither e2cp/e2rm nor debugfs is available to update APEX image"
    fi
}

_PATCH_BLUETOOTH_APEX_OFFLOAD()
{
    local APEX="$WORK_DIR/system/system/apex/com.android.bt.apex"
    local BT_TMP="$TMP_DIR/com_android_bt_apex"
    local APKTOOL_TMP="$BT_TMP/apktool_tmp"
    local APEX_SRC="$BT_TMP/apex"
    local PAYLOAD="$BT_TMP/apex_payload.img"
    local BT_APK="$BT_TMP/Bluetooth.apk"
    local BT_APK_DECODED="$BT_TMP/Bluetooth.apk.decoded"
    local BT_APK_BUILT="$BT_APK_DECODED/dist/Bluetooth.apk"
    local BT_APK_UNSIGNED="$BT_TMP/Bluetooth-unsigned.apk"
    local BT_APK_PATCHED="$BT_TMP/Bluetooth-patched.apk"
    local FW_JAR="$BT_TMP/framework-bluetooth.jar"
    local FW_JAR_DECODED="$BT_TMP/framework-bluetooth.jar.decoded"
    local FW_JAR_PATCHED="$BT_TMP/framework-bluetooth-patched.jar"
    local CERT_PREFIX="aosp"
    local PARTITION_SIZE
    local MAX_IMAGE_SIZE
    local BLOCK_SIZE
    local BLOCK_COUNT
    local DEFLATE_LIST="$BT_TMP/apex_deflate.list"

    [ -f "$APEX" ] || return 0

    LOG_STEP_IN "- Patching Bluetooth framework inside com.android.bt.apex"

    if $ROM_IS_OFFICIAL && [ -f "$SRC_DIR/security/unica_platform.x509.pem" ]; then
        CERT_PREFIX="unica"
    fi

    rm -rf "$BT_TMP"
    mkdir -p "$APEX_SRC" "$APKTOOL_TMP"

    unzip -q "$APEX" -d "$APEX_SRC"
    cp -f "$APEX_SRC/apex_payload.img" "$PAYLOAD"

    _APEX_PAYLOAD_COPY_OUT "$PAYLOAD" "/app/Bluetooth@CP2A.260605.016/Bluetooth.apk" "$BT_APK"
    _APEX_PAYLOAD_COPY_OUT "$PAYLOAD" "/javalib/framework-bluetooth.jar" "$FW_JAR"

    TMPDIR="$APKTOOL_TMP" JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -Djava.io.tmpdir=$APKTOOL_TMP" \
        "$TOOLS_DIR/bin/apktool" d --no-debug-info -r -j "$(nproc)" -f -o "$BT_APK_DECODED" "$BT_APK" >/dev/null

    _PATCH_CONST_BEFORE_BOOL_IPUT \
        "$BT_APK_DECODED/smali/com/android/bluetooth/a2dp/A2dpService.smali" \
        "Lcom/android/bluetooth/a2dp/A2dpService;->mA2dpOffloadEnabled:Z"
    _PATCH_CONST_BEFORE_BOOL_IPUT \
        "$BT_APK_DECODED/smali/com/android/bluetooth/btservice/AdapterProperties.smali" \
        "Lcom/android/bluetooth/btservice/AdapterProperties;->mA2dpOffloadEnabled:Z"
    _PATCH_BOOL_METHOD_RETURN \
        "$BT_APK_DECODED/smali/com/android/bluetooth/btservice/AdapterProperties.smali" \
        "isA2dpOffloadEnabled()Z" "false"
    _PATCH_A2DP_LEGACY_CODEC_PRIORITIES \
        "$BT_APK_DECODED/smali/com/android/bluetooth/a2dp/A2dpCodecConfig.smali"

    TMPDIR="$APKTOOL_TMP" JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -Djava.io.tmpdir=$APKTOOL_TMP" \
        "$TOOLS_DIR/bin/apktool" b -j "$(nproc)" -srp "$BT_APK_DECODED" >/dev/null

    cp -f "$BT_APK" "$BT_APK_UNSIGNED"
    unzip -p "$BT_APK_BUILT" classes.dex > "$BT_TMP/classes.dex"
    touch -t 200901010000 "$BT_TMP/classes.dex"
    (
        cd "$BT_TMP"
        zip -qd "$BT_APK_UNSIGNED" "META-INF/*" classes.dex >/dev/null
        zip -q -0 -X "$BT_APK_UNSIGNED" classes.dex
    )
    "$TOOLS_DIR/bin/signapk" \
        "$SRC_DIR/security/${CERT_PREFIX}_platform.x509.pem" \
        "$SRC_DIR/security/${CERT_PREFIX}_platform.pk8" \
        "$BT_APK_UNSIGNED" "$BT_APK_PATCHED"

    TMPDIR="$APKTOOL_TMP" JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -Djava.io.tmpdir=$APKTOOL_TMP" \
        "$TOOLS_DIR/bin/apktool" d --no-debug-info -j "$(nproc)" -f -o "$FW_JAR_DECODED" "$FW_JAR" >/dev/null
    _PATCH_BOOL_METHOD_RETURN \
        "$FW_JAR_DECODED/smali/com/android/bluetooth/jarjar/com/android/bluetooth/flags/Flags.smali" \
        "a2dpSinkOffload()Z" "false"
    TMPDIR="$APKTOOL_TMP" JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -Djava.io.tmpdir=$APKTOOL_TMP" \
        "$TOOLS_DIR/bin/apktool" b -j "$(nproc)" -srp "$FW_JAR_DECODED" >/dev/null
    "$TOOLS_DIR/bin/zipalign" -p 4 \
        "$FW_JAR_DECODED/dist/framework-bluetooth.jar" "$FW_JAR_PATCHED"

    _APEX_PAYLOAD_COPY_IN "$BT_APK_PATCHED" "$PAYLOAD" "/app/Bluetooth@CP2A.260605.016/Bluetooth.apk"
    _APEX_PAYLOAD_COPY_IN "$FW_JAR_PATCHED" "$PAYLOAD" "/javalib/framework-bluetooth.jar"

    "$TOOLS_DIR/bin/avbtool" erase_footer --image "$PAYLOAD"
    e2fsck -fy "$PAYLOAD" >/dev/null
    PARTITION_SIZE="$(stat -c '%s' "$APEX_SRC/apex_payload.img")"
    MAX_IMAGE_SIZE="$("$TOOLS_DIR/bin/avbtool" add_hashtree_footer \
        --partition_size "$PARTITION_SIZE" \
        --do_not_generate_fec \
        --algorithm SHA256_RSA4096 \
        --key "$SRC_DIR/security/avb/testkey_rsa4096.pem" \
        --calc_max_image_size)"
    BLOCK_SIZE="$(dumpe2fs -h "$PAYLOAD" 2>/dev/null | awk '/Block size:/ { print $3; exit }')"
    BLOCK_COUNT="$((MAX_IMAGE_SIZE / BLOCK_SIZE))"
    resize2fs "$PAYLOAD" "$BLOCK_COUNT" >/dev/null
    "$TOOLS_DIR/bin/avbtool" add_hashtree_footer \
        --image "$PAYLOAD" \
        --partition_size "$PARTITION_SIZE" \
        --partition_name "" \
        --hash_algorithm sha256 \
        --do_not_generate_fec \
        --algorithm SHA256_RSA4096 \
        --key "$SRC_DIR/security/avb/testkey_rsa4096.pem" \
        --prop apex.key:com.android.bt
    "$TOOLS_DIR/bin/avbtool" extract_public_key \
        --key "$SRC_DIR/security/avb/testkey_rsa4096.pem" \
        --output "$APEX_SRC/apex_pubkey"

    cp -f "$PAYLOAD" "$APEX_SRC/apex_payload.img"
    rm -rf "$APEX_SRC/META-INF"
    (
        cd "$APEX_SRC"
        find . -exec touch -h -t 200901010000 {} +
        zip -q -0 -X "$BT_TMP/com.android.bt-unsigned.apex" \
            apex_payload.img apex_pubkey assets/NOTICE.html.gz resources.arsc
        find . -type f \
            ! -path "./META-INF/*" \
            ! -name "apex_payload.img" \
            ! -name "apex_pubkey" \
            ! -name "NOTICE.html.gz" \
            ! -name "resources.arsc" \
            -printf "%P\n" | sort > "$DEFLATE_LIST"
        zip -q -9 -X "$BT_TMP/com.android.bt-unsigned.apex" -@ < "$DEFLATE_LIST"
    )
    "$TOOLS_DIR/bin/signapk" \
        "$SRC_DIR/security/${CERT_PREFIX}_platform.x509.pem" \
        "$SRC_DIR/security/${CERT_PREFIX}_platform.pk8" \
        "$BT_TMP/com.android.bt-unsigned.apex" "$BT_TMP/com.android.bt.apex"
    unzip -t "$BT_TMP/com.android.bt.apex" >/dev/null
    mv -f "$BT_TMP/com.android.bt.apex" "$APEX"
    rm -rf "$BT_TMP"

    LOG_STEP_OUT
}

_PATCH_BEACONMANAGER_LOCATION_PERMISSIONS()
{
    local BEACON_APK="system/priv-app/BeaconManager/BeaconManager.apk"
    local BEACON_DECODED="$APKTOOL_DIR/system/${BEACON_APK//system\/}"
    local MANIFEST="$BEACON_DECODED/AndroidManifest.xml"
    local PERM

    [ -f "$WORK_DIR/system/$BEACON_APK" ] || return 0

    LOG_STEP_IN "- Adding BeaconManager BLE location permissions"
    DECODE_APK "system" "$BEACON_APK" || ABORT "Failed to decode BeaconManager.apk"

    [ -f "$MANIFEST" ] || ABORT "Decoded BeaconManager manifest not found"

    for PERM in \
        android.permission.ACCESS_COARSE_LOCATION \
        android.permission.ACCESS_FINE_LOCATION \
        android.permission.ACCESS_BACKGROUND_LOCATION; do
        if ! grep -q "android:name=\"$PERM\"" "$MANIFEST"; then
            sed -i "0,/^[[:space:]]*<application/{s#^[[:space:]]*<application#    <uses-permission android:name=\"$PERM\" />\\n\\n    <application#}" "$MANIFEST"
            LOG "- Added $PERM"
        fi
    done

    LOG_STEP_OUT
}

# The legacy Exynos (Chiclet) kernel cannot load the Android 17 mainline BPF
# programs, so netbpfload never sets "bpf.progs_loaded" to 1. Left as shipped,
# the "on load-bpf-programs" action hangs forever on its wait_for_prop, and the
# netd1shot self-test trips its reboot_on_failure -> bootloop. Strip the reboot
# triggers and the blocking wait so the bpf -> netd boot chain degrades
# gracefully; netd still starts and networking works via the kernel's own eBPF.
_SED_DELETE_IF_EXISTS "$WORK_DIR/system/system/etc/init/netbpfload.rc" "/reboot_on_failure[[:space:]][[:space:]]*reboot,netbpfload-missing/d"
_SED_DELETE_IF_EXISTS "$WORK_DIR/system/system/etc/init/netbpfload.rc" "/wait_for_prop[[:space:]][[:space:]]*bpf\.progs_loaded[[:space:]][[:space:]]*1/d"
_SED_DELETE_IF_EXISTS "$WORK_DIR/system/system/etc/init/netd.rc" "/reboot_on_failure[[:space:]][[:space:]]*reboot,netd1shot-fail/d"
_SED_DELETE_IF_EXISTS "$WORK_DIR/system/system/etc/init/vold.rc" "/reboot_on_failure[[:space:]][[:space:]]*reboot,vold-failed/d"

DELETE_FROM_WORK_DIR "system_ext" "priv-app/com.qualcomm.location"
DELETE_FROM_WORK_DIR "system_ext" "etc/permissions/com.qualcomm.location.xml"
DELETE_FROM_WORK_DIR "system_ext" "etc/permissions/privapp-permissions-com.qualcomm.location.xml"
DELETE_FROM_WORK_DIR "system_ext" "bin/perfservice"
DELETE_FROM_WORK_DIR "system_ext" "etc/init/perfservice.rc"
DELETE_FROM_WORK_DIR "system_ext" "etc/seccomp_policy/perfservice.policy"
DELETE_FROM_WORK_DIR "system_ext" "app/QCC"
DELETE_FROM_WORK_DIR "system_ext" "etc/permissions/com.qti.qcc.vendor_qcc.xml"
DELETE_FROM_WORK_DIR "system_ext" "bin/qccsyshal@1.2-service"
DELETE_FROM_WORK_DIR "system_ext" "bin/qccsyshal_aidl-service"
DELETE_FROM_WORK_DIR "system_ext" "etc/init/vendor.qti.hardware.qccsyshal@1.2-service.rc"
DELETE_FROM_WORK_DIR "system_ext" "etc/init/vendor.qti.qccsyshal_aidl-service.rc"
DELETE_FROM_WORK_DIR "system_ext" "etc/vintf/manifest/vendor.qti.qccsyshal_aidl-service.xml"
DELETE_FROM_WORK_DIR "system_ext" "lib64/libqcc.so"
DELETE_FROM_WORK_DIR "system_ext" "lib64/libqcc_file_agent_sys.so"
DELETE_FROM_WORK_DIR "system_ext" "lib64/libqccdme.so"
DELETE_FROM_WORK_DIR "system_ext" "lib64/libqccfileservice.so"

_SED_DELETE_IF_EXISTS "$WORK_DIR/$(GET_SYSTEM_EXT)/etc/sysconfig/qti_whitelist_system_ext.xml" "/com\.qualcomm\.location/d"
_SED_DELETE_IF_EXISTS "$WORK_DIR/system/system/etc/sysconfig/qti_whitelist.xml" "/com\.qualcomm\.location/d"
_SED_DELETE_IF_EXISTS "$WORK_DIR/system/system/etc/deviceidle/reviewed_allowlist.xml" "/com\.qualcomm\.location/d"
_SED_DELETE_IF_EXISTS "$WORK_DIR/system/system/etc/permissions/platform.xml" "/com\.qualcomm\.location/d"

LOG_STEP_IN "- Removing invalid vendor property sets"
_SED_DELETE_IF_EXISTS "$WORK_DIR/vendor/build.prop" "/^\(net\.dns1\|net\.dns2\|persist\.demo\.hdmirotationlock\|ro\.em\.version\|vendor\.hwc\.exynos\.vsync_mode\|ro\.smps\.enable\|security\.securehw\.available\|security\.securenvm\.available\|ro\.apk_verity\.mode\)=/d"
_FOR_EACH_EXYNOS_INIT "/setprop persist\.rmnet\.mux /d"
_FOR_EACH_EXYNOS_INIT "/setprop persist\.rmnet\.data\.enable /d"
_FOR_EACH_EXYNOS_INIT "/setprop persist\.data\.wda\.enable /d"
_FOR_EACH_EXYNOS_INIT "/setprop persist\.data\.df\.agg\.dl_pkt /d"
_FOR_EACH_EXYNOS_INIT "/setprop persist\.data\.df\.agg\.dl_size /d"
_FOR_EACH_EXYNOS_INIT "/setprop ro\.crypto\.fuse_sdcard /d"
_DISABLE_PERFETTO_TRACED
_FIX_STRONGBOX_KEYMASTER_RC
_DISABLE_SURFACEFLINGER_SHADER_CACHE
_DISABLE_UNSUPPORTED_MAINLINE_FEATURES
_DISABLE_UNSUPPORTED_BT_OFFLOAD
_DISABLE_UNSUPPORTED_OUI9_INIT_WRITES
_QUIET_VISIBLE_LOGFOX_NOISE
_PATCH_AUDIO_MUTE_AWAIT_CONNECTION_DUPLICATE
_PATCH_BLUETOOTH_APEX_OFFLOAD
_PATCH_BEACONMANAGER_LOCATION_PERMISSIONS
_DISABLE_STALE_KEYMASTER_WAIT
_PATCH_SENSORHUB_SYSFS_LOG_NOISE
_DROP_MISSING_SENSOR_HAL_BLOBS
LOG_STEP_OUT

ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/etc/selinux/mapping/29.0.cil" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/etc/selinux/mapping/29.0.compat.cil" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/etc/selinux/mapping/30.0.cil" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/etc/selinux/mapping/30.0.compat.cil" 0 0 644 "u:object_r:system_file:s0"

ADD_TO_WORK_DIR "platform/exynos2100/patches/miscs" "vendor" "etc/ueventd.rc" 0 0 644 "u:object_r:vendor_configs_file:s0"
ADD_TO_WORK_DIR "platform/exynos2100/patches/miscs" "vendor" "ueventd.rc" 0 0 644 "u:object_r:vendor_configs_file:s0"
ADD_TO_WORK_DIR "platform/exynos2100/patches/miscs" "vendor" "etc/bluetooth_audio_policy_configuration.xml" 0 0 644 "u:object_r:vendor_configs_file:s0"
ADD_TO_WORK_DIR "platform/exynos2100/patches/miscs" "vendor" "etc/init/android.hardware.sensors@2.0-service-multihal.rc" 0 0 644 "u:object_r:vendor_configs_file:s0"
ADD_TO_WORK_DIR "platform/exynos2100/patches/miscs" "vendor" "bin/monsterrom_wait_sensors_ready.sh" 0 2000 755 "u:object_r:vendor_file:s0"
ADD_TO_WORK_DIR "platform/exynos2100/patches/miscs" "system" "system/etc/default-permissions/default-permissions-com.samsung.android.beaconmanager.xml" 0 0 644 "u:object_r:system_file:s0"

unset -f GET_SYSTEM_EXT _SED_DELETE_IF_EXISTS _FOR_EACH_EXYNOS_INIT _DISABLE_PERFETTO_TRACED _FIX_STRONGBOX_KEYMASTER_RC _DISABLE_STALE_KEYMASTER_WAIT _PATCH_SENSORHUB_SYSFS_LOG_NOISE _DROP_MISSING_SENSOR_HAL_BLOBS _DISABLE_SURFACEFLINGER_SHADER_CACHE _DISABLE_UNSUPPORTED_MAINLINE_FEATURES _DISABLE_UNSUPPORTED_BT_OFFLOAD _DISABLE_UNSUPPORTED_OUI9_INIT_WRITES _SET_LOG_TAG_LEVEL _QUIET_VISIBLE_LOGFOX_NOISE _PATCH_CONST_BEFORE_BOOL_IPUT _PATCH_BOOL_METHOD_RETURN _PATCH_AUDIO_MUTE_AWAIT_CONNECTION_DUPLICATE _PATCH_BLUETOOTH_APEX_OFFLOAD _PATCH_BEACONMANAGER_LOCATION_PERMISSIONS
LOG_STEP_OUT
