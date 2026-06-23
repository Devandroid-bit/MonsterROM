#!/system/bin/sh

MODDIR=${0%/*}
LOGFILE=/data/local/tmp/monsterrom-postflash-livefix.log
TAG=MonsterROM-Postflash

log_msg() {
    msg="$*"
    echo "$(date '+%m-%d %H:%M:%S') $msg" >> "$LOGFILE" 2>/dev/null
    log -t "$TAG" "$msg" 2>/dev/null
}

set_prop() {
    if command -v resetprop >/dev/null 2>&1; then
        resetprop -n "$1" "$2" 2>/dev/null
    else
        setprop "$1" "$2" 2>/dev/null
    fi
    log_msg "prop $1=$2"
}

fix_node() {
    path="$1"

    if [ ! -e "$path" ]; then
        log_msg "skip missing node $path"
        return 1
    fi

    chown "$2:$3" "$path" 2>/dev/null
    chmod "$4" "$path" 2>/dev/null
    log_msg "node $path -> $2:$3 $4"
}

bind_file() {
    rel="$1"
    src="$MODDIR/$rel"
    dst="/$rel"
    mount_line=""

    if [ ! -f "$src" ]; then
        log_msg "skip missing source $src"
        return 1
    fi

    if [ ! -e "$dst" ]; then
        log_msg "skip missing target $dst"
        return 1
    fi

    mount_line="$(grep " $dst " /proc/mounts 2>/dev/null | head -n 1)"
    case "$mount_line" in
        "$src "*)
            log_msg "already bound $dst"
            return 0
            ;;
        *" $dst "*)
            umount "$dst" 2>/dev/null
            ;;
    esac

    if mount -o bind "$src" "$dst" 2>/dev/null || mount --bind "$src" "$dst" 2>/dev/null; then
        log_msg "bound $src -> $dst"
        return 0
    fi

    log_msg "bind failed $src -> $dst"
    return 1
}

fix_camera_vendor_lib_info() {
    rel="$1"
    dst="/$rel"
    src="$MODDIR/$rel"
    tmp="$src.tmp"
    key="SEC_FLOATING_FEATURE_CAMERA_CONFIG_VENDOR_LIB_INFO"

    if [ ! -f "$dst" ]; then
        log_msg "skip missing floating feature $dst"
        return 1
    fi

    mkdir -p "${src%/*}" 2>/dev/null
    cp -pf "$dst" "$tmp" 2>/dev/null || {
        log_msg "copy failed $dst -> $tmp"
        return 1
    }

    if ! grep -q "$key" "$tmp" 2>/dev/null; then
        rm -f "$tmp"
        log_msg "skip missing $key in $dst"
        return 1
    fi

    sed -i \
        -e 's/image_codec\.samsung\.v1/image_codec.samsung.v2/g' \
        -e 's/image_codec\.samsung,/image_codec.samsung.v2,/g' \
        -e 's/image_codec\.samsung</image_codec.samsung.v2</g' \
        -e 's/image_codec,/image_codec.samsung.v2,/g' \
        -e 's/image_codec</image_codec.samsung.v2</g' \
        "$tmp" 2>/dev/null

    if ! grep -q "image_codec.samsung.v2" "$tmp" 2>/dev/null; then
        sed -i "s|</$key>|,image_codec.samsung.v2</$key>|" "$tmp" 2>/dev/null
    fi

    mv -f "$tmp" "$src" 2>/dev/null || {
        rm -f "$tmp"
        log_msg "move failed $tmp -> $src"
        return 1
    }
    chmod 644 "$src" 2>/dev/null

    bind_file "$rel"
}

disable_surfaceflinger_shader_cache() {
    set_prop service.sf.cache_dir_available 0
    set_prop service.sf.prime_shader_cache 0

    for prop in \
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
        set_prop "$prop" 0
    done
}

disable_unica_bootsound() {
    set_prop persist.sys.unica.bootsound false
    set_prop service.media.powersnd 0
}

disable_unica_vulkan() {
    set_prop persist.sys.unica.vulkan false
    set_prop debug.hwui.renderer skiagl
}

log_msg "apply start ${1:-manual}"

disable_unica_bootsound
disable_unica_vulkan
set_prop persist.bluetooth.a2dp_offload.disabled true
set_prop persist.vendor.bt.a2dp_offload.disabled true
set_prop persist.vendor.bluetooth.a2dp_offload.disabled true
set_prop persist.bluetooth.leaudio_offload.disabled true
set_prop ro.bluetooth.leaudio_offload.supported false
disable_surfaceflinger_shader_cache
set_prop ro.dalvik.vm.enable_uffd_gc false
set_prop persist.device_config.runtime_native_boot.enable_uffd_gc false
set_prop remote_provisioning.enable_rkpd false
set_prop remote_provisioning.tee.rkp_only 0

fix_node /dev/video10 system camera 0666
fix_node /sys/class/usb_notify/usb_control/usb_sl system system 0664
fix_node /sys/class/usb_notify/usb_control/disable system system 0664
fix_node /sys/class/nfc_sec/pvdd system system 0664
fix_node /sys/class/lcd/panel/smooth_dim system system 0664
fix_node /sys/class/lcd/panel/screen_mode system system 0664
fix_node /sys/class/lcd/panel/vrr_lfd system system 0664
fix_node /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_shared root system 0664
fix_node /proc/sys/net/core/netdev_max_backlog root system 0664
fix_node /dev/blkio/blkio.weight root system 0664
fix_node /dev/blkio/blkio.group_idle root system 0664
fix_node /dev/blkio/background/blkio.weight root system 0664
fix_node /dev/blkio/background/blkio.bfq.weight root system 0664
fix_node /dev/blkio/background/blkio.group_idle root system 0664
fix_node /dev/blkio/top/blkio.ssg.boost_on root system 0664
fix_node /dev/blkio/high/blkio.ssg.max_available_ratio root system 0664
fix_node /dev/blkio/normal/blkio.ssg.max_available_ratio root system 0664
fix_node /dev/blkio/low/blkio.ssg.max_available_ratio root system 0664
fix_node /dev/freezer/frozen/freezer.killable root system 0664
fix_node /dev/cpuctl/foreground/cpu.rt_runtime_us root system 0664
fix_node /dev/cpuctl/background/cpu.rt_runtime_us root system 0664
fix_node /dev/cpuctl/top-app/cpu.rt_runtime_us root system 0664
fix_node /dev/sys/fs/by-name/userdata/seq_file_ra_mul root system 0664
fix_node /sys/class/power_supply/battery/batt_update_data system system 0664
fix_node /sys/class/sensors/grip_sensor/grip_request_firmware system system 0664
fix_node /sys/bbd/lk_enable gps system 0664
fix_node /proc/reset_klog system system 0440

fix_camera_vendor_lib_info system/etc/floating_feature.xml
fix_camera_vendor_lib_info vendor/etc/floating_feature.xml
bind_file system/cameradata/camera-feature.xml
bind_file system/etc/libnfc-nci.conf
bind_file vendor/etc/libnfc-nxp.conf
bind_file vendor/etc/nfc/libnfc-nxp_RF.conf

log_msg "apply done ${1:-manual}"

exit 0
