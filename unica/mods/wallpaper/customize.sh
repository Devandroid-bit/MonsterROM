if $DEBUG; then
    LOG "\033[0;33m! Debug build detected. Skipping\033[0m"
    return 0
fi

# [
COMPRESS_WEBP()
{
    local FILE="$1"
    local FILE_PATH
    local FILE_NAME
    local RES="2400"
    local CMD

    FILE_PATH="$(dirname "$FILE")"
    FILE_NAME="$(basename "$FILE")"

    if $TARGET_COMMON_SUPPORT_DYN_RESOLUTION_CONTROL; then
        if [ "$TARGET_PRODUCT_SHIPPING_API_LEVEL" -gt "30" ] && \
                [ "$TARGET_PRODUCT_SHIPPING_API_LEVEL" -lt "34" ]; then
            RES="3088"
        else
            RES="3120"
        fi
    fi

    LOG "- Compressing $FILE_NAME"

    CMD="cwebp"
    CMD+=" -q 100"
    CMD+=" -resize $RES $RES"
    CMD+=" \"$FILE_PATH/$FILE_NAME\""
    CMD+=" -o \"$FILE_PATH/temp.webp\""

    EVAL "$CMD" || return 1
    EVAL "mv -f \"$FILE_PATH/temp.webp\" \"$FILE_PATH/$FILE_NAME\"" || return 1
}

ENCODE_MP4()
{
    local FILE="$1"
    local FILE_PATH
    local FILE_NAME
    local RES="-1:2400"
    local CMD

    FILE_PATH="$(dirname "$FILE")"
    FILE_NAME="$(basename "$FILE")"

    if $TARGET_COMMON_SUPPORT_DYN_RESOLUTION_CONTROL; then
        RES="1440:-1"
    fi

    LOG "- Encoding $FILE_NAME"

    CMD="ffmpeg"
    CMD+=" -i \"$FILE_PATH/$FILE_NAME\""
    CMD+=" -c:v libx264 -c:a copy"
    CMD+=" -pix_fmt yuv420p -crf 18 -g 1"
    CMD+=" -preset veryslow -tune zerolatency"
    CMD+=" -movflags use_metadata_tags -map_metadata 0"
    CMD+=" -vf \"fps=60,scale=$RES,setsar=1:1\""
    CMD+=" -video_track_timescale 360000 -movie_timescale 90000"
    CMD+=" \"$FILE_PATH/temp.mp4\""

    EVAL "$CMD" || return 1
    EVAL "mv -f \"$FILE_PATH/temp.mp4\" \"$FILE_PATH/$FILE_NAME\"" || return 1
}

LIST_WALLPAPER_RESOURCE_NAMES()
{
    node - "$@" <<'NODE'
const fs = require("fs");
const files = process.argv.slice(2);
const names = new Set();

function maybeAddName(value) {
  if (typeof value !== "string") {
    return;
  }

  if (/^[A-Za-z0-9_.-]+\.(png|jpg|jpeg|webp|mp4)$/i.test(value)) {
    names.add(value);
  }
}

function visit(value) {
  if (Array.isArray(value)) {
    value.forEach(visit);
    return;
  }

  if (!value || typeof value !== "object") {
    maybeAddName(value);
    return;
  }

  maybeAddName(value.filename);

  if (value.drawables && typeof value.drawables === "object") {
    for (const drawable of Object.values(value.drawables)) {
      if (typeof drawable === "string") {
        names.add(drawable);
      }
    }
  }

  for (const child of Object.values(value)) {
    visit(child);
  }
}

for (const file of files) {
  try {
    visit(JSON.parse(fs.readFileSync(file, "utf8")));
  } catch (error) {
    console.error(`${file}: ${error.message}`);
    process.exitCode = 1;
  }
}

[...names].sort().forEach((name) => console.log(name));
NODE
}

