#!/usr/bin/env bash
# Copyright (c) 2026
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

TARGET_CODENAME="${1:-t2s}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$SRC_DIR"
source "$SRC_DIR/buildenv.sh" "$TARGET_CODENAME" > /dev/null

MODULE_ID="monsterrom_oneui9_patches"
MODULE_NAME="MonsterROM One UI 9 patches"
MODULE_VERSION="1.0-${ROM_VERSION:-local}"
MODULE_VERSION_CODE="$(date +%Y%m%d)"
MODULE_ROOT="$OUT_DIR/ksunext/$MODULE_ID"
ZIP_PATH="$OUT_DIR/ksunext/${MODULE_ID}_${TARGET_CODENAME}.zip"
MISSING_PAYLOADS=0

copy_payload()
{
    local SRC_REL="$1"
    local DST_REL="$2"
    local SRC="$WORK_DIR/$SRC_REL"
    local DST="$MODULE_ROOT/$DST_REL"

    if [ ! -f "$SRC" ]; then
        echo "Missing payload, skipping: ${SRC//$SRC_DIR\//}" >&2
        MISSING_PAYLOADS=$((MISSING_PAYLOADS + 1))
        return 0
    fi

    mkdir -p "$(dirname "$DST")"
    cp -a "$SRC" "$DST"
}

copy_repo_payload()
{
    local SRC_REL="$1"
    local DST_REL="$2"
    local SRC="$SRC_DIR/$SRC_REL"
    local DST="$MODULE_ROOT/$DST_REL"

    if [ ! -f "$SRC" ]; then
        echo "Missing repo payload, skipping: $SRC_REL" >&2
        MISSING_PAYLOADS=$((MISSING_PAYLOADS + 1))
        return 0
    fi

    mkdir -p "$(dirname "$DST")"
    cp -a "$SRC" "$DST"
}

rm -rf "$MODULE_ROOT"
mkdir -p "$MODULE_ROOT"

cat > "$MODULE_ROOT/module.prop" <<EOF
id=$MODULE_ID
name=$MODULE_NAME
version=$MODULE_VERSION
versionCode=$MODULE_VERSION_CODE
author=Codex
description=Systemless MonsterROM One UI 9 feature patches with KernelSU Next EROFS bind fallback.
EOF

cat > "$MODULE_ROOT/customize.sh" <<'EOF'
ui_print "- Installing MonsterROM One UI 9 patches"
ui_print "- KernelSU Next/EROFS bind fallback is enabled via post-mount.sh"
ui_print "- Runtime repair service is enabled via service.sh"

set_perm_recursive "$MODPATH/system" 0 0 0755 0644 u:object_r:system_file:s0
set_perm_recursive "$MODPATH/vendor" 0 0 0755 0644 u:object_r:vendor_file:s0
set_perm_recursive "$MODPATH/system/lib64" 0 0 0755 0644 u:object_r:system_lib_file:s0
set_perm_recursive "$MODPATH/vendor/etc" 0 0 0755 0644 u:object_r:vendor_configs_file:s0
set_perm_recursive "$MODPATH/vendor/lib64" 0 0 0755 0644 u:object_r:vendor_file:s0
set_perm "$MODPATH/system.prop" 0 0 0644 u:object_r:system_file:s0
set_perm "$MODPATH/sepolicy.rule" 0 0 0644 u:object_r:system_file:s0
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755 u:object_r:system_file:s0
set_perm "$MODPATH/post-mount.sh" 0 0 0755 u:object_r:system_file:s0
set_perm "$MODPATH/service.sh" 0 0 0755 u:object_r:system_file:s0
EOF

