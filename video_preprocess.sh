#!/usr/bin/env bash
#
# convert_to_web_mp4.sh
#
# Converts every video file in a directory to H.264-encoded MP4 at
# (visually) full quality, preserving all audio streams untouched.
# Output files are written to the SAME directory with a "web_" prefix.
#
# Usage:
#   ./convert_to_web_mp4.sh [/path/to/directory]
#
#   If no directory is given, the script defaults to the directory it
#   lives in (i.e. wherever convert_to_web_mp4.sh itself is saved).
#
# Notes:
#   - Video is re-encoded with libx264 at CRF 18 (visually lossless).
#     For mathematically lossless output set CRF=0 (much larger files).
#   - Output is capped at MAX_W x MAX_H (3840x2160 by default). Anything
#     larger is scaled down preserving aspect ratio; anything smaller is
#     left at its native resolution (never upscaled). Portrait video is
#     handled correctly -- the cap applies to whichever side is longer.
#   - Audio streams are copied bit-for-bit (-c:a copy), so no audio
#     quality is lost and every audio track is preserved.
#   - If the source is already an .mp4 and the re-encoded result turns
#     out LARGER than the original, the re-encode is discarded and the
#     original file is copied verbatim to the web_ name instead.
#   - Files already prefixed with "web_" are skipped, so the script is
#     safe to re-run on the same directory.
#   - Files starting with "._" (macOS AppleDouble metadata files, often
#     created on FAT/exFAT/network drives) are ignored entirely.

set -euo pipefail

# ---- Config ---------------------------------------------------------
CRF=18             # 0 = lossless, 18 = visually lossless, lower = better
PRESET="slow"      # slower presets = better compression at same quality
PREFIX="web_"
MAX_W=3840         # maximum output width  (4K UHD)
MAX_H=2160         # maximum output height (4K UHD)
EXTENSIONS=("mp4" "mov" "mkv" "avi" "webm" "flv" "wmv" "m4v" "mpg" "mpeg" "ts")
# ---------------------------------------------------------------------

usage() {
    echo "Usage: $0 [directory]" >&2
    echo "  If [directory] is omitted, the script's own directory is used." >&2
    exit 1
}

if [[ $# -gt 1 ]]; then
    usage
fi

if [[ $# -eq 1 ]]; then
    DIR="${1%/}"
else
    # No directory given: default to the directory this script lives in.
    # Resolves symlinks so it works even if the script is invoked via a link.
    SOURCE="${BASH_SOURCE[0]}"
    while [[ -L "$SOURCE" ]]; do
        TARGET="$(readlink "$SOURCE")"
        if [[ "$TARGET" == /* ]]; then
            SOURCE="$TARGET"
        else
            SOURCE="$(dirname "$SOURCE")/$TARGET"
        fi
    done
    DIR="$(cd -- "$(dirname -- "$SOURCE")" && pwd)"
    echo "No directory given; defaulting to script directory: $DIR"
fi

if [[ ! -d "$DIR" ]]; then
    echo "Error: '$DIR' is not a directory" >&2
    exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "Error: ffmpeg is not installed or not in PATH" >&2
    exit 1
fi

# Build a case-insensitive find expression for the extensions
find_args=()
for ext in "${EXTENSIONS[@]}"; do
    find_args+=(-iname "*.${ext}" -o)
done
unset 'find_args[${#find_args[@]}-1]'   # drop trailing -o

converted=0
copied=0
skipped=0
failed=0

# Portable file size in bytes (GNU stat and BSD/macOS stat differ)
filesize() {
    stat -c%s "$1" 2>/dev/null || stat -f%z "$1"
}

while IFS= read -r -d '' file; do
    filename="$(basename "$file")"

    if [[ "$filename" == "${PREFIX}"* ]]; then
        echo "Skipping already-converted file: $filename"
        skipped=$((skipped + 1))
        continue
    fi

    name_noext="${filename%.*}"
    ext_lower="$(printf '%s' "${filename##*.}" | tr '[:upper:]' '[:lower:]')"
    outfile="${DIR}/${PREFIX}${name_noext}.mp4"

    if [[ -e "$outfile" ]]; then
        echo "Output already exists, skipping: $(basename "$outfile")"
        skipped=$((skipped + 1))
        continue
    fi

    echo "Converting: $filename -> $(basename "$outfile")"

    # Note: "0:a?" MUST be quoted. The '?' is a shell glob character and
    # would otherwise be mangled or dropped before ffmpeg ever sees it.
    if ffmpeg -nostdin -hide_banner -loglevel warning -stats \
        -i "$file" \
        -map "0:v:0" -map "0:a?" \
        -vf "scale='min(${MAX_W},iw)':'min(${MAX_H},ih)':force_original_aspect_ratio=decrease:force_divisible_by=2" \
        -c:v libx264 -preset "$PRESET" -crf "$CRF" -pix_fmt yuv420p \
        -c:a copy \
        -movflags +faststart \
        "$outfile"
    then
        # If the source was already an .mp4 and re-encoding made it bigger,
        # throw away the re-encode and just copy the original.
        if [[ "$ext_lower" == "mp4" ]]; then
            in_size="$(filesize "$file")"
            out_size="$(filesize "$outfile")"
            if (( out_size > in_size )); then
                echo "  Re-encode larger than source ($out_size > $in_size bytes); copying original instead"
                rm -f -- "$outfile"
                cp -p -- "$file" "$outfile"
                copied=$((copied + 1))
                continue
            fi
        fi
        converted=$((converted + 1))
    else
        echo "  ! Failed to convert: $filename" >&2
        rm -f -- "$outfile"       # remove partial output
        failed=$((failed + 1))
    fi

done < <(find "$DIR" -maxdepth 1 -type f \( "${find_args[@]}" \) ! -name '._*' -print0)

echo
echo "Done. Converted: $converted, copied as-is: $copied, skipped: $skipped, failed: $failed"