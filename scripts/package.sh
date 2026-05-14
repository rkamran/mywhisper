#!/bin/bash
# Builds MyWhisper in Release, ad-hoc signs it, and bundles a shareable DMG.
# Output: dist/MyWhisper-<version>.dmg
set -euo pipefail

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJ_DIR"

APP_NAME="MyWhisper"
VERSION="$(plutil -extract CFBundleShortVersionString raw -o - MyWhisper/Info.plist 2>/dev/null || echo "0.1.0")"
DERIVED="$PROJ_DIR/.build-package"
DIST="$PROJ_DIR/dist"
STAGING="$(mktemp -d)"
DMG_PATH="$DIST/${APP_NAME}-${VERSION}.dmg"
DMG_VOLNAME="${APP_NAME} ${VERSION}"

echo "==> Building ${APP_NAME} ${VERSION} (Release)…"
mkdir -p "$DERIVED" "$DIST"
xcodebuild \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath "$DERIVED" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="" \
    build > "$DERIVED/build.log" 2>&1

BUILT="$DERIVED/Build/Products/Release/${APP_NAME}.app"
if [ ! -d "$BUILT" ]; then
    echo "❌ Build failed. Last 40 lines:"
    tail -40 "$DERIVED/build.log"
    exit 1
fi

echo "==> Ad-hoc signing (recipient-independent)…"
WHISPER_FW="$BUILT/Contents/Frameworks/whisper.framework"
codesign --remove-signature "$WHISPER_FW/Versions/A/whisper" 2>/dev/null || true
codesign --remove-signature "$WHISPER_FW"                    2>/dev/null || true
codesign --force --sign - "$WHISPER_FW/Versions/A/whisper"
codesign --force --sign - "$WHISPER_FW"
codesign --force --sign - "$BUILT"

echo "==> Staging DMG contents at $STAGING…"
cp -R "$BUILT" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
cat > "$STAGING/README.txt" <<EOF
${APP_NAME} ${VERSION}
─────────────────────────────────────────────────────

INSTALL
1. Drag ${APP_NAME}.app to the Applications folder shortcut.
2. Open Applications, right-click ${APP_NAME}, choose "Open".
   (One-time step — macOS Gatekeeper requires this for apps
   not signed with an Apple Developer ID.)
3. The Setup window will walk you through:
   • Granting microphone access
   • Granting Accessibility access
   • Downloading the Whisper model (~141 MB)
   • Optional: configuring an Ollama Cloud key for polish

USAGE
Hold the Right Option key while you speak. Release to
transcribe and paste into whatever app has focus.

EOF

echo "==> Building DMG at $DMG_PATH…"
rm -f "$DMG_PATH"
hdiutil create \
    -volname "$DMG_VOLNAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "$DMG_PATH" >/dev/null

rm -rf "$STAGING"

SIZE_MB=$(du -m "$DMG_PATH" | awk '{print $1}')
echo ""
echo "✅ Wrote $DMG_PATH (${SIZE_MB} MB)"
echo ""
echo "Share that DMG. Tell the recipient:"
echo "  1. Drag MyWhisper.app to the Applications folder"
echo "  2. Right-click MyWhisper in Applications → Open (one-time Gatekeeper bypass)"
echo ""