cat > "$MODULE_ROOT/system.prop" <<'EOF'
# Newer Samsung Camera app parity flag from the supplied One UI feature set.
ro.camera.default_app_social_media_parity_enabled=true
ro.camera.disableHeicUltraHDR=true
ro.camera.enableCamera1MaxZsl=1
ro.sf.lcd_density=450
ro.sf.init.lcd_density=450
persist.sys.unica.bootsound=true
persist.bluetooth.a2dp_offload.disabled=true
persist.bluetooth.leaudio_offload.disabled=true
persist.vendor.bt.a2dp_offload.disabled=true
persist.vendor.bluetooth.a2dp_offload.disabled=true
ro.bluetooth.leaudio_offload.supported=false
persist.bluetooth.samsung.a2dp_offload.cap=
persist.bluetooth.samsung.a2dp.cap=SBC,AAC
persist.bluetooth.samsung.leaudio.livecast=false
media.stagefright.enable-fma2dp=false
ro.bluetooth.library_name=
bluetooth.a2dp.source.sbc_priority.config=1001
bluetooth.a2dp.source.aac_priority.config=900000
bluetooth.a2dp.source.aptx_priority.config=-1
bluetooth.a2dp.source.aptx_hd_priority.config=-1
bluetooth.a2dp.source.ldac_priority.config=-1
bluetooth.a2dp.source.opus_priority.config=-1
bluetooth.a2dp.source.lhdcv5_priority.config=-1
audio.offload.disable=1
audio.offload.video=false
audio.deep_buffer.media=false
tunnel.audio.encode=false
media.stagefright.audio.deep=false
ro.logd.kernel=false
debug.sf.show_refresh_rate_overlay_render_rate=false
persist.debug.wfd.enable=0
nfc.nxp_log_level_global=0
persist.vendor.nfc.log.index=0
persist.log.level=0xFFFFFFFF
persist.log.semlevel=0xFFFFFF00
log.tag=E
persist.log.tag=E
log.tag.SurfaceFlinger=F
persist.log.tag.SurfaceFlinger=F
log.tag.WifiDisplayAdapter=W
persist.log.tag.WifiDisplayAdapter=W
log.tag.WifiDisplayController=W
persist.log.tag.WifiDisplayController=W
log.tag.DisplayManagerService=W
persist.log.tag.DisplayManagerService=W
log.tag.NxpGenExtn=F
persist.log.tag.NxpGenExtn=F
log.tag.RILJ=F
persist.log.tag.RILJ=F
log.tag.SEM_RILJ=F
persist.log.tag.SEM_RILJ=F
log.tag.RILD=F
persist.log.tag.RILD=F
log.tag.RILD2=F
persist.log.tag.RILD2=F
log.tag.Multi-Client=F
persist.log.tag.Multi-Client=F
log.tag.Multi-Client2=F
persist.log.tag.Multi-Client2=F
log.tag.BSOHChargingDataCollector=W
persist.log.tag.BSOHChargingDataCollector=W
log.tag.PackageConfigPersister=E
persist.log.tag.PackageConfigPersister=E
log.tag.GlassesApi=F
persist.log.tag.GlassesApi=F
log.tag.cnka=F
persist.log.tag.cnka=F
log.tag.LockPatternUtils=E
persist.log.tag.LockPatternUtils=E
log.tag.usb_notify=W
persist.log.tag.usb_notify=W
log.tag.APM_AudioPolicyManager=E
persist.log.tag.APM_AudioPolicyManager=E
log.tag.vendor.samsung.bluetooth.audio.BTAudioProvider=W
persist.log.tag.vendor.samsung.bluetooth.audio.BTAudioProvider=W
log.tag.BatteryService_BatteryPropertiesRegistrar=W
persist.log.tag.BatteryService_BatteryPropertiesRegistrar=W
log.tag.SemWifiIntelligentTrainingManager=W
persist.log.tag.SemWifiIntelligentTrainingManager=W
log.tag.Settings=E
persist.log.tag.Settings=E
log.tag.PackageManager=E
persist.log.tag.PackageManager=E
log.tag.Binder=E
persist.log.tag.Binder=E
log.tag.SemWallpaperColorsArea=E
persist.log.tag.SemWallpaperColorsArea=E
log.tag.SmartFaceManager=F
persist.log.tag.SmartFaceManager=F
log.tag.SmartFaceService=F
persist.log.tag.SmartFaceService=F
log.tag.SmartFaceServiceStarter=F
persist.log.tag.SmartFaceServiceStarter=F
log.tag.ExynosCameraNode=E
persist.log.tag.ExynosCameraNode=E
log.tag.CameraDeviceClient=E
persist.log.tag.CameraDeviceClient=E
log.tag.CAE=E
persist.log.tag.CAE=E
log.tag.Sensors=F
persist.log.tag.Sensors=F
log.tag.SensorService=F
persist.log.tag.SensorService=F
log.tag.SemContext.CaeProvider=F
persist.log.tag.SemContext.CaeProvider=F
log.tag.LocalDisplayAdapter=E
persist.log.tag.LocalDisplayAdapter=E
log.tag.display=F
persist.log.tag.display=F
log.tag.ShellTransitions=F
persist.log.tag.ShellTransitions=F
log.tag.NativeCustomFrequencyManager=F
persist.log.tag.NativeCustomFrequencyManager=F
log.tag.AODManagerService=F
persist.log.tag.AODManagerService=F
log.tag.libprocessgroup=E
persist.log.tag.libprocessgroup=E
log.tag.DeviceStorageMonitorService=E
persist.log.tag.DeviceStorageMonitorService=E
log.tag.AccountTypeLoader=E
persist.log.tag.AccountTypeLoader=E
log.tag.System=E
persist.log.tag.System=E
log.tag.keymaster_tee=E
persist.log.tag.keymaster_tee=E
log.tag.ConnectivityService=W
persist.log.tag.ConnectivityService=W
log.tag.ConnectivityManager=W
persist.log.tag.ConnectivityManager=W
log.tag.BLASTSyncEngine=E
persist.log.tag.BLASTSyncEngine=E
log.tag.bt_btm_pm=E
persist.log.tag.bt_btm_pm=E
log.tag.bluetooth=E
persist.log.tag.bluetooth=E
log.tag.ProcessStats=E
persist.log.tag.ProcessStats=E
log.tag.Netd=E
persist.log.tag.Netd=E
log.tag.AlarmManager=E
persist.log.tag.AlarmManager=E
log.tag.id.app.launcher=E
persist.log.tag.id.app.launcher=E
log.tag.Watchdog=F
persist.log.tag.Watchdog=F
log.tag.DBManager=F
persist.log.tag.DBManager=F
log.tag.AbsSettings=F
persist.log.tag.AbsSettings=F
log.tag.WallpaperResourcesInfo=E
persist.log.tag.WallpaperResourcesInfo=E
log.tag.getBitmap=F
persist.log.tag.getBitmap=F
log.tag.FuseDaemon=F
persist.log.tag.FuseDaemon=F
log.tag.ActivityManager=F
persist.log.tag.ActivityManager=F
log.tag.roid.themestore=F
persist.log.tag.roid.themestore=F
log.tag.ThemeCenter_ThemeManagerService=F
persist.log.tag.ThemeCenter_ThemeManagerService=F
log.tag.PermissionService=E
persist.log.tag.PermissionService=E
log.tag.AdvertisingIdSettings=E
persist.log.tag.AdvertisingIdSettings=E
log.tag.AODSettingsHelper=F
persist.log.tag.AODSettingsHelper=F
log.tag.Kumiho-Kumiho=E
persist.log.tag.Kumiho-Kumiho=E
log.tag.NearbyMediums=E
persist.log.tag.NearbyMediums=E
log.tag.NearbyConnections=E
persist.log.tag.NearbyConnections=E
log.tag.NearbySharing=E
persist.log.tag.NearbySharing=E
log.tag.NearbyDiscovery=E
persist.log.tag.NearbyDiscovery=E
log.tag.BtGatt.AdvertiseManager=E
persist.log.tag.BtGatt.AdvertiseManager=E
log.tag.BluetoothMetrics=E
persist.log.tag.BluetoothMetrics=E
log.tag.rfcomm_port_utils=E
persist.log.tag.rfcomm_port_utils=E
log.tag.AppOpService=F
persist.log.tag.AppOpService=F
log.tag.AppOps=F
persist.log.tag.AppOps=F
log.tag.PlayIntegrityHooks=F
persist.log.tag.PlayIntegrityHooks=F
log.tag.QueryBuilder=F
persist.log.tag.QueryBuilder=F
log.tag.RemoteWorkerFactory=E
persist.log.tag.RemoteWorkerFactory=E
log.tag.JobInfo=E
persist.log.tag.JobInfo=E
log.tag.MetadataRetrieverClient=F
persist.log.tag.MetadataRetrieverClient=F
log.tag.CMHProvider=F
persist.log.tag.CMHProvider=F
log.tag.SatelliteController=F
persist.log.tag.SatelliteController=F
log.tag.CmcServiceHelper=F
persist.log.tag.CmcServiceHelper=F
log.tag.ImsUri=F
persist.log.tag.ImsUri=F
log.tag.SecImsServiceConnector=F
persist.log.tag.SecImsServiceConnector=F
log.tag.ContextImpl=E
persist.log.tag.ContextImpl=E
log.tag.NSLocationMonitor=E
persist.log.tag.NSLocationMonitor=E
log.tag.NetworkManager_FLP=E
persist.log.tag.NetworkManager_FLP=E
log.tag.resolv=E
persist.log.tag.resolv=E
log.tag.View=E
persist.log.tag.View=E
log.tag.KeyguardSecurityViewFlipper=E
persist.log.tag.KeyguardSecurityViewFlipper=E
log.tag.CCTFlatFileLogStore=E
persist.log.tag.CCTFlatFileLogStore=E
log.tag.SQLiteLog=F
persist.log.tag.SQLiteLog=F
log.tag.SQLiteCursor=F
persist.log.tag.SQLiteCursor=F
log.tag.SensorsGrip=F
persist.log.tag.SensorsGrip=F
log.tag.SSS@search=F
persist.log.tag.SSS@search=F
log.tag.SemSupplicantStaIfaceHalHidlImpl=F
persist.log.tag.SemSupplicantStaIfaceHalHidlImpl=F
log.tag.power=F
persist.log.tag.power=F
log.tag.WM-WorkerWrapper=F
persist.log.tag.WM-WorkerWrapper=F
log.tag.MediaContentSyncTask=F
persist.log.tag.MediaContentSyncTask=F
log.tag.ControllerEventHandler=F
persist.log.tag.ControllerEventHandler=F
log.tag.FileSyncManager=F
persist.log.tag.FileSyncManager=F
log.tag.WorkerUtils=F
persist.log.tag.WorkerUtils=F
log.tag.UnifiedCropper=F
persist.log.tag.UnifiedCropper=F
log.tag.ArcSoft_C=F
persist.log.tag.ArcSoft_C=F
log.tag.tflite=F
persist.log.tag.tflite=F
log.tag.kcgz=F
persist.log.tag.kcgz=F
log.tag.SemanticLocation=E
persist.log.tag.SemanticLocation=E
log.tag.SLocation=E
persist.log.tag.SLocation=E
log.tag.RequestManager_FLP=F
persist.log.tag.RequestManager_FLP=F
log.tag.wificond=E
persist.log.tag.wificond=E
log.tag.IE_Capabilities=E
persist.log.tag.IE_Capabilities=E
log.tag.SemThroughputPredictor=F
persist.log.tag.SemThroughputPredictor=F
log.tag.DIAGMON_SDK=F
persist.log.tag.DIAGMON_SDK=F
log.tag.SystemServiceRegistry=F
persist.log.tag.SystemServiceRegistry=F
log.tag.PersonalSafety=E
persist.log.tag.PersonalSafety=E
log.tag.TelephonyCallback=E
persist.log.tag.TelephonyCallback=E
log.tag.SemBatteryUsageStatsProvider=E
persist.log.tag.SemBatteryUsageStatsProvider=E
log.tag.Finsky=E
persist.log.tag.Finsky=E
log.tag.ActivityThread=E
persist.log.tag.ActivityThread=E
log.tag.GAEEngine=E
persist.log.tag.GAEEngine=E
log.tag.SyncManager=E
persist.log.tag.SyncManager=E
log.tag.Controller=F
persist.log.tag.Controller=F
log.tag.SDMConfig=E
persist.log.tag.SDMConfig=E
log.tag.qr_barcode_decoder=F
persist.log.tag.qr_barcode_decoder=F
log.tag.GmsTaskScheduler=F
persist.log.tag.GmsTaskScheduler=F
log.tag.Moneta=F
persist.log.tag.Moneta=F
log.tag.DataMlSdk=F
persist.log.tag.DataMlSdk=F
log.tag.NowBarCardViewModel=F
persist.log.tag.NowBarCardViewModel=F
log.tag.SEMS=F
persist.log.tag.SEMS=F
log.tag.RILClient=F
persist.log.tag.RILClient=F
log.tag.GsmCdmaPhone=F
persist.log.tag.GsmCdmaPhone=F
log.tag.GoogleApiManager=F
persist.log.tag.GoogleApiManager=F
log.tag.kbit=F
persist.log.tag.kbit=F
log.tag.LockWidgetData=F
persist.log.tag.LockWidgetData=F
log.tag.LockCalendarHelper=F
persist.log.tag.LockCalendarHelper=F
log.tag.SafetyCenterManagerWrap=F
persist.log.tag.SafetyCenterManagerWrap=F
log.tag.TNP=F
persist.log.tag.TNP=F
log.tag.CalendarSyncAdapter=F
persist.log.tag.CalendarSyncAdapter=F
log.tag.RILC=F
persist.log.tag.RILC=F
log.tag.rild=F
persist.log.tag.rild=F
log.tag.DNC-0=F
persist.log.tag.DNC-0=F
log.tag.DNC-1=F
persist.log.tag.DNC-1=F
log.tag.NetworkTypeController=F
persist.log.tag.NetworkTypeController=F
log.tag.SemGsmCdmaPhone=F
persist.log.tag.SemGsmCdmaPhone=F
log.tag.TelephonyAnalyticsSubId=F
persist.log.tag.TelephonyAnalyticsSubId=F
log.tag.NowBrief.LLMPolicy=F
persist.log.tag.NowBrief.LLMPolicy=F
log.tag.ConfigUpdater=F
persist.log.tag.ConfigUpdater=F
log.tag.AppIconSolution=F
persist.log.tag.AppIconSolution=F
log.tag.FSA2_SyncUpPhotoCursor=F
persist.log.tag.FSA2_SyncUpPhotoCursor=F
log.tag.engmode_client_aidl=F
persist.log.tag.engmode_client_aidl=F
log.tag.SLocation=F
persist.log.tag.SLocation=F
log.tag.SDHMS=F
persist.log.tag.SDHMS=F
log.tag.BluetoothCastAdapterService=F
persist.log.tag.BluetoothCastAdapterService=F
log.tag.BluetoothRemoteDevices=F
persist.log.tag.BluetoothRemoteDevices=F
log.tag.BluetoothAdapterService=F
persist.log.tag.BluetoothAdapterService=F
log.tag.CachedBluetoothDevice=F
persist.log.tag.CachedBluetoothDevice=F
log.tag.BTAudioHalDeviceProxy=F
persist.log.tag.BTAudioHalDeviceProxy=F
log.tag.BTAudioHalStream=F
persist.log.tag.BTAudioHalStream=F
log.tag.BTAudioA2dpHIDL=F
persist.log.tag.BTAudioA2dpHIDL=F
log.tag.BTAudioClientHIDL=F
persist.log.tag.BTAudioClientHIDL=F
log.tag.A2dpService=F
persist.log.tag.A2dpService=F
log.tag.BluetoothActiveDeviceManager=F
persist.log.tag.BluetoothActiveDeviceManager=F
log.tag.bt_btif_storage=F
persist.log.tag.bt_btif_storage=F
log.tag.bt_btu_hcif=F
persist.log.tag.bt_btu_hcif=F
log.tag.bluetooth-a2dp=F
persist.log.tag.bluetooth-a2dp=F
log.tag.BUPlugin_BudsLogManager=F
persist.log.tag.BUPlugin_BudsLogManager=F
log.tag.DlbSpatializerEffectContext=F
persist.log.tag.DlbSpatializerEffectContext=F
log.tag.AS.AudioDeviceInventory=F
persist.log.tag.AS.AudioDeviceInventory=F
log.tag.AS.AudioService=F
persist.log.tag.AS.AudioService=F
log.tag.AS.SpatializerHelper=F
persist.log.tag.AS.SpatializerHelper=F
log.tag.BluetoothBDTestService=F
persist.log.tag.BluetoothBDTestService=F
log.tag.BluetoothUtils=F
persist.log.tag.BluetoothUtils=F
log.tag.mAFPC_ABC=F
persist.log.tag.mAFPC_ABC=F
log.tag.NotificationService=F
persist.log.tag.NotificationService=F
log.tag.LpaConnector=F
persist.log.tag.LpaConnector=F
log.tag.CustomCpuInfoReader=F
persist.log.tag.CustomCpuInfoReader=F
log.tag.DigitalHorizontalClockView_LOCK_SCREEN_2@218=F
persist.log.tag.DigitalHorizontalClockView_LOCK_SCREEN_2@218=F
log.tag.DigitalHorizontalClockView_LOCK_SCREEN_2@115=F
persist.log.tag.DigitalHorizontalClockView_LOCK_SCREEN_2@115=F
log.tag.ClockBlurManager@355_parent@218=F
persist.log.tag.ClockBlurManager@355_parent@218=F
log.tag.SecVibrator-HAL-AIDL-CORE=F
persist.log.tag.SecVibrator-HAL-AIDL-CORE=F
log.tag.SecVibrator-HAL-AIDL-EXT=F
persist.log.tag.SecVibrator-HAL-AIDL-EXT=F
log.tag.pageboostd=F
persist.log.tag.pageboostd=F
log.tag.KeyguardFingerPrintSwipe=F
persist.log.tag.KeyguardFingerPrintSwipe=F
log.tag.WorkSourceUtil=F
persist.log.tag.WorkSourceUtil=F
log.tag.AOD_CONFIG@AODConfigurationController=F
persist.log.tag.AOD_CONFIG@AODConfigurationController=F
log.tag.HoneySpace.ReflectionUtils=F
persist.log.tag.HoneySpace.ReflectionUtils=F
log.tag.HoneySpace.OnBoardingUtil=F
persist.log.tag.HoneySpace.OnBoardingUtil=F
log.tag.SettingsToPropertiesMapper=F
persist.log.tag.SettingsToPropertiesMapper=F
log.tag.AutofillManagerServiceImpl=F
persist.log.tag.AutofillManagerServiceImpl=F
log.tag.GuestManager=F
persist.log.tag.GuestManager=F
log.tag.PocketModeEvent=F
persist.log.tag.PocketModeEvent=F
log.tag.PocketMotionManager=F
persist.log.tag.PocketMotionManager=F
log.tag.AutomaticBrightnessController=F
persist.log.tag.AutomaticBrightnessController=F
log.tag.DreamController=F
persist.log.tag.DreamController=F
log.tag.LSO_LSOInterface=F
persist.log.tag.LSO_LSOInterface=F
log.tag.NotifRow=F
persist.log.tag.NotifRow=F
log.tag.MODManager=F
persist.log.tag.MODManager=F
log.tag.bauth_FPQCBAuthSensorControl=F
persist.log.tag.bauth_FPQCBAuthSensorControl=F
log.tag.FaceServiceStorage=F
persist.log.tag.FaceServiceStorage=F
log.tag.BiometricScheduler=F
persist.log.tag.BiometricScheduler=F
log.tag.MotionRecognitionService=F
persist.log.tag.MotionRecognitionService=F
log.tag.WifiGuiderService=F
persist.log.tag.WifiGuiderService=F
log.tag.TransitionChain=F
persist.log.tag.TransitionChain=F
log.tag.ConsumerBase=F
persist.log.tag.ConsumerBase=F
log.tag.SemWifiApSmartBleScanner=F
persist.log.tag.SemWifiApSmartBleScanner=F
log.tag.CameraService_worker=F
persist.log.tag.CameraService_worker=F
log.tag.cameraserver=F
persist.log.tag.cameraserver=F
log.tag.ExynosCameraInterface=F
persist.log.tag.ExynosCameraInterface=F
log.tag.ExynosCameraMetadataConverterVendor=F
persist.log.tag.ExynosCameraMetadataConverterVendor=F
log.tag.SveCamera=F
persist.log.tag.SveCamera=F
log.tag.LockGuard=F
persist.log.tag.LockGuard=F
log.tag.GameTools=F
persist.log.tag.GameTools=F
log.tag.GoogleSettingsUtils=F
persist.log.tag.GoogleSettingsUtils=F
log.tag.MediaProvider=F
persist.log.tag.MediaProvider=F
log.tag.SatelliteModemInterface=F
persist.log.tag.SatelliteModemInterface=F
log.tag.AppSearchIcing=F
persist.log.tag.AppSearchIcing=F
log.tag.BRListParser=F
persist.log.tag.BRListParser=F
log.tag.PdeNotificationListenerService=F
persist.log.tag.PdeNotificationListenerService=F
log.tag.MemoryLeakHandler=F
persist.log.tag.MemoryLeakHandler=F
EOF