RESOLVE_WALLPAPER_RESOURCE_FILE()
{
    local APK_DIR="$1"
    local NAME="$2"
    local BASE="${NAME%.*}"
    local CANDIDATES=()
    local DIR
    local CANDIDATE

    if [[ "$NAME" == "$BASE" ]]; then
        CANDIDATES=("$NAME" "$NAME.webp" "$NAME.png" "$NAME.jpg" "$NAME.xml")
    else
        CANDIDATES=("$NAME" "$BASE.webp" "$BASE.png" "$BASE.jpg" "$BASE.xml")
    fi

    for DIR in "$APK_DIR/res"/raw "$APK_DIR/res"/drawable* "$APK_DIR/res"/mipmap*; do
        [ -d "$DIR" ] || continue
        for CANDIDATE in "${CANDIDATES[@]}"; do
            if [ -f "$DIR/$CANDIDATE" ]; then
                echo "$DIR/$CANDIDATE"
                return 0
            fi
        done
    done

    return 1
}

PROCESS_WALLPAPER_DECLARED_RESOURCES()
{
    local APK_DIR="$1"
    local JSON_FILES=()
    local RESOURCE_NAMES
    local NAME
    local FILE
    local FOUND=false

    declare -A PROCESSED_FILES=()

    for FILE in "$APK_DIR"/res/raw/resources_info*.json; do
        [ -f "$FILE" ] && JSON_FILES+=("$FILE")
    done

    [ "${#JSON_FILES[@]}" -gt "0" ] || return 1

    RESOURCE_NAMES="$(LIST_WALLPAPER_RESOURCE_NAMES "${JSON_FILES[@]}")" || return 1

    while IFS= read -r NAME; do
        [ "$NAME" ] || continue

        FILE="$(RESOLVE_WALLPAPER_RESOURCE_FILE "$APK_DIR" "$NAME")" || continue
        [ "$FILE" ] || continue
        if [ "${PROCESSED_FILES[$FILE]}" ]; then
            continue
        fi

        PROCESSED_FILES["$FILE"]=true
        FOUND=true

        case "$FILE" in
            *.webp)
                COMPRESS_WEBP "$FILE" || return 1
                ;;
            *.mp4)
                ENCODE_MP4 "$FILE" || return 1
                ;;
        esac
    done <<< "$RESOURCE_NAMES"

    $FOUND
}

PROCESS_WALLPAPER_LEGACY_GLOBS()
{
    local APK_DIR="$1"
    local FILE

    for FILE in "$APK_DIR/res"/drawable-nodpi*/dex_wallpaper_*.webp; do
        [ -f "$FILE" ] || continue
        COMPRESS_WEBP "$FILE" || return 1
    done
    for FILE in "$APK_DIR/res"/drawable-nodpi*/wallpaper_*.webp; do
        [ -f "$FILE" ] || continue
        COMPRESS_WEBP "$FILE" || return 1
    done
    for FILE in "$APK_DIR/res/raw"/video_*.mp4; do
        [ -f "$FILE" ] || continue
        ENCODE_MP4 "$FILE" || return 1
    done
}

