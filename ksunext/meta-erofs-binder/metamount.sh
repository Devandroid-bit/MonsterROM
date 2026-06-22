#!/system/bin/sh

MODDIR="${0%/*}"
MODULE_METADATA_DIR="${MODULE_METADATA_DIR:-/data/adb/modules}"
MODULE_CONTENT_DIR="${MODULE_CONTENT_DIR:-$MODULE_METADATA_DIR}"
SELF_ID="${MODDIR##*/}"
TAG="MonsterROM-ErofsBinder"

log_msg() {
    if command -v log >/dev/null 2>&1; then
        log -t "$TAG" "$*"
    fi
    echo "$TAG: $*"
}

copy_target_attrs() {
    src="$1"
    dst="$2"

    [ -e "$dst" ] || return 0
    chcon --reference="$dst" "$src" 2>/dev/null || true

    mode="$(stat -c %a "$dst" 2>/dev/null || true)"
    owner="$(stat -c %u:%g "$dst" 2>/dev/null || true)"

    [ -n "$mode" ] && chmod "$mode" "$src" 2>/dev/null || true
    [ -n "$owner" ] && chown "$owner" "$src" 2>/dev/null || true
}

is_mounted_target() {
    target="$1"
    grep -q " $target " /proc/self/mountinfo 2>/dev/null
}

bind_file() {
    src="$1"
    dst="$2"

    if [ ! -e "$dst" ]; then
        log_msg "skip missing target $dst"
        return 0
    fi

    if [ ! -f "$dst" ]; then
        log_msg "skip non-file target $dst"
        return 0
    fi

    if is_mounted_target "$dst"; then
        log_msg "already mounted $dst"
        return 0
    fi

    copy_target_attrs "$src" "$dst"

    if mount -o bind,dev=KSU "$src" "$dst" 2>/dev/null; then
        log_msg "bind $src -> $dst"
        return 0
    fi

    if mount -o bind "$src" "$dst" 2>/dev/null; then
        log_msg "bind fallback $src -> $dst"
        return 0
    fi

    log_msg "failed bind $src -> $dst"
    return 0
}

mount_payload_dir() {
    src_root="$1"
    dst_root="$2"

    [ -d "$src_root" ] || return 0
    [ -d "$dst_root" ] || {
        log_msg "skip missing mountpoint $dst_root"
        return 0
    }

    find "$src_root" -type f 2>/dev/null | while IFS= read -r src; do
        rel="${src#$src_root/}"
        bind_file "$src" "$dst_root/$rel"
    done
}

mount_module_payload() {
    module_meta="$1"
    module_id="${module_meta##*/}"

    [ "$module_id" = "$SELF_ID" ] && return 0
    [ -f "$module_meta/module.prop" ] || return 0
    [ -f "$module_meta/disable" ] && return 0
    [ -f "$module_meta/remove" ] && return 0
    [ -f "$module_meta/skip_mount" ] && return 0

    module_content="$MODULE_CONTENT_DIR/$module_id"
    [ -d "$module_content" ] || module_content="$module_meta"

    mount_payload_dir "$module_content/system" /system
    mount_payload_dir "$module_content/system_ext" /system_ext
    mount_payload_dir "$module_content/product" /product
    mount_payload_dir "$module_content/vendor" /vendor
    mount_payload_dir "$module_content/odm" /odm
    mount_payload_dir "$module_content/system_dlkm" /system_dlkm
    mount_payload_dir "$module_content/vendor_dlkm" /vendor_dlkm
    mount_payload_dir "$module_content/odm_dlkm" /odm_dlkm
    mount_payload_dir "$module_content/oem" /oem
    mount_payload_dir "$module_content/apex" /apex
}

log_msg "starting mount pass from $MODULE_METADATA_DIR"

for module_meta in "$MODULE_METADATA_DIR"/*; do
    [ -d "$module_meta" ] || continue
    mount_module_payload "$module_meta"
done

log_msg "mount pass complete"
