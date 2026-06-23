#!/system/bin/sh

MODDIR=${0%/*}

if [ -x "$MODDIR/post-fs-data.sh" ]; then
    "$MODDIR/post-fs-data.sh" post-mount
fi

exit 0
