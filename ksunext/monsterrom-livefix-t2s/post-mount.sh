#!/system/bin/sh

TAG="MonsterROM-LiveFix"

if command -v log >/dev/null 2>&1; then
    log -t "$TAG" "post-mount stage reached"
fi

binder=/data/adb/modules/meta-erofs-binder/metamount.sh
if [ -f "$binder" ]; then
    MODULE_METADATA_DIR=/data/adb/modules MODULE_CONTENT_DIR=/data/adb/modules sh "$binder" >/dev/null 2>&1 || true
fi
