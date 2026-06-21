# Set default SIM count to 1
# Before: [mov w0, #0x2]
# After: [mov w0, #0x1]
# Newer firmware revisions resolve the SIM slot count at runtime and no longer
# embed this hardcoded default, so only patch when the pattern is present
# instead of failing the whole build.
SECRIL_CONFIG_SVC="$WORK_DIR/vendor/bin/secril_config_svc"
if xxd -p -c 0 "$SECRIL_CONFIG_SVC" 2> /dev/null | grep -q "40008052"; then
    HEX_PATCH "$SECRIL_CONFIG_SVC" "40008052" "20008052"
else
    LOGW "secril_config_svc has no hardcoded SIM count default; skipping single SIM patch"
fi
