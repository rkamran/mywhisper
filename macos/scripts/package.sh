#!/bin/bash
# Builds MyWhisper in Release, signs with a Developer ID Application
# certificate, notarizes via Apple, staples the ticket, and ships a DMG.
#
# Prerequisites (one-time setup):
#   • Developer ID Application certificate in your login keychain
#     (Xcode → Settings → Accounts → team → Manage Certificates → + → Developer ID Application).
#   • Notarization credentials stored under keychain profile NOTARY_PROFILE
#     (xcrun notarytool store-credentials "MyWhisper-Notary" --apple-id … --team-id … --password …).

set -euo pipefail

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJ_DIR"

APP_NAME="MyWhisper"
NOTARY_PROFILE="MyWhisper-Notary"
TEAM_ID="9KJ7PBNV65"
ENTITLEMENTS="MyWhisper/MyWhisper.entitlements"

VERSION="$(plutil -extract CFBundleShortVersionString raw -o - MyWhisper/Info.plist 2>/dev/null || echo "0.0.0")"
DERIVED="$PROJ_DIR/.build-package"
DIST="$PROJ_DIR/dist"
STAGING="$(mktemp -d)"
DMG_PATH="$DIST/${APP_NAME}-${VERSION}.dmg"
DMG_VOLNAME="${APP_NAME} ${VERSION}"

# ── Step 1: locate the Developer ID Application certificate ─────────────────
SIGN_IDENTITY="$(security find-identity -v -p codesigning \
    | grep "Developer ID Application" \
    | grep "$TEAM_ID" \
    | head -1 \
    | sed -E 's/^[[:space:]]+[0-9]+\)[[:space:]]+[A-F0-9]+[[:space:]]+"(.+)"$/\1/')"

if [ -z "$SIGN_IDENTITY" ]; then
    echo "❌ No Developer ID Application certificate found for team $TEAM_ID."
    echo "   Add one via Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application."
    exit 1
fi
echo "==> Signing identity: $SIGN_IDENTITY"

# ── Step 2: build ───────────────────────────────────────────────────────────
echo "==> Building ${APP_NAME} ${VERSION} (Release)…"
mkdir -p "$DERIVED" "$DIST"
xcodebuild \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath "$DERIVED" \
    -allowProvisioningUpdates \
    build > "$DERIVED/build.log" 2>&1

BUILT="$DERIVED/Build/Products/Release/${APP_NAME}.app"
if [ ! -d "$BUILT" ]; then
    echo "❌ Build failed. Last 40 lines:"
    tail -40 "$DERIVED/build.log"
    exit 1
fi

# ── Step 3: re-sign with Developer ID, hardened runtime, secure timestamp ───
# Inside-out so nested binaries have matching identity and notarization passes.
echo "==> Re-signing with Developer ID Application…"
WHISPER_FW="$BUILT/Contents/Frameworks/whisper.framework"

codesign --remove-signature "$WHISPER_FW/Versions/A/whisper" 2>/dev/null || true
codesign --remove-signature "$WHISPER_FW"                    2>/dev/null || true

codesign --force --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" "$WHISPER_FW/Versions/A/whisper"
codesign --force --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" "$WHISPER_FW"
codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$SIGN_IDENTITY" "$BUILT"

echo "==> Verifying signature…"
codesign --verify --deep --strict --verbose=1 "$BUILT" 2>&1 | sed 's/^/    /'

# ── Step 4: assemble DMG ────────────────────────────────────────────────────
echo "==> Staging DMG contents…"
cp -R "$BUILT" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
cat > "$STAGING/README.txt" <<EOF
${APP_NAME} ${VERSION}
─────────────────────────────────────────────────────

1. Drag ${APP_NAME}.app to the Applications folder shortcut.
2. Open it from Applications.
3. The Setup window walks you through:
   • Microphone access
   • Accessibility access
   • Downloading the Whisper model (~148 MB)
   • Optional Ollama Cloud key for transcript polishing

Hold the Right Option key while speaking. Release to transcribe and type.
EOF

echo "==> Building DMG at $DMG_PATH…"
rm -f "$DMG_PATH"
hdiutil create \
    -volname "$DMG_VOLNAME" \
    -srcfolder "$STAGING" \
    -ov -format UDZO -fs HFS+ \
    "$DMG_PATH" >/dev/null

# Sign the DMG itself so Gatekeeper has a single-file signature to validate.
echo "==> Signing the DMG…"
codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG_PATH"

# ── Step 5: notarize and staple ─────────────────────────────────────────────
echo "==> Submitting to Apple for notarization (may take 1–5 minutes)…"
SUBMIT_LOG="$DERIVED/notary-submit.log"
if ! xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait > "$SUBMIT_LOG" 2>&1; then
    echo "❌ Notarization submission failed:"
    cat "$SUBMIT_LOG"
    exit 1
fi
cat "$SUBMIT_LOG" | sed 's/^/    /'

# Fail loudly if the status isn't Accepted.
if ! grep -q "status: Accepted" "$SUBMIT_LOG"; then
    SUBMISSION_ID="$(grep -E '^[[:space:]]*id: ' "$SUBMIT_LOG" | head -1 | awk '{print $2}')"
    if [ -n "$SUBMISSION_ID" ]; then
        echo "==> Fetching notarization log for $SUBMISSION_ID…"
        xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$NOTARY_PROFILE"
    fi
    exit 1
fi

echo "==> Stapling notarization ticket…"
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

# Final Gatekeeper assessment — recipients will see this same result.
echo "==> Gatekeeper assessment:"
spctl --assess --type open --context context:primary-signature -v "$DMG_PATH" 2>&1 | sed 's/^/    /'

rm -rf "$STAGING"

SIZE_MB=$(du -m "$DMG_PATH" | awk '{print $1}')
cat <<EOF

✅ Wrote $DMG_PATH (${SIZE_MB} MB)
   Signed by: $SIGN_IDENTITY
   Notarized and stapled — recipients can double-click to open with no Gatekeeper warning.

EOF