cat > "$MODULE_ROOT/sepolicy.rule" <<'EOF'
allow platform_app_36 SemInputDeviceManager_service service_manager find
allow platform_app_36 system_prop property_service set
allow keystore Hermes_service service_manager find
EOF

cat > "$MODULE_ROOT/post-fs-data.sh" <<'EOF'
#!/system/bin/sh

resetprop_cmd()
{
    if [ -x /data/adb/ksud ]; then
        /data/adb/ksud resetprop "$@" >/dev/null 2>&1
    elif command -v resetprop >/dev/null 2>&1; then
        resetprop "$@" >/dev/null 2>&1
    else
        return 1
    fi
}

set_log_tag()
{
    resetprop_cmd "log.tag.$1" "$2"
    resetprop_cmd -p "persist.log.tag.$1" "$2"
}

quiet_visible_log_noise()
{
    resetprop_cmd ro.logd.kernel false
    resetprop_cmd debug.sf.show_refresh_rate_overlay_render_rate false
    resetprop_cmd -p persist.debug.wfd.enable 0
    resetprop_cmd nfc.nxp_log_level_global 0
    resetprop_cmd -p persist.vendor.nfc.log.index 0
    resetprop_cmd -p persist.log.level 0xFFFFFFFF
    resetprop_cmd -p persist.log.semlevel 0xFFFFFF00
    resetprop_cmd log.tag E
    resetprop_cmd -p persist.log.tag E

    set_log_tag SurfaceFlinger F
    set_log_tag WifiDisplayAdapter W
    set_log_tag WifiDisplayController W
    set_log_tag DisplayManagerService W
    set_log_tag NxpGenExtn F
    set_log_tag RILJ F
    set_log_tag SEM_RILJ F
    set_log_tag RILD F
    set_log_tag RILD2 F
    set_log_tag Multi-Client F
    set_log_tag Multi-Client2 F
    set_log_tag BSOHChargingDataCollector W
    set_log_tag PackageConfigPersister E
    set_log_tag GlassesApi F
    set_log_tag cnka F
    set_log_tag LockPatternUtils E
    set_log_tag usb_notify W
    set_log_tag APM_AudioPolicyManager E
    set_log_tag vendor.samsung.bluetooth.audio.BTAudioProvider W
    set_log_tag BatteryService_BatteryPropertiesRegistrar W
    set_log_tag SemWifiIntelligentTrainingManager W
    set_log_tag Settings E
    set_log_tag PackageManager E
    set_log_tag Binder E
    set_log_tag SemWallpaperColorsArea E
    set_log_tag SmartFaceManager F
    set_log_tag SmartFaceService F
    set_log_tag SmartFaceServiceStarter F
    set_log_tag ExynosCameraNode E
    set_log_tag CameraDeviceClient E
    set_log_tag CAE E
    set_log_tag Sensors F
    set_log_tag SensorService F
    set_log_tag SemContext.CaeProvider F
    set_log_tag LocalDisplayAdapter E
    set_log_tag display F
    set_log_tag ShellTransitions F
    set_log_tag NativeCustomFrequencyManager F
    set_log_tag AODManagerService F
    set_log_tag libprocessgroup E
    set_log_tag DeviceStorageMonitorService E
    set_log_tag AccountTypeLoader E
    set_log_tag System E
    set_log_tag keymaster_tee E
    set_log_tag ConnectivityService W
    set_log_tag ConnectivityManager W
    set_log_tag BLASTSyncEngine E
    set_log_tag bt_btm_pm E
    set_log_tag bluetooth E
    set_log_tag ProcessStats E
    set_log_tag Netd E
    set_log_tag AlarmManager E
    set_log_tag id.app.launcher E
    set_log_tag Watchdog F
    set_log_tag DBManager F
    set_log_tag AbsSettings F
    set_log_tag WallpaperResourcesInfo E
    set_log_tag getBitmap F
    set_log_tag FuseDaemon F
    set_log_tag ActivityManager F
    set_log_tag roid.themestore F
    set_log_tag ThemeCenter_ThemeManagerService F
    set_log_tag PermissionService E
    set_log_tag AdvertisingIdSettings E
    set_log_tag AODSettingsHelper F
    set_log_tag Kumiho-Kumiho E
    set_log_tag NearbyMediums E
    set_log_tag NearbyConnections E
    set_log_tag NearbySharing E
    set_log_tag NearbyDiscovery E
    set_log_tag BtGatt.AdvertiseManager E
    set_log_tag BluetoothMetrics E
    set_log_tag rfcomm_port_utils E
    set_log_tag AppOpService F
    set_log_tag AppOps F
    set_log_tag PlayIntegrityHooks F
    set_log_tag QueryBuilder F
    set_log_tag RemoteWorkerFactory E
    set_log_tag JobInfo E
    set_log_tag MetadataRetrieverClient F
    set_log_tag CMHProvider F
    set_log_tag SatelliteController F
    set_log_tag CmcServiceHelper F
    set_log_tag ImsUri F
    set_log_tag SecImsServiceConnector F
    set_log_tag ContextImpl E
    set_log_tag NSLocationMonitor E
    set_log_tag NetworkManager_FLP E
    set_log_tag resolv E
    set_log_tag View E
    set_log_tag KeyguardSecurityViewFlipper E
    set_log_tag CCTFlatFileLogStore E
    set_log_tag SQLiteLog F
    set_log_tag SQLiteCursor F
    set_log_tag SensorsGrip F
    set_log_tag SSS@search F
    set_log_tag SemSupplicantStaIfaceHalHidlImpl F
    set_log_tag power F
    set_log_tag WM-WorkerWrapper F
    set_log_tag MediaContentSyncTask F
    set_log_tag ControllerEventHandler F
    set_log_tag FileSyncManager F
    set_log_tag WorkerUtils F
    set_log_tag UnifiedCropper F
    set_log_tag ArcSoft_C F
    set_log_tag tflite F
    set_log_tag kcgz F
    set_log_tag SemanticLocation E
    set_log_tag SLocation E
    set_log_tag RequestManager_FLP F
    set_log_tag wificond E
    set_log_tag IE_Capabilities E
    set_log_tag SemThroughputPredictor F
    set_log_tag DIAGMON_SDK F
    set_log_tag SystemServiceRegistry F
    set_log_tag PersonalSafety E
    set_log_tag TelephonyCallback E
    set_log_tag SemBatteryUsageStatsProvider E
    set_log_tag Finsky E
    set_log_tag ActivityThread E
    set_log_tag GAEEngine E
    set_log_tag SyncManager E
    set_log_tag Controller F
    set_log_tag SDMConfig E
    set_log_tag qr_barcode_decoder F
    set_log_tag GmsTaskScheduler F
    for TAG in \
        Moneta DataMlSdk NowBarCardViewModel SEMS RILClient GsmCdmaPhone \
        GoogleApiManager kbit LockWidgetData LockCalendarHelper \
        SafetyCenterManagerWrap TNP CalendarSyncAdapter RILC rild DNC-0 DNC-1 \
        NetworkTypeController SemGsmCdmaPhone TelephonyAnalyticsSubId \
        NowBrief.LLMPolicy ConfigUpdater AppIconSolution FSA2_SyncUpPhotoCursor \
        engmode_client_aidl SLocation SDHMS BluetoothCastAdapterService \
        BluetoothRemoteDevices BluetoothAdapterService CachedBluetoothDevice \
        BTAudioHalDeviceProxy BTAudioHalStream BTAudioA2dpHIDL \
        BTAudioClientHIDL A2dpService BluetoothActiveDeviceManager \
        bt_btif_storage bt_btu_hcif bluetooth-a2dp BUPlugin_BudsLogManager \
        DlbSpatializerEffectContext AS.AudioDeviceInventory AS.AudioService \
        AS.SpatializerHelper BluetoothBDTestService BluetoothUtils SemWifiApSmartBleScanner \
        CameraService_worker cameraserver ExynosCameraInterface \
        ExynosCameraMetadataConverterVendor SveCamera LockGuard GameTools \
        GoogleSettingsUtils MediaProvider SatelliteModemInterface AppSearchIcing \
        BRListParser PdeNotificationListenerService MemoryLeakHandler \
        mAFPC_ABC NotificationService LpaConnector CustomCpuInfoReader \
        DigitalHorizontalClockView_LOCK_SCREEN_2@218 \
        DigitalHorizontalClockView_LOCK_SCREEN_2@115 \
        ClockBlurManager@355_parent@218 SecVibrator-HAL-AIDL-CORE \
        SecVibrator-HAL-AIDL-EXT pageboostd KeyguardFingerPrintSwipe \
        WorkSourceUtil AOD_CONFIG@AODConfigurationController \
        HoneySpace.ReflectionUtils HoneySpace.OnBoardingUtil \
        SettingsToPropertiesMapper AutofillManagerServiceImpl GuestManager \
        PocketModeEvent PocketMotionManager AutomaticBrightnessController \
        DreamController LSO_LSOInterface NotifRow MODManager \
        bauth_FPQCBAuthSensorControl FaceServiceStorage BiometricScheduler \
        MotionRecognitionService WifiGuiderService TransitionChain ConsumerBase; do
        set_log_tag "$TAG" F
    done
}

resetprop_cmd -p persist.sys.unica.bootsound true
resetprop_cmd -p persist.bluetooth.a2dp_offload.disabled true
resetprop_cmd -p persist.bluetooth.leaudio_offload.disabled true
resetprop_cmd -p persist.vendor.bt.a2dp_offload.disabled true
resetprop_cmd -p persist.vendor.bluetooth.a2dp_offload.disabled true
resetprop_cmd ro.bluetooth.leaudio_offload.supported false
resetprop_cmd -d persist.bluetooth.samsung.a2dp_offload.cap \
    || resetprop_cmd -p persist.bluetooth.samsung.a2dp_offload.cap ""
resetprop_cmd -p persist.bluetooth.samsung.a2dp.cap SBC,AAC
resetprop_cmd -p persist.bluetooth.samsung.leaudio.livecast false
resetprop_cmd media.stagefright.enable-fma2dp false
resetprop_cmd -d ro.bluetooth.library_name \
    || resetprop_cmd -n ro.bluetooth.library_name ""
resetprop_cmd bluetooth.a2dp.source.sbc_priority.config 1001
resetprop_cmd bluetooth.a2dp.source.aac_priority.config 900000
resetprop_cmd bluetooth.a2dp.source.aptx_priority.config -1
resetprop_cmd bluetooth.a2dp.source.aptx_hd_priority.config -1
resetprop_cmd bluetooth.a2dp.source.ldac_priority.config -1
resetprop_cmd bluetooth.a2dp.source.opus_priority.config -1
resetprop_cmd bluetooth.a2dp.source.lhdcv5_priority.config -1
resetprop_cmd audio.offload.disable 1
resetprop_cmd audio.offload.video false
resetprop_cmd audio.deep_buffer.media false
resetprop_cmd tunnel.audio.encode false
resetprop_cmd media.stagefright.audio.deep false
quiet_visible_log_noise
EOF

cat > "$MODULE_ROOT/post-mount.sh" <<'EOF'
#!/system/bin/sh

