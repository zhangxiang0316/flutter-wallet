#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
# shellcheck source=android_release_common.sh
source "$SCRIPT_DIR/android_release_common.sh"
cd "$PROJECT_ROOT"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🤖 Building Android APK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

load_android_release_metadata
require_android_release_signing
VERSION="$ANDROID_VERSION_NAME"
ENV_FILE=".env.local"

if [ -f "$ENV_FILE" ]; then
    echo "🔐 Loading local API config from $ENV_FILE"
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
else
    echo "⚠️  $ENV_FILE not found. History API keys will not be injected."
fi

echo ""
echo "📦 Version: $VERSION"
echo "🔏 Release signing configuration verified"

echo ""
echo "📦 Step 1: Cleaning previous builds..."
flutter clean

echo ""
echo "🔨 Step 2: Getting dependencies..."
flutter pub get

echo ""
echo "🔨 Step 3: Building APK (Release)..."
flutter build apk --release \
    --dart-define="ETHERSCAN_API_KEY=${ETHERSCAN_API_KEY:-}" \
    --dart-define="TRONGRID_API_KEY=${TRONGRID_API_KEY:-}" \
    --dart-define="HELIUS_API_KEY=${HELIUS_API_KEY:-}" \
    --dart-define="MORALIS_API_KEY=${MORALIS_API_KEY:-}"

echo ""
echo "📂 Step 4: Checking build output..."
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$APK_PATH" ]; then
    echo "❌ Error: APK not found at $APK_PATH"
    exit 1
fi

echo "✅ APK found: $APK_PATH"

echo ""
echo "📦 Step 5: Copying and verifying APK..."
mkdir -p releases/android
RELEASE_APK="releases/android/flutter-Wallet-v${VERSION}.apk"
cp "$APK_PATH" "$RELEASE_APK"
verify_android_apk "$RELEASE_APK"
write_release_checksum "$RELEASE_APK"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ APK created successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📍 Location: $RELEASE_APK"
echo "🔐 Checksum: ${RELEASE_APK}.sha256"
echo ""
echo "📊 File size:"
du -h "$RELEASE_APK"
echo ""
echo "📱 Installation instructions:"
echo "   1. Transfer APK to Android device"
echo "   2. Enable 'Install from Unknown Sources'"
echo "   3. Open APK to install"
echo ""
echo "💡 For App Bundle (Google Play):"
echo "   Run: flutter build appbundle --release"
echo ""
echo "🎉 Done!"
echo ""
