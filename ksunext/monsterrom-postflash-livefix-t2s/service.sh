#!/system/bin/sh

MODDIR=${0%/*}
i=0

while [ "$i" -lt 40 ]; do
    if [ -x "$MODDIR/post-fs-data.sh" ]; then
        "$MODDIR/post-fs-data.sh" "service-$i"
    fi

    i=$((i + 1))
    sleep 3
done

exit 0