MODDIR=${0%/*}
BUSYBOX=/data/adb/ksu/bin/busybox
[ -x "$BUSYBOX" ] || BUSYBOX=/data/adb/magisk/busybox
[ -x "$BUSYBOX" ] || BUSYBOX=busybox

log_msg()
{
    echo "monsterrom_oneui9_patches: $*" > /dev/kmsg 2>/dev/null || true
}

fix_sensor_permissions()
{
    local NODE

    for NODE in \
        /sys/class/lcd/panel/smooth_dim \
        /sys/class/lcd/panel/screen_mode \
        /sys/class/lcd/panel/vrr_lfd \
        /sys/class/power_supply/battery/batt_after_manufactured \
        /sys/class/usb_notify/usb_control/usb_hw_param; do
        [ -e "$NODE" ] || continue
        chown system:system "$NODE" 2>/dev/null || true
        chmod 0664 "$NODE" 2>/dev/null || true
    done

    for NODE in /sys/class/sec/switch/afc_disable; do
        [ -e "$NODE" ] || continue
        chown system:radio "$NODE" 2>/dev/null || true
        chmod 0664 "$NODE" 2>/dev/null || true
    done

    for NODE in /sys/bbd/lk_enable; do
        [ -e "$NODE" ] || continue
        chown gps:system "$NODE" 2>/dev/null || true
        chmod 0664 "$NODE" 2>/dev/null || true
    done

    for NODE in \
        /sys/class/sensors/grip_sensor/onoff \
        /sys/class/sensors/grip_sensor/motion \
        /sys/class/sensors/grip_sensor/unknown_state \
        /sys/class/sensors/ssp_sensor/data_injection_enable \
        /sys/class/sensors/ssp_sensor/enable \
        /sys/class/sensors/ssp_sensor/enable_irq \
        /sys/class/sensors/ssp_sensor/mcu_sleep_test \
        /sys/class/sensors/ssp_sensor/mcu_test \
        /sys/class/sensors/ssp_sensor/sensor_dump \
        /sys/class/sensors/ssp_sensor/ssp_control; do
        [ -e "$NODE" ] || continue
        chown system:radio "$NODE" 2>/dev/null || true
        chmod 0664 "$NODE" 2>/dev/null || true
    done

    for NODE in \
        /sys/devices/virtual/sensor_event/symlink/grip_sensor/enable \
        /sys/devices/virtual/sensor_event/symlink/grip_notifier/enable2; do
        [ -e "$NODE" ] || continue
        chown system:radio "$NODE" 2>/dev/null || true
        chmod 0664 "$NODE" 2>/dev/null || true
    done

    if [ ! -e /sys/class/sensors/hidden_hole ] \
        && [ ! -e /sys/devices/virtual/sensor_event/symlink/hidden_hole ]; then
        log_msg "hidden_hole sysfs node absent; real sensor tree left unmasked"
    fi

    for NODE in \
        /sys/class/sensors/ssp_sensor/ssp_flush \
        /sys/class/sensors/sensor_dev/flush; do
        [ -e "$NODE" ] || continue
        chown system:radio "$NODE" 2>/dev/null || true
        chmod 0220 "$NODE" 2>/dev/null || true
    done

    for NODE in /sys/bus/iio/devices/iio:device*/poll_delay \
        /sys/bus/iio/devices/iio:device*/buffer/enable \
        /sys/bus/iio/devices/iio:device*/buffer/length; do
        [ -e "$NODE" ] || continue
        chown system:system "$NODE" 2>/dev/null || true
        chmod 0660 "$NODE" 2>/dev/null || true
    done
}

mount_hidden_hole_sensor_overlay()
{
    local BASE="/dev/monsterrom_oneui9_patches_hidden_hole"
    local VIEW="$BASE/sensors"
    local SENSOR
    local NAME
    local TARGET

    if [ -e /sys/class/sensors/hidden_hole/hh_check_coef ] \
        && [ -e /sys/class/sensors/grip_notifier ] \
        && [ -e /sys/class/sensors/grip_sensor/country_code ]; then
        return 0
    fi
    [ -d /sys/class/sensors ] || return 0

    if grep -q " /sys/class/sensors " /proc/mounts 2>/dev/null; then
        log_msg "hidden_hole sensor overlay already mounted"
        return 0
    fi

    rm -rf "$BASE" 2>/dev/null || true
    mkdir -p "$VIEW/hidden_hole" 2>/dev/null || return 0

    for SENSOR in /sys/class/sensors/*; do
        [ -e "$SENSOR" ] || continue
        NAME="${SENSOR##*/}"
        TARGET="$(readlink -f "$SENSOR" 2>/dev/null || true)"
        [ -n "$TARGET" ] && [ -e "$TARGET" ] || continue
        ln -s "$TARGET" "$VIEW/$NAME" 2>/dev/null || true
    done

    TARGET="$(readlink -f /sys/devices/virtual/sensors/grip_sensor 2>/dev/null || true)"
    if [ -n "$TARGET" ] && [ -d "$TARGET" ]; then
        rm -f "$VIEW/grip_sensor" 2>/dev/null || true
        mkdir -p "$VIEW/grip_sensor" 2>/dev/null || true
        for SENSOR in "$TARGET"/*; do
            [ -e "$SENSOR" ] || continue
            ln -s "$SENSOR" "$VIEW/grip_sensor/${SENSOR##*/}" 2>/dev/null || true
        done
        echo "EEA" > "$VIEW/grip_sensor/country_code" 2>/dev/null || true
        chown -R system:radio "$VIEW/grip_sensor" 2>/dev/null || true
        chmod 0755 "$VIEW/grip_sensor" 2>/dev/null || true
        chmod 0664 "$VIEW/grip_sensor/country_code" 2>/dev/null || true
    fi

    TARGET="$(readlink -f /sys/devices/virtual/sensor_event/symlink/grip_notifier 2>/dev/null || true)"
    if [ -n "$TARGET" ] && [ -e "$TARGET" ]; then
        ln -s "$TARGET" "$VIEW/grip_notifier" 2>/dev/null || true
    fi

    echo "hidden_hole" > "$VIEW/hidden_hole/name" 2>/dev/null || true
    echo "SAMSUNG" > "$VIEW/hidden_hole/vendor" 2>/dev/null || true
    echo "0" > "$VIEW/hidden_hole/hh_check_coef" 2>/dev/null || true
    echo "0" > "$VIEW/hidden_hole/raw_data" 2>/dev/null || true
    chown -R system:radio "$VIEW/hidden_hole" 2>/dev/null || true
    chmod 0755 "$VIEW" "$VIEW/hidden_hole" 2>/dev/null || true
    chmod 0664 "$VIEW/hidden_hole/"* 2>/dev/null || true
    chcon -h u:object_r:sysfs:s0 "$VIEW" "$VIEW/grip_sensor" "$VIEW/grip_sensor/"* \
        "$VIEW/grip_notifier" "$VIEW/hidden_hole" "$VIEW/hidden_hole/"* 2>/dev/null || true

    mount -o bind "$VIEW" /sys/class/sensors 2>/dev/null \
        || "$BUSYBOX" mount -o bind "$VIEW" /sys/class/sensors 2>/dev/null \
        || {
            log_msg "hidden_hole sensor overlay bind failed"
            return 0
        }

    log_msg "hidden_hole sensor overlay mounted"
}

restart_sensors_after_mcu_ready()
{
    (
        local TRY

        stop vendor.sensors-hal-2-0-multihal >/dev/null 2>&1 \
            || setprop ctl.stop vendor.sensors-hal-2-0-multihal >/dev/null 2>&1 \
            || true

        TRY=0
        while [ "$TRY" -lt 24 ]; do
            dmesg 2>/dev/null | grep -q "Sensors of MCU are ready" && break
            TRY=$((TRY + 1))
            sleep 1
        done

        start vendor.sensors-hal-2-0-multihal >/dev/null 2>&1 \
            || setprop ctl.start vendor.sensors-hal-2-0-multihal >/dev/null 2>&1 \
            || true
        log_msg "sensor HAL start requested after sensorhub wait"
    ) &
}

mount_system_lib64_overlay()
{
    local SRC="$MODDIR/system/lib64/libpenguin.so"
    local BASE="/dev/monsterrom_oneui9_patches_system_lib64"
    local UPPER="$BASE/upper"
    local WORK="$BASE/work"

    [ -f "$SRC" ] || return 0
    [ -d /system/lib64 ] || return 0

    if [ -e /system/lib64/libpenguin.so ]; then
        return 0
    fi

    if grep -q " /system/lib64 " /proc/mounts 2>/dev/null; then
        return 0
    fi

    rm -rf "$BASE" 2>/dev/null || true
    mkdir -p "$BASE" 2>/dev/null || return 0
    mount -t tmpfs -o mode=0755,size=4m tmpfs "$BASE" 2>/dev/null || {
        log_msg "tmpfs upper mount failed for /system/lib64 overlay"
        return 0
    }

    mkdir -p "$UPPER" "$WORK" 2>/dev/null || {
        umount "$BASE" 2>/dev/null || true
        return 0
    }

    cp -af "$SRC" "$UPPER/libpenguin.so" 2>/dev/null || {
        umount "$BASE" 2>/dev/null || true
        return 0
    }
    chown 0:0 "$UPPER/libpenguin.so" 2>/dev/null || true
    chmod 0644 "$UPPER/libpenguin.so" 2>/dev/null || true
    chcon u:object_r:system_lib_file:s0 "$UPPER/libpenguin.so" 2>/dev/null || true

    mount -t overlay overlay \
        -o "lowerdir=/system/lib64,upperdir=$UPPER,workdir=$WORK,index=off,metacopy=off" \
        /system/lib64 2>/dev/null \
        || mount -t overlay overlay \
            -o "lowerdir=/system/lib64,upperdir=$UPPER,workdir=$WORK" \
            /system/lib64 2>/dev/null \
        || {
            log_msg "overlay failed: /system/lib64 libpenguin shim"
            umount "$BASE" 2>/dev/null || true
            return 0
        }

    log_msg "overlay mounted: /system/lib64 libpenguin shim"
}

mount_vendor_lib64_overlay()
{
    local BASE="/dev/monsterrom_oneui9_patches_vendor_lib64"
    local UPPER="$BASE/upper"
    local WORK="$BASE/work"
    local LIB
    local NEEDED=false
    local LIBS="
libAIQSolution_MPI.camera.samsung.so
libcdsprpc.so
"

    [ -d /vendor/lib64 ] || return 0

    for LIB in $LIBS; do
        [ -f "$MODDIR/vendor/lib64/$LIB" ] || continue
        [ -e "/vendor/lib64/$LIB" ] && continue
        NEEDED=true
    done
    $NEEDED || return 0

    if grep -q " /vendor/lib64 " /proc/mounts 2>/dev/null; then
        return 0
    fi

    rm -rf "$BASE" 2>/dev/null || true
    mkdir -p "$BASE" 2>/dev/null || return 0
    mount -t tmpfs -o mode=0755,size=4m tmpfs "$BASE" 2>/dev/null || {
        log_msg "tmpfs upper mount failed for /vendor/lib64 overlay"
        return 0
    }

    mkdir -p "$UPPER" "$WORK" 2>/dev/null || {
        umount "$BASE" 2>/dev/null || true
        return 0
    }

    for LIB in $LIBS; do
        [ -f "$MODDIR/vendor/lib64/$LIB" ] || continue
        [ -e "/vendor/lib64/$LIB" ] && continue
        cp -af "$MODDIR/vendor/lib64/$LIB" "$UPPER/$LIB" 2>/dev/null || {
            umount "$BASE" 2>/dev/null || true
            return 0
        }
        chown 0:0 "$UPPER/$LIB" 2>/dev/null || true
        chmod 0644 "$UPPER/$LIB" 2>/dev/null || true
        chcon u:object_r:vendor_file:s0 "$UPPER/$LIB" 2>/dev/null || true
    done

    mount -t overlay overlay \
        -o "lowerdir=/vendor/lib64,upperdir=$UPPER,workdir=$WORK,index=off,metacopy=off" \
        /vendor/lib64 2>/dev/null \
        || mount -t overlay overlay \
            -o "lowerdir=/vendor/lib64,upperdir=$UPPER,workdir=$WORK" \
            /vendor/lib64 2>/dev/null \
        || {
            log_msg "overlay failed: /vendor/lib64 camera libraries"
            umount "$BASE" 2>/dev/null || true
            return 0
        }

    log_msg "overlay mounted: /vendor/lib64 camera libraries"
}

mount_vendor_etc_overlay()
{
    local BASE="/dev/monsterrom_oneui9_patches_vendor_etc"
    local UPPER="$BASE/upper"
    local WORK="$BASE/work"

    [ -d "$MODDIR/vendor/etc" ] || return 0
    [ -d /vendor/etc ] || return 0

    if grep -q " /vendor/etc " /proc/mounts 2>/dev/null; then
        return 0
    fi

    rm -rf "$BASE" 2>/dev/null || true
    mkdir -p "$UPPER" "$WORK" 2>/dev/null || return 0

    cp -af "$MODDIR/vendor/etc/." "$UPPER/" 2>/dev/null || {
        rm -rf "$BASE" 2>/dev/null || true
        return 0
    }
    chown -R 0:0 "$UPPER" 2>/dev/null || true
    chmod -R u+rwX,go+rX "$UPPER" 2>/dev/null || true
    chcon -R u:object_r:vendor_configs_file:s0 "$UPPER" 2>/dev/null || true

    mount -t overlay overlay \
        -o "lowerdir=/vendor/etc,upperdir=$UPPER,workdir=$WORK,index=off,metacopy=off" \
        /vendor/etc 2>/dev/null \
        || mount -t overlay overlay \
            -o "lowerdir=/vendor/etc,upperdir=$UPPER,workdir=$WORK" \
            /vendor/etc 2>/dev/null \
        || {
            log_msg "overlay failed: /vendor/etc configs"
            rm -rf "$BASE" 2>/dev/null || true
            return 0
        }

    log_msg "overlay mounted: /vendor/etc configs"
}

