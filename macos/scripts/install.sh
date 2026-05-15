#!/bin/bash
# Build MyWhisper with Xcode-managed Apple Development signing and install it to
# /Applications. TCC permissions persist because the signing identity is tied
# to your Apple Developer team, not a per-build hash.
#
# One-time setup:
#   Xcode → Settings → Accounts → sign in with your Apple ID and pick the team
#   matching DEVELOPMENT_TEAM in project.yml. Xcode then provisions an "Apple
#   Development" certificate automatically.

set -euo pipefail

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJ_DIR"

APP_NAME="MyWhisper"
DEST="/Applications/${APP_NAME}.app"
DERIVED="$PROJ_DIR/.build-install"

echo "==> Building ${APP_NAME} (Release, Xcode-managed signing)…"
mkdir -p "$DERIVED"
xcodebuild \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath "$DERIVED" \
    -allowProvisioningUpdates \
    build > "$DERIVED/build.log" 2>&1

BUILT="$DERIVED/Build/Products/Release/${APP_NAME}.app"
if [ ! -d "$BUILT" ]; then
    echo "❌ Build failed. Last 40 lines of $DERIVED/build.log:"
    tail -40 "$DERIVED/build.log"
    exit 1
fi

echo "==> Installing to ${DEST}…"
if [ -d "$DEST" ]; then
    osascript -e "tell application \"${APP_NAME}\" to quit" 2>/dev/null || true
    sleep 0.5
    rm -rf "$DEST"
fi
cp -R "$BUILT" "$DEST"

echo "==> Verifying signature…"
codesign --verify --strict --verbose=1 "$DEST" 2>&1 | sed 's/^/    /'
codesign -dvv "$DEST" 2>&1 | grep -E "(Authority|TeamIdentifier|Identifier=)" | sed 's/^/    /'

echo "==> Launching ${APP_NAME}…"
open "$DEST"

cat <<EOF

✅ Installed at ${DEST}
   Signed by Xcode with your Apple Development certificate. TCC grants persist
   across every future install — no more re-prompts.

EOF
