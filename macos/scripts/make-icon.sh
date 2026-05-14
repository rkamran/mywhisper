#!/bin/bash
# Generates AppIcon.appiconset (all required sizes) inside MyWhisper/Assets.xcassets.
set -euo pipefail

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJ_DIR"

ICONSET="MyWhisper/Assets.xcassets/AppIcon.appiconset"
TMP="$(mktemp -d)"
MASTER="$TMP/icon-1024.png"

echo "==> Drawing master 1024×1024 icon…"
swift scripts/make-icon.swift "$MASTER"

mkdir -p "$ICONSET"
rm -f "$ICONSET"/*.png

echo "==> Resizing for AppIcon variants…"
declare -a VARIANTS=(
    "16:icon_16x16.png"
    "32:icon_16x16@2x.png"
    "32:icon_32x32.png"
    "64:icon_32x32@2x.png"
    "128:icon_128x128.png"
    "256:icon_128x128@2x.png"
    "256:icon_256x256.png"
    "512:icon_256x256@2x.png"
    "512:icon_512x512.png"
    "1024:icon_512x512@2x.png"
)
for v in "${VARIANTS[@]}"; do
    size="${v%%:*}"
    name="${v##*:}"
    sips -z "$size" "$size" "$MASTER" --out "$ICONSET/$name" > /dev/null
done

cat > "$ICONSET/Contents.json" <<'EOF'
{
  "images" : [
    { "filename" : "icon_16x16.png",     "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png",  "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png",     "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png",  "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png",   "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png","idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png",   "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png","idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png",   "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png","idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF

# Asset catalog needs a Contents.json at the root too
mkdir -p MyWhisper/Assets.xcassets
if [ ! -f MyWhisper/Assets.xcassets/Contents.json ]; then
    cat > MyWhisper/Assets.xcassets/Contents.json <<'EOF'
{
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF
fi

rm -rf "$TMP"
echo "✓ AppIcon variants written to $ICONSET"
