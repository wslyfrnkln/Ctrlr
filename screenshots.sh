#!/usr/bin/env bash
# screenshots.sh — App Store Screenshot Resizer
#
# Usage:
#   ./screenshots.sh                   # processes Screenshots/source/
#   ./screenshots.sh path/to/folder/   # custom source folder
#
# Output: Screenshots/AppStore/{6.7in, 6.5in}/
# Requires: sips (built into macOS — no dependencies)
#
# Reusable for any project — edit CONFIG below.

set -euo pipefail

# ─── CONFIG ──────────────────────────────────────────────────────────────────
SOURCE_DIR="${1:-Screenshots/source}"
OUTPUT_DIR="Screenshots/AppStore"

# App Store required sizes (width x height, portrait)
# 5.5" omitted — 16:9 aspect ratio differs significantly from modern iPhones.
# Apple accepts 6.7" screenshots for all display sizes.
declare -a SIZES=(
  "6.7in:1290:2796"   # Required — iPhone 15/16 Pro Max
  "6.5in:1284:2778"   # Fallback — iPhone 14 Plus / 13 Pro Max
)
# ─────────────────────────────────────────────────────────────────────────────

# Validate source dir
if [ ! -d "$SOURCE_DIR" ]; then
  echo "✗ Source folder not found: $SOURCE_DIR"
  exit 1
fi

# Collect images
shopt -s nullglob nocaseglob
images=("$SOURCE_DIR"/*.{png,jpg,jpeg,heic})
shopt -u nullglob nocaseglob

if [ ${#images[@]} -eq 0 ]; then
  echo "✗ No images found in $SOURCE_DIR"
  exit 1
fi

echo "Found ${#images[@]} image(s) in $SOURCE_DIR"
echo ""

total=0
failed=0

for size_entry in "${SIZES[@]}"; do
  label="${size_entry%%:*}"
  rest="${size_entry#*:}"
  width="${rest%%:*}"
  height="${rest#*:}"

  out_dir="$OUTPUT_DIR/$label"
  mkdir -p "$out_dir"

  echo "── $label  (${width} × ${height}) ──────────────────────────"

  for img in "${images[@]}"; do
    filename="$(basename "$img")"
    dest="$out_dir/$filename"

    if sips --resampleHeightWidth "$height" "$width" "$img" --out "$dest" &>/dev/null; then
      actual=$(sips -g pixelWidth -g pixelHeight "$dest" 2>/dev/null \
        | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{print w"×"h}')
      echo "  ✓ $filename → $actual"
      (( total++ )) || true
    else
      echo "  ✗ $filename — resize failed"
      (( failed++ )) || true
    fi
  done
  echo ""
done

echo "────────────────────────────────────────────────"
echo "  Done: $total resized, $failed failed"
echo "  Output: $OUTPUT_DIR/"
echo "────────────────────────────────────────────────"
