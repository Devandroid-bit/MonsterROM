#!/system/bin/sh

TAG="MonsterROM-LiveFix"

log_msg() {
    if command -v log >/dev/null 2>&1; then
        log -t "$TAG" "$*"
    fi
}

run_erofs_binder() {
    binder=/data/adb/modules/meta-erofs-binder/metamount.sh
    if [ -f "$binder" ]; then
        log_msg "running EROFS binder from post-fs-data"
        MODULE_METADATA_DIR=/data/adb/modules MODULE_CONTENT_DIR=/data/adb/modules sh "$binder" >/dev/null 2>&1 || true
    else
        log_msg "EROFS binder not found at $binder"
    fi
}

get_resetprop() {
    if command -v resetprop >/dev/null 2>&1; then
        command -v resetprop
        return 0
    fi

    if [ -x /data/adb/ksu/bin/resetprop ]; then
        echo /data/adb/ksu/bin/resetprop
        return 0
    fi

    return 1
}

set_prop() {
    key="$1"
    value="$2"

    resetprop_bin="$(get_resetprop 2>/dev/null || true)"
    if [ -n "$resetprop_bin" ]; then
        "$resetprop_bin" -n "$key" "$value" 2>/dev/null && return 0
    fi

    setprop "$key" "$value" 2>/dev/null || true
}

delete_prop() {
    key="$1"

    resetprop_bin="$(get_resetprop 2>/dev/null || true)"
    if [ -n "$resetprop_bin" ]; then
        "$resetprop_bin" -d "$key" 2>/dev/null || true
        "$resetprop_bin" -p -d "$key" 2>/dev/null || true
    fi
}

set_global() {
    key="$1"
    value="$2"

    settings put global "$key" "$value" 2>/dev/null || true
}

log_msg "post-fs-data stage reached"
run_erofs_binder

set_prop ro.dalvik.vm.enable_uffd_gc false
set_prop persist.device_config.runtime_native_boot.enable_uffd_gc false
set_prop remote_provisioning.enable_rkpd false
set_prop remote_provisioning.tee.rkp_only 0
set_global bluetooth_disable_a2dp_hw_offload 1
set_global bluetooth_a2dp_hw_offload_disabled 1
set_prop persist.bluetooth.a2dp_offload.disabled true
set_prop persist.bluetooth.leaudio_offload.disabled true
set_prop persist.vendor.bt.a2dp_offload.disabled true
set_prop persist.vendor.bluetooth.a2dp_offload.disabled true
set_prop ro.bluetooth.leaudio_offload.supported false
delete_prop persist.bluetooth.samsung.a2dp_offload.cap
set_prop persist.sys.unica.vulkan false
set_prop debug.hwui.renderer skiagl
set_prop service.sf.cache_dir_available 0
set_prop service.sf.prime_shader_cache 0
set_prop debug.sf.prime_shader_cache.clipped_dimmed_image_layers 0
set_prop debug.sf.prime_shader_cache.clipped_layers 0
set_prop debug.sf.prime_shader_cache.edge_extension_shader 0
set_prop debug.sf.prime_shader_cache.hole_punch 0
set_prop debug.sf.prime_shader_cache.image_dimmed_layers 0
set_prop debug.sf.prime_shader_cache.image_layers 0
set_prop debug.sf.prime_shader_cache.pip_image_layers 0
set_prop debug.sf.prime_shader_cache.shadow_layers 0
set_prop debug.sf.prime_shader_cache.solid_dimmed_layers 0
set_prop debug.sf.prime_shader_cache.solid_layers 0
set_prop debug.sf.prime_shader_cache.transparent_image_dimmed_layers 0
