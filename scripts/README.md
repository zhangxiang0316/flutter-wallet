# Build Scripts

自动化构建脚本，用于生成各平台的安装包。

## 📱 Android

Android 构建脚本会自动读取项目根目录的 `.env.local`，并通过 `--dart-define`
注入交易历史 API Key：

```bash
ETHERSCAN_API_KEY=your_etherscan_v2_key
TRONGRID_API_KEY=your_trongrid_key
```

如果 `.env.local` 不存在，脚本仍会继续构建，但 EVM/TRON 交易历史会退回公共数据源，
Arbitrum 等链的历史记录可能变慢或不完整。

### APK（直接安装）
```bash
./scripts/build_android.sh
```

生成文件：`releases/android/Omnicast-Wallet-vX.X.X.apk`

**用途**：
- ✅ 直接安装到设备
- ✅ 分发给测试用户
- ✅ 第三方应用商店

### App Bundle（Google Play）
```bash
./scripts/build_android_bundle.sh
```

生成文件：`releases/android/Omnicast-Wallet-vX.X.X.aab`

**用途**：
- ✅ 上传到 Google Play Console
- ✅ 自动优化 APK 大小
- ✅ 支持动态交付

---

## 🍎 iOS

```bash
./scripts/build_ios.sh
```

**要求**：
- macOS 系统
- 已安装 Xcode
- Apple Developer 账号
- 有效的签名证书

**步骤**：
1. 脚本准备构建环境
2. 手动在 Xcode 中创建 Archive
3. 导出 IPA 文件

**用途**：
- ✅ TestFlight 测试
- ✅ Ad Hoc 分发
- ✅ 上传 App Store

---

## 💻 macOS

### ZIP 压缩包（推荐快速测试）
```bash
./scripts/build_macos_zip.sh
```

生成文件：`build/macos/Build/Products/Release/Omnicast-Wallet-vX.X.X-macos.zip`

**优点**：
- ✅ 快速简单
- ✅ 无需额外工具
- ✅ 适合开发测试

### DMG 安装包（推荐正式发布）
```bash
./scripts/build_macos_dmg.sh
```

**前置条件**：
```bash
brew install create-dmg
```

生成文件：`build/macos/Build/Products/Release/Omnicast-Wallet-vX.X.X.dmg`

**优点**：
- ✅ 专业安装体验
- ✅ 拖拽安装界面
- ✅ 用户熟悉的方式

---

## 🚀 一键构建所有平台

```bash
./scripts/build_all.sh
```

自动构建：
- Android APK
- Android App Bundle
- macOS ZIP
- macOS DMG（如果已安装 create-dmg）
- iOS（需要手动完成 Xcode 步骤）

---

## 📊 构建产物

```
releases/
├── android/
│   ├── Omnicast-Wallet-v1.0.0.apk
│   └── Omnicast-Wallet-v1.0.0.aab
├── ios/
│   └── Omnicast-Wallet-v1.0.0.ipa
└── macos/
    ├── Omnicast-Wallet-v1.0.0.dmg
    └── Omnicast-Wallet-v1.0.0-macos.zip
```

---

## 🔐 代码签名

### Android
使用项目配置的签名密钥（如果有）。

未签名的 APK 仍可安装，但会提示"未知来源"。

### iOS
**必须**有 Apple Developer 账号和证书。

在 Xcode 中配置：
1. Signing & Capabilities
2. 选择 Team
3. 自动管理签名

### macOS
**可选**。未签名的应用：
- 用户需要右键 → 打开
- 或在系统偏好设置中允许

有开发者账号可以签名：
```bash
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name" \
  path/to/app
```

---

## 💡 Tips

### 本地调试注入 API Key

```bash
./scripts/flutter_run_with_env.sh
```

该脚本读取 `.env.local` 并传入：

```bash
--dart-define=ETHERSCAN_API_KEY=...
--dart-define=TRONGRID_API_KEY=...
--dart-define=HELIUS_API_KEY=...
```

修改 `.env.local` 后需要完全重启应用，Hot Reload 不会重新读取编译参数。

### 减小包体积
```bash
# 分离调试信息
flutter build apk --release --split-debug-info=debug-info/

# 代码混淆
flutter build apk --release --obfuscate --split-debug-info=debug-info/
```

### 多架构构建
```bash
# Android 分架构 APK
flutter build apk --release --split-per-abi

# 生成多个 APK：
# - app-armeabi-v7a-release.apk
# - app-arm64-v8a-release.apk
# - app-x86_64-release.apk
```

### 构建模式
```bash
# Debug（开发调试）
flutter build apk --debug

# Profile（性能分析）
flutter build apk --profile

# Release（正式发布）
flutter build apk --release
```

---

## 🐛 常见问题

### Android 构建失败
```bash
# 清理并重试
flutter clean
flutter pub get
./scripts/build_android.sh
```

### iOS 签名错误
1. 检查 Bundle ID 是否匹配
2. 确认 Provisioning Profile 有效
3. 在 Xcode 中重新选择 Team

### macOS Gatekeeper 阻止
用户安装时：
1. 右键点击应用
2. 选择「打开」
3. 点击「打开」确认

---

## 📖 更多信息

- [Flutter 官方文档](https://docs.flutter.dev/deployment)
- [Android 发布指南](https://docs.flutter.dev/deployment/android)
- [iOS 发布指南](https://docs.flutter.dev/deployment/ios)
- [macOS 发布指南](https://docs.flutter.dev/deployment/macos)
