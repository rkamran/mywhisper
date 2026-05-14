#!/bin/bash
# Build MyWhisper, sign with a stable local identity, install to /Applications.
# Re-run any time you change code. TCC permissions persist because the signing
# identity is stable across builds.

set -euo pipefail

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJ_DIR"

APP_NAME="MyWhisper"
DEST="/Applications/${APP_NAME}.app"
DERIVED="$PROJ_DIR/.build-install"
IDENTITY_CN="MyWhisper Local Signer"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

# ─── Step 1: ensure exactly one stable code-signing identity ─────────────────
# Find all certs with our CN. Self-signed/untrusted certs don't appear in
# `find-identity -v` so use `find-certificate -a` instead.
list_hashes() {
    security find-certificate -a -c "$IDENTITY_CN" -Z "$KEYCHAIN" 2>/dev/null \
        | awk -F': ' '/SHA-1 hash:/ {print $2}' || true
}

EXISTING="$(list_hashes)"
COUNT=$(printf '%s\n' "$EXISTING" | grep -c . || true)

if [ "$COUNT" -gt 1 ]; then
    echo "==> Found $COUNT duplicate signing certs — keeping the first, removing the rest…"
    printf '%s\n' "$EXISTING" | tail -n +2 | while IFS= read -r h; do
        [ -z "$h" ] && continue
        security delete-identity   -Z "$h" "$KEYCHAIN" 2>/dev/null || \
        security delete-certificate -Z "$h" "$KEYCHAIN" 2>/dev/null || true
    done
    EXISTING="$(list_hashes)"
    COUNT=$(printf '%s\n' "$EXISTING" | grep -c . || true)
fi

if [ "$COUNT" -eq 0 ]; then
    echo "==> Creating local code-signing identity ($IDENTITY_CN)…"
    CERT_DIR="$(mktemp -d)"
    cat > "$CERT_DIR/openssl.cnf" <<EOF
[req]
distinguished_name = req_dn
prompt = no
[req_dn]
CN = $IDENTITY_CN
[v3]
keyUsage = critical, digitalSignature
extendedKeyUsage = codeSigning
basicConstraints = critical, CA:false
EOF
    openssl genrsa -out "$CERT_DIR/key.pem" 2048 2>/dev/null
    openssl req -new -x509 \
        -key "$CERT_DIR/key.pem" \
        -days 3650 \
        -out "$CERT_DIR/cert.pem" \
        -config "$CERT_DIR/openssl.cnf" \
        -extensions v3 2>/dev/null
    openssl pkcs12 -export \
        -inkey "$CERT_DIR/key.pem" \
        -in "$CERT_DIR/cert.pem" \
        -out "$CERT_DIR/cert.p12" \
        -password pass:mywhisper \
        -name "$IDENTITY_CN" 2>/dev/null
    security import "$CERT_DIR/cert.p12" \
        -k "$KEYCHAIN" \
        -P mywhisper \
        -T /usr/bin/codesign \
        -T /usr/bin/security
    security set-key-partition-list \
        -S "apple-tool:,apple:,codesign:" \
        -s -k "" \
        "$KEYCHAIN" >/dev/null 2>&1 || true
    rm -rf "$CERT_DIR"
    EXISTING="$(list_hashes)"
fi

CERT_HASH="$(printf '%s\n' "$EXISTING" | head -n1)"
if [ -z "$CERT_HASH" ]; then
    echo "❌ Could not locate signing cert after setup."
    exit 1
fi
echo "    ✓ Signing identity SHA-1: $CERT_HASH"

# ─── Step 2: build ────────────────────────────────────────────────────────────
echo "==> Building ${APP_NAME} (Release)…"
mkdir -p "$DERIVED"
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
    echo "❌ Build failed. Last 40 lines of $DERIVED/build.log:"
    tail -40 "$DERIVED/build.log"
    exit 1
fi

# ─── Step 3: install ──────────────────────────────────────────────────────────
echo "==> Installing to ${DEST}…"
if [ -d "$DEST" ]; then
    osascript -e "tell application \"${APP_NAME}\" to quit" 2>/dev/null || true
    sleep 0.5
    rm -rf "$DEST"
fi
cp -R "$BUILT" "$DEST"

# ─── Step 4: sign with stable identity (inside-out) ──────────────────────────
# --deep is deprecated and doesn't re-sign nested binaries reliably; dyld will
# refuse to load a framework whose Team ID doesn't match the main app's. So we
# sign each nested binary explicitly, then the framework bundle, then the app.
echo "==> Signing with stable identity (SHA-1: $CERT_HASH)…"
WHISPER_FW="$DEST/Contents/Frameworks/whisper.framework"
# Strip any pre-existing signatures inside the framework so re-signing produces
# a uniform Team ID across the inner dylib and the outer app.
codesign --remove-signature "$WHISPER_FW/Versions/A/whisper" 2>/dev/null || true
codesign --remove-signature "$WHISPER_FW"                    2>/dev/null || true

codesign --force --sign "$CERT_HASH" \
    "$WHISPER_FW/Versions/A/whisper"
codesign --force --sign "$CERT_HASH" \
    "$WHISPER_FW"
codesign --force --sign "$CERT_HASH" "$DEST"

echo "==> Verifying signatures…"
codesign --verify --strict --verbose=1 "$DEST" 2>&1 | sed 's/^/    /'

# ─── Step 5: launch ───────────────────────────────────────────────────────────
echo "==> Launching ${APP_NAME}…"
open "$DEST"

cat <<EOF

✅ Installed at ${DEST}
   Signed with: ${IDENTITY_CN}

This is a one-time re-prompt. Grant Mic + Accessibility now and they will
persist across every future ./scripts/install.sh run.

If you saw stale Accessibility entries earlier, remove them in
System Settings → Privacy & Security → Accessibility (only keep the
current one).

EOF