bind_file()
{
    local REL="$1"
    local SRC="$MODDIR/$REL"
    local DST="/$REL"
    local TRY
    local CONTEXT="u:object_r:system_file:s0"

    [ -f "$SRC" ] || return 0

    case "$REL" in
        vendor/etc/*)
            grep -q " /vendor/etc " /proc/mounts 2>/dev/null && return 0
            ;;
    esac

    case "$REL" in
        system/lib64/*)
            CONTEXT="u:object_r:system_lib_file:s0"
            ;;
        vendor/etc/*)
            CONTEXT="u:object_r:vendor_configs_file:s0"
            ;;
        vendor/*)
            CONTEXT="u:object_r:vendor_file:s0"
            ;;
    esac

    TRY=0
    while [ "$TRY" -lt 5 ]; do
        [ -e "$DST" ] && break
        TRY=$((TRY + 1))
        sleep 1
    done

    if [ ! -e "$DST" ]; then
        log_msg "target missing, skipping $DST"
        return 0
    fi

    chmod 0644 "$SRC" 2>/dev/null || true
    chown 0:0 "$SRC" 2>/dev/null || true
    chcon "$CONTEXT" "$SRC" 2>/dev/null || true

    if grep -q " $DST " /proc/mounts 2>/dev/null; then
        log_msg "bind target already mounted, skipping $DST"
        return 0
    fi

    "$BUSYBOX" mount -o bind "$SRC" "$DST" 2>/dev/null \
        || mount -o bind "$SRC" "$DST" 2>/dev/null \
        || log_msg "bind failed: $SRC -> $DST"
}

apply_pending_payload_updates()
{
    local NEXT
    local DST

    for NEXT in "$MODDIR"/system/priv-app/AirCommand/AirCommand.apk.next; do
        [ -f "$NEXT" ] || continue
        DST="${NEXT%.next}"
        mv -f "$NEXT" "$DST" 2>/dev/null || {
            log_msg "pending payload update failed: $NEXT"
            continue
        }
        chmod 0644 "$DST" 2>/dev/null || true
        chown 0:0 "$DST" 2>/dev/null || true
        chcon u:object_r:system_file:s0 "$DST" 2>/dev/null || true
        log_msg "pending payload update applied: $DST"
    done
}

bind_overlay_entry()
{
    local SRC="$1"
    local DST="$2"

    if [ -d "$SRC" ] && [ ! -L "$SRC" ]; then
        mkdir -p "$DST" 2>/dev/null || return 1
        "$BUSYBOX" mount -o rbind "$SRC" "$DST" 2>/dev/null \
            || "$BUSYBOX" mount -o bind "$SRC" "$DST" 2>/dev/null \
            || mount -o rbind "$SRC" "$DST" 2>/dev/null \
            || mount -o bind "$SRC" "$DST" 2>/dev/null
        return $?
    fi

    mkdir -p "$(dirname "$DST")" 2>/dev/null || return 1
    : > "$DST" 2>/dev/null || touch "$DST" 2>/dev/null || return 1
    "$BUSYBOX" mount -o bind "$SRC" "$DST" 2>/dev/null \
        || mount -o bind "$SRC" "$DST" 2>/dev/null
}

mount_merged_dir_overlay()
{
    local TARGET="$1"
    local MOD_REL="$2"
    local MOD_SRC="$MODDIR/$MOD_REL"
    local STATE_DIR="/data/adb/monsterrom_oneui9_patches/merged_dirs"
    local VIEW="$STATE_DIR/$(echo "$MOD_REL" | tr '/' '_')"
    local ENTRY
    local NAME

    [ -d "$TARGET" ] || return 0
    [ -d "$MOD_SRC" ] || return 0

    if grep -q " $TARGET " /proc/mounts 2>/dev/null; then
        log_msg "merged dir already mounted, skipping $TARGET"
        return 0
    fi

    rm -rf "$VIEW" 2>/dev/null || true
    mkdir -p "$VIEW" 2>/dev/null || return 0
    chown 0:0 "$VIEW" 2>/dev/null || true
    chmod 0755 "$VIEW" 2>/dev/null || true
    chcon u:object_r:system_file:s0 "$VIEW" 2>/dev/null || true

    for ENTRY in "$TARGET"/*; do
        [ -e "$ENTRY" ] || continue
        NAME="${ENTRY##*/}"
        bind_overlay_entry "$ENTRY" "$VIEW/$NAME" \
            || log_msg "merged dir mirror failed: $ENTRY"
    done

    for ENTRY in "$MOD_SRC"/*; do
        [ -e "$ENTRY" ] || continue
        NAME="${ENTRY##*/}"
        if [ -e "$VIEW/$NAME" ] || grep -q " $VIEW/$NAME " /proc/mounts 2>/dev/null; then
            umount -l "$VIEW/$NAME" 2>/dev/null || true
            rm -rf "$VIEW/$NAME" 2>/dev/null || true
        fi
        bind_overlay_entry "$ENTRY" "$VIEW/$NAME" \
            || log_msg "merged dir module entry failed: $ENTRY"
    done

    "$BUSYBOX" mount -o rbind "$VIEW" "$TARGET" 2>/dev/null \
        || mount -o rbind "$VIEW" "$TARGET" 2>/dev/null \
        || "$BUSYBOX" mount -o bind "$VIEW" "$TARGET" 2>/dev/null \
        || mount -o bind "$VIEW" "$TARGET" 2>/dev/null \
        || {
            log_msg "merged dir bind failed: $VIEW -> $TARGET"
            return 0
        }

    log_msg "merged dir mounted: $TARGET"
}

mount_module_addition_overlays()
{
    mount_merged_dir_overlay /system/etc/default-permissions system/etc/default-permissions
    mount_merged_dir_overlay /system/etc/permissions system/etc/permissions
    mount_merged_dir_overlay /system/etc/sysconfig system/etc/sysconfig
    mount_merged_dir_overlay /system/app system/app
    mount_merged_dir_overlay /system/priv-app system/priv-app
    mount_merged_dir_overlay /product/overlay product/overlay
}

clean_launcher_art_cache()
{
    local FILE

    for FILE in /data/dalvik-cache/*/system@priv-app@TouchWizHome_2017@TouchWizHome_2017.apk@classes*; do
        [ -e "$FILE" ] || continue
        rm -f "$FILE" 2>/dev/null || true
    done

    rm -rf \
        /data/system/package_cache/*/*TouchWizHome* \
        /data/system/package_cache/*/*com.sec.android.app.launcher* \
        /data/misc/profiles/cur/*/com.sec.android.app.launcher \
        /data/misc/profiles/ref/com.sec.android.app.launcher \
        2>/dev/null || true
}

clean_aircommand_art_cache()
{
    local FILE

    for FILE in /data/dalvik-cache/*/system@priv-app@AirCommand@AirCommand.apk@classes*; do
        [ -e "$FILE" ] || continue
        rm -f "$FILE" 2>/dev/null || true
    done

    for FILE in /data/dalvik-cache/*/system@app@FactoryAirCommandManager@FactoryAirCommandManager.apk@classes*; do
        [ -e "$FILE" ] || continue
        rm -f "$FILE" 2>/dev/null || true
    done

    rm -rf \
        /data/system/package_cache/*/*AirCommand* \
        /data/system/package_cache/*/*com.samsung.android.service.aircommand* \
        /data/system/package_cache/*/*FactoryAirCommandManager* \
        /data/system/package_cache/*/*com.samsung.android.aircommandmanager* \
        /data/misc/profiles/cur/*/com.samsung.android.service.aircommand \
        /data/misc/profiles/ref/com.samsung.android.service.aircommand \
        /data/misc/profiles/cur/*/com.samsung.android.aircommandmanager \
        /data/misc/profiles/ref/com.samsung.android.aircommandmanager \
        2>/dev/null || true
}

fix_sensor_permissions
mount_hidden_hole_sensor_overlay
restart_sensors_after_mcu_ready
apply_pending_payload_updates
mount_system_lib64_overlay
mount_vendor_lib64_overlay
mount_vendor_etc_overlay
mount_module_addition_overlays
log_msg "early repairs applied"

for REL in \
    system/cameradata/camera-feature.xml \
    system/etc/default-permissions/default-permissions-com.samsung.android.beaconmanager.xml \
    system/etc/default-permissions/default-permissions-com.samsung.android.service.aircommand.xml \
    system/etc/floating_feature.xml \
    system/etc/permissions/privapp-permissions-com.samsung.android.service.aircommand.xml \
    system/etc/permissions/com.sec.feature.spen_usp_level70.xml \
    system/etc/public.libraries-camera.samsung.txt \
    system/etc/sysconfig/preinstalled-packages-com.samsung.android.aircommandmanager.xml \
    system/framework/framework.jar \
    system/framework/services.jar \
    system/lib64/libFaceClustering.camera.samsung.so \
    system/lib64/libFaceRestoration.camera.samsung.so \
    system/lib64/libFace_Landmark_Engine.camera.samsung.so \
    system/lib64/libpenguin.so \
    system/app/FactoryAirCommandManager/FactoryAirCommandManager.apk \
    system/app/HandwritingService/HandwritingService.apk \
    system/priv-app/AirCommand/AirCommand.apk \
    system/priv-app/SamsungSmartSuggestions/SamsungSmartSuggestions.apk \
    system/priv-app/TouchWizHome_2017/TouchWizHome_2017.apk \
    system/priv-app/wallpaper-res/wallpaper-res.apk \
    product/overlay/NotesRoleEnabled/NotesRoleEnabledOverlay.apk \
    vendor/etc/public.libraries.txt \
    vendor/etc/bluetooth_audio_policy_configuration.xml \
    vendor/etc/sensors/hals.conf \
    vendor/lib64/libAIQSolution_MPI.camera.samsung.so \
    vendor/lib64/libcdsprpc.so \
    vendor/lib64/sensors.sensorhub.so
do
    bind_file "$REL"
done

clean_launcher_art_cache
clean_aircommand_art_cache
EOF

cat > "$MODULE_ROOT/service.sh" <<'EOF'
#!/system/bin/sh

