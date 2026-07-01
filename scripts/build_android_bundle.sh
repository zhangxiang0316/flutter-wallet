#!/bin/bash

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🤖 Building Android App Bundle (AAB)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 版本号
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
echo "🔨 Step 3: Building App Bundle (Release)..."
flutter build appbundle --release \
    --dart-define="ETHERSCAN_API_KEY=${ETHERSCAN_API_KEY:-}" \
    --dart-define="TRONGRID_API_KEY=${TRONGRID_API_KEY:-}" \
    --dart-define="HELIUS_API_KEY=${HELIUS_API_KEY:-}" \
    --dart-define="MORALIS_API_KEY=${MORALIS_API_KEY:-}"

echo ""
echo "📂 Step 4: Checking build output..."
AAB_PATH="build/app/outputs/bundle/release/app-release.aab"
if [ ! -f "$AAB_PATH" ]; then
    echo "❌ Error: AAB not found at $AAB_PATH"
    exit 1
fi

echo "✅ AAB found: $AAB_PATH"

echo ""
echo "📦 Step 5: Copying AAB to release folder..."
mkdir -p releases/android
RELEASE_AAB="releases/android/Omnicast-Wallet-v${VERSION}.aab"
cp "$AAB_PATH" "$RELEASE_AAB"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ App Bundle created successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📍 Location: $RELEASE_AAB"
echo ""
echo "📊 File size:"
du -h "$RELEASE_AAB"
echo ""
echo "📱 Upload to Google Play Console:"
echo "   1. Go to play.google.com/console"
echo "   2. Select your app"
echo "   3. Production → Create new release"
echo "   4. Upload: $RELEASE_AAB"
echo ""
echo "💡 Note: AAB is for Google Play only"
echo "   For direct installation, use APK instead"
echo ""
echo "🎉 Done!"
echo ""
