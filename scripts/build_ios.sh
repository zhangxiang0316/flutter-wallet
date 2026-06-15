#!/bin/bash

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🍎 Building iOS IPA"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 版本号
VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | sed 's/+.*//')

echo ""
echo "📦 Version: $VERSION"

echo ""
echo "⚠️  Prerequisites:"
echo "   - macOS required"
echo "   - Xcode installed"
echo "   - Apple Developer account"
echo "   - Valid provisioning profile"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Build cancelled"
    exit 1
fi

echo ""
echo "📦 Step 1: Cleaning previous builds..."
flutter clean

echo ""
echo "🔨 Step 2: Getting dependencies..."
flutter pub get

echo ""
echo "🔨 Step 3: Building iOS app (Release)..."
flutter build ios --release --no-codesign

echo ""
echo "📂 Step 4: Build complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📱 Manual Steps in Xcode:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Open Xcode:"
echo "   $ open ios/Runner.xcworkspace"
echo ""
echo "2. In Xcode:"
echo "   - Select 'Any iOS Device' as target"
echo "   - Product → Archive"
echo "   - Wait for archive to complete"
echo ""
echo "3. In Organizer window:"
echo "   - Select the archive"
echo "   - Click 'Distribute App'"
echo "   - Choose distribution method:"
echo "     • App Store Connect (for App Store)"
echo "     • Ad Hoc (for testing)"
echo "     • Development (for development)"
echo "     • Enterprise (for enterprise)"
echo ""
echo "4. Follow the wizard:"
echo "   - Select distribution options"
echo "   - Sign with your certificate"
echo "   - Export IPA"
echo ""
echo "💡 Tips:"
echo "   - For testing: Choose 'Ad Hoc' distribution"
echo "   - For App Store: Choose 'App Store Connect'"
echo "   - Save IPA to: releases/ios/"
echo ""
echo "🔐 Signing:"
echo "   Make sure you have:"
echo "   - Valid Apple Developer certificate"
echo "   - Provisioning profile for your Bundle ID"
echo "   - Set Team in Xcode (Signing & Capabilities)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 询问是否打开 Xcode
echo ""
read -p "Open Xcode now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open ios/Runner.xcworkspace
    echo ""
    echo "✅ Xcode opened!"
    echo "📖 Follow the steps above to create IPA"
else
    echo ""
    echo "💡 To open later:"
    echo "   $ open ios/Runner.xcworkspace"
fi

echo ""
echo "🎉 Build preparation complete!"
echo ""