MODDIR=${0%/*}

log_msg()
{
    echo "monsterrom_oneui9_patches: $*" > /dev/kmsg 2>/dev/null || true
}

resetprop_cmd()
{
    if [ -x /data/adb/ksud ]; then
        /data/adb/ksud resetprop "$@" >/dev/null 2>&1
    elif command -v resetprop >/dev/null 2>&1; then
        resetprop "$@" >/dev/null 2>&1
    else
        return 1
    fi
}

set_log_tag_runtime()
{
    resetprop_cmd "log.tag.$1" "$2" || setprop "log.tag.$1" "$2" >/dev/null 2>&1 || true
    resetprop_cmd -p "persist.log.tag.$1" "$2" || setprop "persist.log.tag.$1" "$2" >/dev/null 2>&1 || true
}

quiet_visible_log_noise()
{
    resetprop_cmd ro.logd.kernel false || true
    resetprop_cmd debug.sf.show_refresh_rate_overlay_render_rate false \
        || setprop debug.sf.show_refresh_rate_overlay_render_rate false >/dev/null 2>&1 || true
    resetprop_cmd -p persist.debug.wfd.enable 0 \
        || setprop persist.debug.wfd.enable 0 >/dev/null 2>&1 || true
    resetprop_cmd nfc.nxp_log_level_global 0 \
        || setprop nfc.nxp_log_level_global 0 >/dev/null 2>&1 || true
    resetprop_cmd -p persist.vendor.nfc.log.index 0 \
        || setprop persist.vendor.nfc.log.index 0 >/dev/null 2>&1 || true
    resetprop_cmd -p persist.log.level 0xFFFFFFFF \
        || setprop persist.log.level 0xFFFFFFFF >/dev/null 2>&1 || true
    resetprop_cmd -p persist.log.semlevel 0xFFFFFF00 \
        || setprop persist.log.semlevel 0xFFFFFF00 >/dev/null 2>&1 || true
    resetprop_cmd log.tag E || setprop log.tag E >/dev/null 2>&1 || true
    resetprop_cmd -p persist.log.tag E \
        || setprop persist.log.tag E >/dev/null 2>&1 || true

    set_log_tag_runtime SurfaceFlinger F
    set_log_tag_runtime WifiDisplayAdapter W
    set_log_tag_runtime WifiDisplayController W
    set_log_tag_runtime DisplayManagerService W
    set_log_tag_runtime NxpGenExtn F
    set_log_tag_runtime RILJ F
    set_log_tag_runtime SEM_RILJ F
    set_log_tag_runtime RILD F
    set_log_tag_runtime RILD2 F
    set_log_tag_runtime Multi-Client F
    set_log_tag_runtime Multi-Client2 F
    set_log_tag_runtime BSOHChargingDataCollector W
    set_log_tag_runtime PackageConfigPersister E
    set_log_tag_runtime GlassesApi F
    set_log_tag_runtime cnka F
    set_log_tag_runtime LockPatternUtils E
    set_log_tag_runtime usb_notify W
    set_log_tag_runtime APM_AudioPolicyManager E
    set_log_tag_runtime vendor.samsung.bluetooth.audio.BTAudioProvider W
    set_log_tag_runtime BatteryService_BatteryPropertiesRegistrar W
    set_log_tag_runtime SemWifiIntelligentTrainingManager W
    set_log_tag_runtime Settings E
    set_log_tag_runtime PackageManager E
    set_log_tag_runtime Binder E
    set_log_tag_runtime SemWallpaperColorsArea E
    set_log_tag_runtime SmartFaceManager F
    set_log_tag_runtime SmartFaceService F
    set_log_tag_runtime SmartFaceServiceStarter F
    set_log_tag_runtime ExynosCameraNode E
    set_log_tag_runtime CameraDeviceClient E
    set_log_tag_runtime CAE E
    set_log_tag_runtime Sensors F
    set_log_tag_runtime SensorService F
    set_log_tag_runtime SemContext.CaeProvider F
    set_log_tag_runtime LocalDisplayAdapter E
    set_log_tag_runtime display F
    set_log_tag_runtime ShellTransitions F
    set_log_tag_runtime NativeCustomFrequencyManager F
    set_log_tag_runtime AODManagerService F
    set_log_tag_runtime libprocessgroup E
    set_log_tag_runtime DeviceStorageMonitorService E
    set_log_tag_runtime AccountTypeLoader E
    set_log_tag_runtime System E
    set_log_tag_runtime keymaster_tee E
    set_log_tag_runtime ConnectivityService W
    set_log_tag_runtime ConnectivityManager W
    set_log_tag_runtime BLASTSyncEngine E
    set_log_tag_runtime bt_btm_pm E
    set_log_tag_runtime bluetooth E
    set_log_tag_runtime ProcessStats E
    set_log_tag_runtime Netd E
    set_log_tag_runtime AlarmManager E
    set_log_tag_runtime id.app.launcher E
    set_log_tag_runtime Watchdog F
    set_log_tag_runtime DBManager F
    set_log_tag_runtime AbsSettings F
    set_log_tag_runtime WallpaperResourcesInfo E
    set_log_tag_runtime getBitmap F
    set_log_tag_runtime FuseDaemon F
    set_log_tag_runtime ActivityManager F
    set_log_tag_runtime roid.themestore F
    set_log_tag_runtime ThemeCenter_ThemeManagerService F
    set_log_tag_runtime PermissionService E
    set_log_tag_runtime AdvertisingIdSettings E
    set_log_tag_runtime AODSettingsHelper F
    set_log_tag_runtime Kumiho-Kumiho E
    set_log_tag_runtime NearbyMediums E
    set_log_tag_runtime NearbyConnections E
    set_log_tag_runtime NearbySharing E
    set_log_tag_runtime NearbyDiscovery E
    set_log_tag_runtime BtGatt.AdvertiseManager E
    set_log_tag_runtime BluetoothMetrics E
    set_log_tag_runtime rfcomm_port_utils E
    set_log_tag_runtime AppOpService F
    set_log_tag_runtime AppOps F
    set_log_tag_runtime PlayIntegrityHooks F
    set_log_tag_runtime QueryBuilder F
    set_log_tag_runtime RemoteWorkerFactory E
    set_log_tag_runtime JobInfo E
    set_log_tag_runtime MetadataRetrieverClient F
    set_log_tag_runtime CMHProvider F
    set_log_tag_runtime SatelliteController F
    set_log_tag_runtime CmcServiceHelper F
    set_log_tag_runtime ImsUri F
    set_log_tag_runtime SecImsServiceConnector F
    set_log_tag_runtime ContextImpl E
    set_log_tag_runtime NSLocationMonitor E
    set_log_tag_runtime NetworkManager_FLP E
    set_log_tag_runtime resolv E
    set_log_tag_runtime View E
    set_log_tag_runtime KeyguardSecurityViewFlipper E
    set_log_tag_runtime CCTFlatFileLogStore E
    set_log_tag_runtime SQLiteLog F
    set_log_tag_runtime SQLiteCursor F
    set_log_tag_runtime SensorsGrip F
    set_log_tag_runtime SSS@search F
    set_log_tag_runtime SemSupplicantStaIfaceHalHidlImpl F
    set_log_tag_runtime power F
    set_log_tag_runtime WM-WorkerWrapper F
    set_log_tag_runtime MediaContentSyncTask F
    set_log_tag_runtime ControllerEventHandler F
    set_log_tag_runtime FileSyncManager F
    set_log_tag_runtime WorkerUtils F
    set_log_tag_runtime UnifiedCropper F
    set_log_tag_runtime ArcSoft_C F
    set_log_tag_runtime tflite F
    set_log_tag_runtime kcgz F
    set_log_tag_runtime SemanticLocation E
    set_log_tag_runtime SLocation E
    set_log_tag_runtime RequestManager_FLP F
    set_log_tag_runtime wificond E
    set_log_tag_runtime IE_Capabilities E
    set_log_tag_runtime SemThroughputPredictor F
    set_log_tag_runtime DIAGMON_SDK F
    set_log_tag_runtime SystemServiceRegistry F
    set_log_tag_runtime PersonalSafety E
    set_log_tag_runtime TelephonyCallback E
    set_log_tag_runtime SemBatteryUsageStatsProvider E
    set_log_tag_runtime Finsky E
    set_log_tag_runtime ActivityThread E
    set_log_tag_runtime GAEEngine E
    set_log_tag_runtime SyncManager E
    set_log_tag_runtime Controller F
    set_log_tag_runtime SDMConfig E
    set_log_tag_runtime qr_barcode_decoder F
    set_log_tag_runtime GmsTaskScheduler F
    for TAG in \
        Moneta DataMlSdk NowBarCardViewModel SEMS RILClient GsmCdmaPhone \
        GoogleApiManager kbit LockWidgetData LockCalendarHelper \
        SafetyCenterManagerWrap TNP CalendarSyncAdapter RILC rild DNC-0 DNC-1 \
        NetworkTypeController SemGsmCdmaPhone TelephonyAnalyticsSubId \
        NowBrief.LLMPolicy ConfigUpdater AppIconSolution FSA2_SyncUpPhotoCursor \
        engmode_client_aidl SLocation SDHMS BluetoothCastAdapterService \
        BluetoothRemoteDevices BluetoothAdapterService CachedBluetoothDevice \
        BTAudioHalDeviceProxy BTAudioHalStream BTAudioA2dpHIDL \
        BTAudioClientHIDL A2dpService BluetoothActiveDeviceManager \
        bt_btif_storage bt_btu_hcif bluetooth-a2dp BUPlugin_BudsLogManager \
        DlbSpatializerEffectContext AS.AudioDeviceInventory AS.AudioService \
        AS.SpatializerHelper BluetoothBDTestService BluetoothUtils SemWifiApSmartBleScanner \
        CameraService_worker cameraserver ExynosCameraInterface \
        ExynosCameraMetadataConverterVendor SveCamera LockGuard GameTools \
        GoogleSettingsUtils MediaProvider SatelliteModemInterface AppSearchIcing \
        BRListParser PdeNotificationListenerService MemoryLeakHandler \
        mAFPC_ABC NotificationService LpaConnector CustomCpuInfoReader \
        DigitalHorizontalClockView_LOCK_SCREEN_2@218 \
        DigitalHorizontalClockView_LOCK_SCREEN_2@115 \
        ClockBlurManager@355_parent@218 SecVibrator-HAL-AIDL-CORE \
        SecVibrator-HAL-AIDL-EXT pageboostd KeyguardFingerPrintSwipe \
        WorkSourceUtil AOD_CONFIG@AODConfigurationController \
        HoneySpace.ReflectionUtils HoneySpace.OnBoardingUtil \
        SettingsToPropertiesMapper AutofillManagerServiceImpl GuestManager \
        PocketModeEvent PocketMotionManager AutomaticBrightnessController \
        DreamController LSO_LSOInterface NotifRow MODManager \
        bauth_FPQCBAuthSensorControl FaceServiceStorage BiometricScheduler \
        MotionRecognitionService WifiGuiderService TransitionChain ConsumerBase; do
        set_log_tag_runtime "$TAG" F
    done

    [ -w /proc/sys/kernel/printk ] && echo "3 4 1 3" > /proc/sys/kernel/printk 2>/dev/null || true
    [ -w /proc/sys/kernel/printk_devkmsg ] && echo "off" > /proc/sys/kernel/printk_devkmsg 2>/dev/null || true
}

wait_for_boot()
{
    local TRY=0

    while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ] && [ "$TRY" -lt 90 ]; do
        TRY=$((TRY + 1))
        sleep 2
    done
}

fix_display_defaults()
{
    wm size reset >/dev/null 2>&1 || true
    wm density reset >/dev/null 2>&1 || true
    settings put system screen_mode_setting 4 >/dev/null 2>&1 || true
    settings put system display_color_mode 0 >/dev/null 2>&1 || true
    settings put secure accessibility_display_daltonizer_enabled 0 >/dev/null 2>&1 || true
}

fix_bluetooth_audio_defaults()
{
    resetprop_cmd bluetooth.a2dp.source.sbc_priority.config 1001 \
        || setprop bluetooth.a2dp.source.sbc_priority.config 1001 >/dev/null 2>&1 || true
    resetprop_cmd bluetooth.a2dp.source.aac_priority.config 900000 \
        || setprop bluetooth.a2dp.source.aac_priority.config 900000 >/dev/null 2>&1 || true
    resetprop_cmd bluetooth.a2dp.source.aptx_priority.config -1 \
        || setprop bluetooth.a2dp.source.aptx_priority.config -1 >/dev/null 2>&1 || true
    resetprop_cmd bluetooth.a2dp.source.aptx_hd_priority.config -1 \
        || setprop bluetooth.a2dp.source.aptx_hd_priority.config -1 >/dev/null 2>&1 || true
    resetprop_cmd bluetooth.a2dp.source.ldac_priority.config -1 \
        || setprop bluetooth.a2dp.source.ldac_priority.config -1 >/dev/null 2>&1 || true
    resetprop_cmd bluetooth.a2dp.source.opus_priority.config -1 \
        || setprop bluetooth.a2dp.source.opus_priority.config -1 >/dev/null 2>&1 || true
    resetprop_cmd bluetooth.a2dp.source.lhdcv5_priority.config -1 \
        || setprop bluetooth.a2dp.source.lhdcv5_priority.config -1 >/dev/null 2>&1 || true

    resetprop_cmd audio.offload.disable 1 || setprop audio.offload.disable 1 >/dev/null 2>&1 || true
    resetprop_cmd audio.offload.video false || setprop audio.offload.video false >/dev/null 2>&1 || true
    resetprop_cmd audio.deep_buffer.media false || setprop audio.deep_buffer.media false >/dev/null 2>&1 || true
    resetprop_cmd tunnel.audio.encode false || setprop tunnel.audio.encode false >/dev/null 2>&1 || true
    resetprop_cmd media.stagefright.audio.deep false || setprop media.stagefright.audio.deep false >/dev/null 2>&1 || true

    settings put global bluetooth_a2dp_codec 1 >/dev/null 2>&1 || true
    settings put global bluetooth_a2dp_codec_priority_sbc 1001 >/dev/null 2>&1 || true
    settings put global bluetooth_a2dp_codec_priority_aac 1000000 >/dev/null 2>&1 || true
    settings put global bluetooth_a2dp_codec_priority_ldac 0 >/dev/null 2>&1 || true
    settings put global bluetooth_a2dp_codec_sample_rate 0 >/dev/null 2>&1 || true
    settings put global bluetooth_a2dp_codec_bits_per_sample 0 >/dev/null 2>&1 || true
    settings put global bluetooth_a2dp_codec_channel_mode 0 >/dev/null 2>&1 || true
    settings put secure bluetooth_a2dp_bt_uhq_state 0 >/dev/null 2>&1 || true
    settings put secure bluetooth_a2dp_uhqa_support 0 >/dev/null 2>&1 || true
    settings put secure bt_a2dp_audio_latency 0 >/dev/null 2>&1 || true
    settings put secure spatial_audio_enabled 0 >/dev/null 2>&1 || true
    settings put secure spatial_audio_head_tracking_enabled 0 >/dev/null 2>&1 || true
    settings put global spatial_audio_enabled 0 >/dev/null 2>&1 || true
}

fix_smartface_background_polling()
{
    settings put system intelligent_sleep_mode 0 >/dev/null 2>&1 || true
    settings put global smart_illuminate_enabled 0 >/dev/null 2>&1 || true
    settings put secure face_stay_on_lock_screen 0 >/dev/null 2>&1 || true
    settings put secure face_brighten_screen 0 >/dev/null 2>&1 || true
    am force-stop com.samsung.android.smartface >/dev/null 2>&1 || true
}

fix_samsung_oda_log()
{
    mkdir -p /data/log 2>/dev/null || return 0
    chown system:log /data/log 2>/dev/null || true
    chmod 0775 /data/log 2>/dev/null || true
    touch /data/log/SamsungOdaService.log 2>/dev/null || true
    chown system:log /data/log/SamsungOdaService.log 2>/dev/null || true
    chmod 0666 /data/log/SamsungOdaService.log 2>/dev/null || true
    chcon u:object_r:dumplog_data_file:s0 /data/log /data/log/SamsungOdaService.log 2>/dev/null || true
}

fix_faceservice_worker()
{
    local USER_ID
    local COMPONENT="com.samsung.faceservice/androidx.work.impl.background.systemjob.SystemJobService"

    cmd package list packages com.samsung.faceservice 2>/dev/null \
        | grep -q "^package:com.samsung.faceservice$" || return 0

    for USER_ID in $(cmd user list 2>/dev/null | sed -n 's/.*UserInfo{\([0-9][0-9]*\):.*/\1/p'); do
        pm disable --user "$USER_ID" "$COMPONENT" >/dev/null 2>&1 || true
        cmd jobscheduler cancel -u "$USER_ID" com.samsung.faceservice 18 >/dev/null 2>&1 || true
        cmd jobscheduler cancel -u "$USER_ID" com.samsung.faceservice 22 >/dev/null 2>&1 || true
        cmd jobscheduler cancel -u "$USER_ID" com.samsung.faceservice 12 >/dev/null 2>&1 || true
        am force-stop --user "$USER_ID" com.samsung.faceservice >/dev/null 2>&1 || true
    done

    log_msg "FaceService WorkManager disabled; native FaceClustering stack needs a matched One UI 9 blob pair"
}

