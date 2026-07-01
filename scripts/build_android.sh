#!/bin/bash

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🤖 Building Android APK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 版本号（从 pubspec.yaml 读取）
VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
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
echo "📦 Step 5: Copying APK to release folder..."
mkdir -p releases/android
RELEASE_APK="releases/android/Omnicast-Wallet-v${VERSION}.apk"
cp "$APK_PATH" "$RELEASE_APK"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ APK created successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📍 Location: $RELEASE_APK"
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
