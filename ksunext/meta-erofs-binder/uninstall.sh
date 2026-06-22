#!/system/bin/sh

TAG="MonsterROM-ErofsBinder"

if command -v log >/dev/null 2>&1; then
    log -t "$TAG" "uninstall requested; bind mounts are cleared on reboot"
fi