fix_ssco_model_provider_users()
{
    local USER_ID
    local PKG="com.samsung.android.ssco"
    local PROVIDER="$PKG/.provider.SemanticDataProvider"
    local RECEIVER="$PKG/.receiver.AppUpdateReceiver"

    cmd package list packages "$PKG" 2>/dev/null | grep -q "^package:$PKG$" || return 0

    for USER_ID in $(cmd user list 2>/dev/null | sed -n 's/.*UserInfo{\([0-9][0-9]*\):.*/\1/p'); do
        cmd package list packages --user "$USER_ID" "$PKG" 2>/dev/null \
            | grep -q "^package:$PKG$" || continue
        pm disable --user "$USER_ID" "$PROVIDER" >/dev/null 2>&1 || true
        pm disable --user "$USER_ID" "$RECEIVER" >/dev/null 2>&1 || true
        am force-stop --user "$USER_ID" "$PKG" >/dev/null 2>&1 || true
    done

    log_msg "SSCO semantic provider disabled; shipped data app targets unsupported NPU"
}

fix_smartsuggestions_history()
{
    local USER_ID
    local APP_UID
    local BASE
    local FILE

    for USER_ID in $(cmd user list 2>/dev/null | sed -n 's/.*UserInfo{\([0-9][0-9]*\):.*/\1/p'); do
        APP_UID="$(cmd package list packages --user "$USER_ID" -U com.samsung.android.smartsuggestions 2>/dev/null \
            | sed -n 's/.*uid:\([0-9][0-9]*\).*/\1/p' | head -n 1)"
        [ -n "$APP_UID" ] || continue

        BASE="/storage/emulated/$USER_ID/Android/data/com.samsung.android.smartsuggestions"
        FILE="$BASE/files/searchHistory.txt"

        mkdir -p "$BASE/files" 2>/dev/null || continue
        touch "$FILE" 2>/dev/null || true
        chown "$APP_UID:ext_data_rw" "$BASE" "$BASE/files" "$FILE" 2>/dev/null \
            || chown "$APP_UID:1078" "$BASE" "$BASE/files" "$FILE" 2>/dev/null \
            || true
        chmod 2770 "$BASE" "$BASE/files" 2>/dev/null || true
        chmod 0660 "$FILE" 2>/dev/null || true
    done
}

fix_beaconmanager_ble_permissions()
{
    local PKG="com.samsung.android.beaconmanager"
    local APP_UID
    local PERM
    local OP

    cmd package list packages "$PKG" 2>/dev/null | grep -q "^package:$PKG$" || return 0

    APP_UID="$(cmd package list packages -U "$PKG" 2>/dev/null \
        | sed -n 's/.*uid:\([0-9][0-9]*\).*/\1/p' | head -n 1)"

    for PERM in \
        android.permission.BLUETOOTH_SCAN \
        android.permission.BLUETOOTH_CONNECT \
        android.permission.BLUETOOTH_ADVERTISE \
        android.permission.POST_NOTIFICATIONS \
        android.permission.ACCESS_COARSE_LOCATION \
        android.permission.ACCESS_FINE_LOCATION \
        android.permission.ACCESS_BACKGROUND_LOCATION; do
        pm grant "$PKG" "$PERM" >/dev/null 2>&1 || true
    done

    for OP in \
        BLUETOOTH_SCAN \
        BLUETOOTH_CONNECT \
        BLUETOOTH_ADVERTISE \
        COARSE_LOCATION \
        FINE_LOCATION; do
        appops set "$PKG" "$OP" allow >/dev/null 2>&1 || true
        [ -n "$APP_UID" ] && cmd appops set --uid "$APP_UID" "$OP" allow >/dev/null 2>&1 || true
        cmd appops set --uid "$PKG" "$OP" allow >/dev/null 2>&1 || true
    done
}

fix_sensor_permissions()
{
    local NODE

    for NODE in \
        /sys/class/lcd/panel/smooth_dim \
        /sys/class/lcd/panel/screen_mode \
        /sys/class/lcd/panel/vrr_lfd \
        /sys/class/power_supply/battery/batt_after_manufactured \
        /sys/class/usb_notify/usb_control/usb_hw_param; do
        [ -e "$NODE" ] || continue
        chown system:system "$NODE" 2>/dev/null || true
        chmod 0664 "$NODE" 2>/dev/null || true
    done

    for NODE in /sys/class/sec/switch/afc_disable; do
        [ -e "$NODE" ] || continue
        chown system:radio "$NODE" 2>/dev/null || true
        chmod 0664 "$NODE" 2>/dev/null || true
    done

    for NODE in /sys/bbd/lk_enable; do
        [ -e "$NODE" ] || continue
        chown gps:system "$NODE" 2>/dev/null || true
        chmod 0664 "$NODE" 2>/dev/null || true
    done

    for NODE in \
        /sys/class/sensors/grip_sensor/onoff \
        /sys/class/sensors/grip_sensor/motion \
        /sys/class/sensors/grip_sensor/unknown_state \
        /sys/class/sensors/ssp_sensor/data_injection_enable \
        /sys/class/sensors/ssp_sensor/enable \
        /sys/class/sensors/ssp_sensor/enable_irq \
        /sys/class/sensors/ssp_sensor/mcu_sleep_test \
        /sys/class/sensors/ssp_sensor/mcu_test \
        /sys/class/sensors/ssp_sensor/sensor_dump \
        /sys/class/sensors/ssp_sensor/ssp_control; do
        [ -e "$NODE" ] || continue
        chown system:radio "$NODE" 2>/dev/null || true
        chmod 0664 "$NODE" 2>/dev/null || true
    done

    for NODE in \
        /sys/devices/virtual/sensor_event/symlink/grip_sensor/enable \
        /sys/devices/virtual/sensor_event/symlink/grip_notifier/enable2; do
        [ -e "$NODE" ] || continue
        chown system:radio "$NODE" 2>/dev/null || true
        chmod 0664 "$NODE" 2>/dev/null || true
    done

    if [ ! -e /sys/class/sensors/hidden_hole ] \
        && [ ! -e /sys/devices/virtual/sensor_event/symlink/hidden_hole ]; then
        log_msg "hidden_hole sysfs node absent; real sensor tree left unmasked"
    fi

    for NODE in \
        /sys/class/sensors/ssp_sensor/ssp_flush \
        /sys/class/sensors/sensor_dev/flush; do
        [ -e "$NODE" ] || continue
        chown system:radio "$NODE" 2>/dev/null || true
        chmod 0220 "$NODE" 2>/dev/null || true
    done

    for NODE in /sys/bus/iio/devices/iio:device*/poll_delay \
        /sys/bus/iio/devices/iio:device*/buffer/enable \
        /sys/bus/iio/devices/iio:device*/buffer/length; do
        [ -e "$NODE" ] || continue
        chown system:system "$NODE" 2>/dev/null || true
        chmod 0660 "$NODE" 2>/dev/null || true
    done
}

mount_hidden_hole_sensor_overlay()
{
    local BASE="/dev/monsterrom_oneui9_patches_hidden_hole"
    local VIEW="$BASE/sensors"
    local SENSOR
    local NAME
    local TARGET

    if [ -e /sys/class/sensors/hidden_hole/hh_check_coef ] \
        && [ -e /sys/class/sensors/grip_notifier ] \
        && [ -e /sys/class/sensors/grip_sensor/country_code ]; then
        return 0
    fi
    [ -d /sys/class/sensors ] || return 0

    if grep -q " /sys/class/sensors " /proc/mounts 2>/dev/null; then
        log_msg "hidden_hole sensor overlay already mounted"
        return 0
    fi

    rm -rf "$BASE" 2>/dev/null || true
    mkdir -p "$VIEW/hidden_hole" 2>/dev/null || return 0

    for SENSOR in /sys/class/sensors/*; do
        [ -e "$SENSOR" ] || continue
        NAME="${SENSOR##*/}"
        TARGET="$(readlink -f "$SENSOR" 2>/dev/null || true)"
        [ -n "$TARGET" ] && [ -e "$TARGET" ] || continue
        ln -s "$TARGET" "$VIEW/$NAME" 2>/dev/null || true
    done

    TARGET="$(readlink -f /sys/devices/virtual/sensors/grip_sensor 2>/dev/null || true)"
    if [ -n "$TARGET" ] && [ -d "$TARGET" ]; then
        rm -f "$VIEW/grip_sensor" 2>/dev/null || true
        mkdir -p "$VIEW/grip_sensor" 2>/dev/null || true
        for SENSOR in "$TARGET"/*; do
            [ -e "$SENSOR" ] || continue
            ln -s "$SENSOR" "$VIEW/grip_sensor/${SENSOR##*/}" 2>/dev/null || true
        done
        echo "EEA" > "$VIEW/grip_sensor/country_code" 2>/dev/null || true
        chown -R system:radio "$VIEW/grip_sensor" 2>/dev/null || true
        chmod 0755 "$VIEW/grip_sensor" 2>/dev/null || true
        chmod 0664 "$VIEW/grip_sensor/country_code" 2>/dev/null || true
    fi

    TARGET="$(readlink -f /sys/devices/virtual/sensor_event/symlink/grip_notifier 2>/dev/null || true)"
    if [ -n "$TARGET" ] && [ -e "$TARGET" ]; then
        ln -s "$TARGET" "$VIEW/grip_notifier" 2>/dev/null || true
    fi

    echo "hidden_hole" > "$VIEW/hidden_hole/name" 2>/dev/null || true
    echo "SAMSUNG" > "$VIEW/hidden_hole/vendor" 2>/dev/null || true
    echo "0" > "$VIEW/hidden_hole/hh_check_coef" 2>/dev/null || true
    echo "0" > "$VIEW/hidden_hole/raw_data" 2>/dev/null || true
    chown -R system:radio "$VIEW/hidden_hole" 2>/dev/null || true
    chmod 0755 "$VIEW" "$VIEW/hidden_hole" 2>/dev/null || true
    chmod 0664 "$VIEW/hidden_hole/"* 2>/dev/null || true
    chcon -h u:object_r:sysfs:s0 "$VIEW" "$VIEW/grip_sensor" "$VIEW/grip_sensor/"* \
        "$VIEW/grip_notifier" "$VIEW/hidden_hole" "$VIEW/hidden_hole/"* 2>/dev/null || true

    mount -o bind "$VIEW" /sys/class/sensors 2>/dev/null \
        || {
            log_msg "hidden_hole sensor overlay bind failed"
            return 0
        }

    log_msg "hidden_hole sensor overlay mounted"
}

