#!/bin/bash

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Building macOS ZIP Distribution"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 版本号
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
echo "📦 Step 4: Creating ZIP archive..."

cd build/macos/Build/Products/Release

ZIP_NAME="Omnicast-Wallet-v${VERSION}-macos.zip"

# 删除旧的 ZIP（如果存在）
if [ -f "$ZIP_NAME" ]; then
    rm "$ZIP_NAME"
    echo "🗑️  Removed old ZIP"
fi

# 创建 ZIP（使用 ditto 保留资源 fork）
ditto -c -k --sequesterRsrc --keepParent "omnicast.app" "$ZIP_NAME"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ ZIP created successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📍 Location: build/macos/Build/Products/Release/$ZIP_NAME"
echo ""
echo "📊 File size:"
du -h "$ZIP_NAME"
echo ""
echo "📖 Installation instructions for users:"
echo "   1. Download and unzip the file"
echo "   2. Drag 'omnicast.app' to Applications folder"
echo "   3. Right-click and select 'Open' (first time only)"
echo ""
echo "🎉 Done! You can now distribute this ZIP file."
echo ""
