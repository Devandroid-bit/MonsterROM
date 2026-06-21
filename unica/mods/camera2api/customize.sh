LOG "- Enabling Camera2API and HAL3 features"

# Append to vendor build.prop
if [ -f "$WORK_DIR/vendor/build.prop" ]; then
    {
        echo ""
        echo "# Camera2API Unlocker"
        echo "persist.camera.HAL3.enabled=1"
        echo "persist.vendor.camera.HAL3.enabled=1"
        echo "ro.vendor.camera.hal3.enabled=1"
    } >> "$WORK_DIR/vendor/build.prop"
fi

# Append to system build.prop
if [ -f "$WORK_DIR/system/system/build.prop" ]; then
    {
        echo ""
        echo "# Camera2API Unlocker"
        echo "persist.camera.HAL3.enabled=1"
        echo "persist.vendor.camera.HAL3.enabled=1"
        echo "ro.vendor.camera.hal3.enabled=1"
    } >> "$WORK_DIR/system/system/build.prop"
fi