ADJUST_WALLPAPER_METADATA()
{
    local JSON_FILE="$1"

    [ -f "$JSON_FILE" ] || return 0

    node - "$JSON_FILE" <<'NODE'
const fs = require("fs");
const file = process.argv[2];
const data = JSON.parse(fs.readFileSync(file, "utf8"));
const SCALE = 2 / 3;
let adjusted = 0;

function scaleFrame(value) {
  if (typeof value !== "number" || value <= 0) {
    return value;
  }
  return Math.floor(value * SCALE);
}

function collectTransitionFrames(info) {
  if (typeof info !== "string") {
    return [];
  }

  const frames = [];
  for (const line of info.split(/\n/)) {
    const parts = line.trim().split(/\s+/);
    if (parts.length < 5) {
      continue;
    }

    for (const index of [2, 3]) {
      if (/^\d+$/.test(parts[index])) {
        frames.push(Number(parts[index]));
      }
    }
  }

  return frames;
}

function shouldScale(entry, settings) {
  const frames = collectTransitionFrames(settings.transition_frame_info);
  for (const key of ["thumbnail_system_frame_no", "thumbnail_lock_frame_no", "thumbnail_frame_no"]) {
    if (typeof settings[key] === "number") {
      frames.push(settings[key]);
    }
  }
  if (typeof entry.frame_no === "number") {
    frames.push(entry.frame_no);
  }

  return frames.some((frame) => frame > 1079 || frame === 270);
}

function scaleTransitionInfo(info) {
  if (typeof info !== "string") {
    return info;
  }

  return info.split(/\n/).map((line) => {
    const parts = line.trim().split(/\s+/);
    if (parts.length < 5) {
      return line;
    }

    for (const index of [2, 3]) {
      if (/^\d+$/.test(parts[index])) {
        parts[index] = String(scaleFrame(Number(parts[index])));
      }
    }

    return parts.join(" ");
  }).join("\n");
}

function adjustEntry(entry) {
  const settings = entry?.type_params?.service_settings;
  const filename = settings?.filename || entry?.filename;
  if (!settings || !/^video_\d+\.mp4$/i.test(filename || "")) {
    return;
  }

  if (!shouldScale(entry, settings)) {
    return;
  }

  for (const key of ["thumbnail_system_frame_no", "thumbnail_lock_frame_no", "thumbnail_frame_no"]) {
    settings[key] = scaleFrame(settings[key]);
  }
  entry.frame_no = scaleFrame(entry.frame_no);
  settings.transition_frame_info = scaleTransitionInfo(settings.transition_frame_info);
  adjusted += 1;
}

function visit(value) {
  if (Array.isArray(value)) {
    value.forEach(visit);
    return;
  }

  if (!value || typeof value !== "object") {
    return;
  }

  adjustEntry(value);
  Object.values(value).forEach(visit);
}

visit(data);

if (adjusted > 0) {
  fs.writeFileSync(file, `${JSON.stringify(data, null, 2)}\n`);
}

console.log(adjusted);
NODE
}
# ]

LOG "- Using source wallpaper resources"
WALLPAPER_APK_DIR="$APKTOOL_DIR/system/priv-app/wallpaper-res/wallpaper-res.apk"
DECODE_APK "system" "system/priv-app/wallpaper-res/wallpaper-res.apk" || return 1
if ! PROCESS_WALLPAPER_DECLARED_RESOURCES "$WALLPAPER_APK_DIR"; then
    LOG "\033[0;33m! resources_info scan failed. Falling back to legacy wallpaper globs\033[0m"
    PROCESS_WALLPAPER_LEGACY_GLOBS "$WALLPAPER_APK_DIR" || return 1
fi
ADJUSTED_WALLPAPER_METADATA="$(ADJUST_WALLPAPER_METADATA "$WALLPAPER_APK_DIR/res/raw/resources_info.json")" || return 1
if [ "$ADJUSTED_WALLPAPER_METADATA" -gt "0" ]; then
    LOG "- Adjusted metadata for $ADJUSTED_WALLPAPER_METADATA video wallpaper(s)"
fi
LOG "- Using source Samsung Wallpaper app"
APPLY_PATCH "system" "system/priv-app/SpriteWallpaper/SpriteWallpaper.apk" \
    "$MODPATH/SpriteWallpaper.apk/0001-Force-Miracle-wallpapers-motion-animator.patch"
APPLY_PATCH "system" "system/priv-app/SpriteWallpaper/SpriteWallpaper.apk" \
    "$MODPATH/SpriteWallpaper.apk/0002-Adjust-motion-animator-for-60fps-video-files.patch"

unset -f \
    ADJUST_WALLPAPER_METADATA \
    ENCODE_MP4 \
    COMPRESS_WEBP \
    LIST_WALLPAPER_RESOURCE_NAMES \
    PROCESS_WALLPAPER_DECLARED_RESOURCES \
    PROCESS_WALLPAPER_LEGACY_GLOBS \
    RESOLVE_WALLPAPER_RESOURCE_FILE
unset ADJUSTED_WALLPAPER_METADATA WALLPAPER_APK_DIR
