#!/system/bin/sh

TAG="MonsterROM-ErofsBinder"
MODDIR="${0%/*}"

if command -v log >/dev/null 2>&1; then
    log -t "$TAG" "post-fs-data stage reached"
fi

sh "$MODDIR/metamount.sh"
