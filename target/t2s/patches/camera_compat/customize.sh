# Android 17's Samsung ACodec helper reads 512 bytes into a 255-byte process
# name buffer. Newer bionic FORTIFY aborts mediaserver when Camera configures
# its encoder. Limit the read to 254 bytes, leaving room for the trailing NUL.
LIBSTAGEFRIGHT="$WORK_DIR/system/system/lib64/libstagefright.so"
FREAD_PATTERN="2100805202408052e30315aae41f8052"
FREAD_REPLACEMENT="21008052c21f8052e30315aae41f8052"

if [ -f "$LIBSTAGEFRIGHT" ] &&
        xxd -p -c 0 "$LIBSTAGEFRIGHT" | grep -q "$FREAD_PATTERN"; then
    HEX_PATCH "$LIBSTAGEFRIGHT" "$FREAD_PATTERN" "$FREAD_REPLACEMENT"
fi

unset LIBSTAGEFRIGHT FREAD_PATTERN FREAD_REPLACEMENT
