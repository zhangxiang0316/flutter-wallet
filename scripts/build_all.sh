#!/bin/bash

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Building All Platforms"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 版本号
VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | sed 's/+.*//')

echo ""
echo "📦 Version: $VERSION"
echo ""
echo "Will build:"
echo "  ✅ Android APK"
echo "  ✅ Android App Bundle (AAB)"
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "  ✅ macOS DMG"
    echo "  ✅ macOS ZIP"
    echo "  ⚠️  iOS IPA (requires manual steps)"
else
    echo "  ⏭️  macOS (skipped - not on macOS)"
    echo "  ⏭️  iOS (skipped - not on macOS)"
fi
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Build cancelled"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📱 Building Android..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Android APK
./scripts/build_android.sh

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Building Android App Bundle..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Android App Bundle
./scripts/build_android_bundle.sh

# macOS and iOS (only on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "💻 Building macOS..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # macOS ZIP
    ./scripts/build_macos_zip.sh

    # macOS DMG (if create-dmg is available)
    if command -v create-dmg &> /dev/null; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "💿 Building macOS DMG..."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        ./scripts/build_macos_dmg.sh
    else
        echo ""
        echo "⚠️  Skipping DMG (create-dmg not installed)"
        echo "   Install: brew install create-dmg"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🍎 iOS Build Notes"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "iOS requires manual steps in Xcode."
    echo ""
    read -p "Build iOS now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ./scripts/build_ios.sh
    else
        echo "⏭️  Skipping iOS build"
        echo "💡 To build later: ./scripts/build_ios.sh"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Build Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📦 Release files:"
echo ""
ls -lh releases/android/ 2>/dev/null || echo "   (no Android builds)"
if [[ "$OSTYPE" == "darwin"* ]]; then
    ls -lh releases/macos/ 2>/dev/null || true
    ls -lh releases/ios/ 2>/dev/null || true
    ls -lh build/macos/Build/Products/Release/*.dmg 2>/dev/null || true
    ls -lh build/macos/Build/Products/Release/*.zip 2>/dev/null || true
fi
echo ""
echo "🎉 All done!"
echo ""