fix_launcher_compile_cache()
{
    local APK="/system/priv-app/TouchWizHome_2017/TouchWizHome_2017.apk"
    local STATE_DIR="/data/adb/monsterrom_oneui9_patches"
    local HASH_FILE="$STATE_DIR/launcher.sha256"
    local HASH
    local OLD_HASH

    [ -f "$APK" ] || return 0

    HASH="$(sha256sum "$APK" 2>/dev/null | awk '{ print $1 }')"
    [ -n "$HASH" ] || return 0
    OLD_HASH="$(cat "$HASH_FILE" 2>/dev/null || true)"
    [ "$HASH" != "$OLD_HASH" ] || return 0

    rm -rf \
        /data/system/package_cache/*/*TouchWizHome* \
        /data/system/package_cache/*/*com.sec.android.app.launcher* \
        /data/dalvik-cache/*/system@priv-app@TouchWizHome_2017@TouchWizHome_2017.apk@classes* \
        /data/misc/profiles/cur/*/com.sec.android.app.launcher \
        /data/misc/profiles/ref/com.sec.android.app.launcher \
        2>/dev/null || true

    cmd package compile --reset com.sec.android.app.launcher >/dev/null 2>&1 || true
    am force-stop com.sec.android.app.launcher >/dev/null 2>&1 || true
    monkey -p com.sec.android.app.launcher 1 >/dev/null 2>&1 || true

    mkdir -p "$STATE_DIR" 2>/dev/null || true
    echo "$HASH" > "$HASH_FILE" 2>/dev/null || true
    log_msg "launcher compile cache reset for patched APK"
}

fix_aircommand_compile_cache()
{
    local APK="/system/priv-app/AirCommand/AirCommand.apk"
    local PKG="com.samsung.android.service.aircommand"
    local STATE_DIR="/data/adb/monsterrom_oneui9_patches"
    local HASH_FILE="$STATE_DIR/aircommand.sha256"
    local HASH
    local OLD_HASH

    [ -f "$APK" ] || return 0

    HASH="$(sha256sum "$APK" 2>/dev/null | awk '{ print $1 }')"
    [ -n "$HASH" ] || return 0
    OLD_HASH="$(cat "$HASH_FILE" 2>/dev/null || true)"
    [ "$HASH" != "$OLD_HASH" ] || return 0

    rm -rf \
        /data/system/package_cache/*/*AirCommand* \
        /data/system/package_cache/*/*com.samsung.android.service.aircommand* \
        /data/dalvik-cache/*/system@priv-app@AirCommand@AirCommand.apk@classes* \
        /data/misc/profiles/cur/*/$PKG \
        /data/misc/profiles/ref/$PKG \
        2>/dev/null || true

    cmd package compile --reset "$PKG" >/dev/null 2>&1 || true
    am force-stop "$PKG" >/dev/null 2>&1 || true

    mkdir -p "$STATE_DIR" 2>/dev/null || true
    echo "$HASH" > "$HASH_FILE" 2>/dev/null || true
    log_msg "aircommand compile cache reset for patched APK"
}

start_aircommand_request_daemon()
{
    (
        local REQ
        local LAST_REQ=""
        local PEN_INSERT
        local REC_OLD
        local PEN_OLD

        while true; do
            REQ="$(settings get system unica_aircommand_request 2>/dev/null || true)"

            case "$REQ" in
                show:*|hide:*)
                    [ "$REQ" != "$LAST_REQ" ] || {
                        sleep 1
                        continue
                    }
                    LAST_REQ="$REQ"
                    settings delete system unica_aircommand_request >/dev/null 2>&1 || true

                    case "$REQ" in
                        show:*)
                            REC_OLD="$(settings get system unica_aircommand_old_recommended_apps_setting 2>/dev/null || echo null)"
                            PEN_OLD="$(settings get system unica_aircommand_old_pen_detachment_option 2>/dev/null || echo null)"
                            settings delete system unica_aircommand_old_recommended_apps_setting >/dev/null 2>&1 || true
                            settings delete system unica_aircommand_old_pen_detachment_option >/dev/null 2>&1 || true
                            [ "$REC_OLD" != "null" ] || REC_OLD="$(settings get system recommended_apps_setting 2>/dev/null || echo null)"
                            [ "$PEN_OLD" != "null" ] || PEN_OLD="$(settings get system pen_detachment_option 2>/dev/null || echo null)"
                            if [ "$REC_OLD" = "__UNICA_NULL__" ] && [ "$PEN_OLD" = "0" ]; then
                                PEN_OLD="__UNICA_NULL__"
                            fi
                            [ "$REC_OLD" != "__UNICA_NULL__" ] || REC_OLD="null"
                            [ "$PEN_OLD" != "__UNICA_NULL__" ] || PEN_OLD="null"
                            settings put system recommended_apps_setting 0 >/dev/null 2>&1 || true
                            settings put system pen_detachment_option 2 >/dev/null 2>&1 || true
                            PEN_INSERT=false
                            ;;
                        *)
                            PEN_INSERT=true
                            ;;
                    esac

                    am broadcast -a com.samsung.pen.INSERT \
                        --ez penInsert "$PEN_INSERT" \
                        --ez isBoot false \
                        --ez simulated true >/dev/null 2>&1 \
                        || log_msg "aircommand root broadcast failed: $REQ"

                    if [ "$PEN_INSERT" = false ]; then
                        sleep 8
                        if [ "$REC_OLD" = "null" ]; then
                            settings delete system recommended_apps_setting >/dev/null 2>&1 || true
                        else
                            settings put system recommended_apps_setting "$REC_OLD" >/dev/null 2>&1 || true
                        fi
                        if [ "$PEN_OLD" = "null" ]; then
                            settings delete system pen_detachment_option >/dev/null 2>&1 || true
                        else
                            settings put system pen_detachment_option "$PEN_OLD" >/dev/null 2>&1 || true
                        fi
                    elif [ "$PEN_INSERT" = true ]; then
                        sleep 5
                        am broadcast -a com.samsung.pen.INSERT \
                            --ez penInsert true \
                            --ez isBoot false \
                            --ez simulated true >/dev/null 2>&1 \
                            || true
                    fi
                    ;;
            esac

            sleep 1
        done
    ) &

    log_msg "aircommand root request daemon started"
}

wait_for_boot
start_aircommand_request_daemon
quiet_visible_log_noise
fix_display_defaults
fix_bluetooth_audio_defaults
fix_smartface_background_polling
fix_samsung_oda_log
fix_faceservice_worker
fix_ssco_model_provider_users
fix_smartsuggestions_history
fix_beaconmanager_ble_permissions
fix_sensor_permissions
mount_hidden_hole_sensor_overlay
fix_launcher_compile_cache
fix_aircommand_compile_cache
log_msg "runtime repairs applied"
EOF

chmod 0644 "$MODULE_ROOT/module.prop" "$MODULE_ROOT/customize.sh" "$MODULE_ROOT/system.prop" "$MODULE_ROOT/sepolicy.rule"
chmod 0755 "$MODULE_ROOT/post-fs-data.sh" "$MODULE_ROOT/post-mount.sh" "$MODULE_ROOT/service.sh"

copy_payload "system/system/etc/floating_feature.xml" \
    "system/etc/floating_feature.xml"
copy_payload "system/system/cameradata/camera-feature.xml" \
    "system/cameradata/camera-feature.xml"
copy_repo_payload "platform/exynos2100/patches/miscs/system/system/etc/default-permissions/default-permissions-com.samsung.android.beaconmanager.xml" \
    "system/etc/default-permissions/default-permissions-com.samsung.android.beaconmanager.xml"
copy_payload "system/system/etc/default-permissions/default-permissions-com.samsung.android.service.aircommand.xml" \
    "system/etc/default-permissions/default-permissions-com.samsung.android.service.aircommand.xml"
copy_payload "system/system/etc/public.libraries-camera.samsung.txt" \
    "system/etc/public.libraries-camera.samsung.txt"
copy_payload "system/system/etc/permissions/privapp-permissions-com.samsung.android.service.aircommand.xml" \
    "system/etc/permissions/privapp-permissions-com.samsung.android.service.aircommand.xml"
copy_payload "system/system/etc/permissions/com.sec.feature.spen_usp_level70.xml" \
    "system/etc/permissions/com.sec.feature.spen_usp_level70.xml"
copy_payload "system/system/etc/sysconfig/preinstalled-packages-com.samsung.android.aircommandmanager.xml" \
    "system/etc/sysconfig/preinstalled-packages-com.samsung.android.aircommandmanager.xml"
copy_payload "system/system/framework/framework.jar" \
    "system/framework/framework.jar"
copy_payload "system/system/framework/services.jar" \
    "system/framework/services.jar"
copy_payload "system/system/lib64/libFaceClustering.camera.samsung.so" \
    "system/lib64/libFaceClustering.camera.samsung.so"
copy_payload "system/system/lib64/libFaceRestoration.camera.samsung.so" \
    "system/lib64/libFaceRestoration.camera.samsung.so"
copy_payload "system/system/lib64/libFace_Landmark_Engine.camera.samsung.so" \
    "system/lib64/libFace_Landmark_Engine.camera.samsung.so"
copy_payload "system/system/lib64/libpenguin.so" \
    "system/lib64/libpenguin.so"
copy_payload "system/system/app/FactoryAirCommandManager/FactoryAirCommandManager.apk" \
    "system/app/FactoryAirCommandManager/FactoryAirCommandManager.apk"
copy_payload "system/system/app/HandwritingService/HandwritingService.apk" \
    "system/app/HandwritingService/HandwritingService.apk"
copy_payload "system/system/priv-app/AirCommand/AirCommand.apk" \
    "system/priv-app/AirCommand/AirCommand.apk"
copy_payload "system/system/priv-app/SamsungSmartSuggestions/SamsungSmartSuggestions.apk" \
    "system/priv-app/SamsungSmartSuggestions/SamsungSmartSuggestions.apk"
copy_payload "system/system/priv-app/TouchWizHome_2017/TouchWizHome_2017.apk" \
    "system/priv-app/TouchWizHome_2017/TouchWizHome_2017.apk"
copy_payload "system/system/priv-app/wallpaper-res/wallpaper-res.apk" \
    "system/priv-app/wallpaper-res/wallpaper-res.apk"
copy_payload "product/overlay/NotesRoleEnabled/NotesRoleEnabledOverlay.apk" \
    "product/overlay/NotesRoleEnabled/NotesRoleEnabledOverlay.apk"
copy_payload "vendor/etc/public.libraries.txt" \
    "vendor/etc/public.libraries.txt"
copy_repo_payload "platform/exynos2100/patches/miscs/vendor/etc/bluetooth_audio_policy_configuration.xml" \
    "vendor/etc/bluetooth_audio_policy_configuration.xml"
copy_payload "vendor/etc/sensors/hals.conf" \
    "vendor/etc/sensors/hals.conf"
copy_payload "vendor/lib64/libAIQSolution_MPI.camera.samsung.so" \
    "vendor/lib64/libAIQSolution_MPI.camera.samsung.so"
copy_payload "vendor/lib64/libcdsprpc.so" \
    "vendor/lib64/libcdsprpc.so"
copy_payload "vendor/lib64/sensors.sensorhub.so" \
    "vendor/lib64/sensors.sensorhub.so"

mkdir -p "$(dirname "$ZIP_PATH")"
rm -f "$ZIP_PATH"
if command -v zip >/dev/null 2>&1; then
    (cd "$MODULE_ROOT" && zip -r9 "$ZIP_PATH" . > /dev/null)
else
    python3 - "$MODULE_ROOT" "$ZIP_PATH" <<'PY'
import os
import sys
import zipfile

root, zip_path = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for base, dirs, files in os.walk(root):
        dirs.sort()
        files.sort()
        for name in files:
            path = os.path.join(base, name)
            archive.write(path, os.path.relpath(path, root))
PY
fi

if [ "$MISSING_PAYLOADS" -gt 0 ]; then
    echo "Built runtime-only module; skipped $MISSING_PAYLOADS missing payload(s)." >&2
fi

echo "$ZIP_PATH"
