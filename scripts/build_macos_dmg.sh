#!/bin/bash

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Building macOS DMG Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 版本号（从 pubspec.yaml 读取或手动指定）
VERSION="1.0.0"

echo ""
echo "📦 Step 1: Cleaning previous builds..."
flutter clean

echo ""
echo "🔨 Step 2: Building macOS app (Release)..."
flutter build macos --release

echo ""
echo "📂 Step 3: Checking build output..."
APP_PATH="build/macos/Build/Products/Release/omnicast.app"
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: App not found at $APP_PATH"
    exit 1
fi

echo "✅ App found: $APP_PATH"

echo ""
echo "📦 Step 4: Creating DMG installer..."

cd build/macos/Build/Products/Release

# 检查是否安装了 create-dmg
if ! command -v create-dmg &> /dev/null; then
    echo "⚠️  create-dmg not found. Installing..."
    brew install create-dmg
fi

# 删除旧的 DMG（如果存在）
DMG_NAME="Omnicast-Wallet-v${VERSION}.dmg"
if [ -f "$DMG_NAME" ]; then
    rm "$DMG_NAME"
    echo "🗑️  Removed old DMG"
fi

# 创建 DMG
create-dmg \
  --volname "Omnicast Wallet" \
  --volicon "omnicast.app/Contents/Resources/AppIcon.icns" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "omnicast.app" 175 120 \
  --hide-extension "omnicast.app" \
  --app-drop-link 425 120 \
  --no-internet-enable \
  "$DMG_NAME" \
  "omnicast.app"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ DMG created successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📍 Location: build/macos/Build/Products/Release/$DMG_NAME"
echo ""
echo "📊 File size:"
du -h "$DMG_NAME"
echo ""
echo "🎉 Done! You can now distribute this DMG file."
echo ""
