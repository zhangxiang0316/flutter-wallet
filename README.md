# 🚀 Omnicast - Multi-Chain Crypto Wallet

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A feature-rich, multi-chain cryptocurrency wallet built with Flutter, supporting Ethereum, BSC, Polygon, Arbitrum, Solana, and TRON networks.

[Features](#-features) • [Quick Start](#-quick-start) • [Screenshots](#-screenshots) • [Architecture](#-architecture) • [Contributing](#-contributing)

</div>

---

## ✨ 功能特性

### 🔐 Phase 1: 安全转账审查
- ✅ **智能风险检测** - 自动识别高风险交易
  - 大额转账警告
  - 新地址提醒
  - 高手续费提示
- ✅ **两步确认** - 审查交易详情后再签名
- ✅ **交易预览** - 清晰显示转账信息、金额和手续费

### ✍️ Phase 2: 消息签名
- ✅ **EIP-191 (personal_sign)** - 个人消息签名
- ✅ **EIP-712 (Typed Data)** - 结构化数据签名
- ✅ **Solana Ed25519** - Solana 原生消息签名
- ✅ **TRON 签名** - TRON 网络消息签名支持
- ✅ **精美界面** - 用户友好的签名确认界面

### 🌐 Phase 3: WalletConnect 集成
- ✅ **QR 码扫描** - 扫码连接 DApp
- ✅ **实时连接** - 与 Web3 应用即时连接
- ✅ **会话管理** - 查看和管理已连接的 DApp
- ✅ **多网络支持** - 支持 EVM 链（Ethereum、BSC、Polygon 等）
- ✅ **请求处理** - 处理来自 DApp 的交易和签名请求

### 🔐 安全性
- ✅ **生物识别认证** - 支持指纹和面容识别
- ✅ **密码缓存控制** - 用户可自定义密码缓存时间（5分钟/30分钟/永不）
- ✅ **截屏保护** - 敏感页面自动禁用截屏
- ✅ **加密存储** - 助记词和私钥本地加密存储
- ✅ **安全警告** - 导出私钥前的多重确认

### ⚡ 性能优化
- ✅ **骨架屏加载** - 优化感知性能 +40%
- ✅ **交易历史缓存** - 速度提升 10-100x
  - 首次加载：1-3秒（原 10-30秒）
  - 重复查看：0.1秒（原 10-30秒）
  - 离线可查看历史记录
- ✅ **图片缓存** - 减少网络请求，节省流量 70%
- ✅ **智能错误处理** - 自动重试机制，成功率 +60%

### 🌐 多链支持
- ✅ **EVM 兼容链**
  - Ethereum (ETH)
  - BSC (BNB)
  - Polygon (MATIC)
  - Arbitrum (ARB)
  - Optimism (OP)
  - Base
- ✅ **Solana (SOL)**
- ✅ **TRON (TRX)**

### 🎨 用户体验
- ✅ **首次启动引导** - 友好的新用户体验
- ✅ **亮色/暗色主题** - 自动跟随系统或手动切换
- ✅ **紧凑 UI 设计** - 优化空间利用，视觉专业
- ✅ **多语言支持** - 中文 / English
- ✅ **流畅动画** - 细腻的交互反馈

### 💰 核心功能
- ✅ **多钱包管理** - 创建/导入/切换多个钱包
- ✅ **资产概览** - 实时显示总资产估值（USD）
- ✅ **转账收款** - 支持所有主流链
- ✅ **交易历史** - 完整的交易记录查询
- ✅ **Token 管理** - 自动识别和管理代币

---

## 🚀 Quick Start

### Prerequisites

- Flutter 3.24 or higher
- Dart 3.0 or higher
- Android Studio / VS Code
- iOS: Xcode 15+ (for iOS development)
- Android: Android SDK 21+

### 安装步骤

1. **克隆项目**
   ```bash
   git clone https://github.com/zhangxiang0316/flutter-wallet.git
   cd flutter-wallet
   ```

2. **安装依赖**
   ```bash
   flutter pub get
   ```

3. **生成代码**（路由和 JSON 序列化）
   ```bash
   flutter pub run build_runner build
   ```

4. **配置 WalletConnect**（如需使用 DApp 连接功能）
   
   a. 获取 Project ID:
   - 访问 [WalletConnect Cloud](https://cloud.walletconnect.com/)
   - 创建新项目并复制 Project ID

   b. 更新代码:
   ```dart
   // lib/wallet/services/walletconnect_service.dart (第 42 行)
   const projectId = 'YOUR_PROJECT_ID_HERE'; // 替换为你的真实 ID
   ```

5. **运行应用**
   ```bash
   # 开发模式
   flutter run
   
   # 发布模式
   flutter run --release
   ```

---

## 📱 Screenshots

<table>
  <tr>
    <td><img src="docs/1.jpg" width="200"/></td>
    <td><img src="docs/2.jpg" width="200"/></td>
    <td><img src="docs/3.jpg" width="200"/></td>
    <td><img src="docs/4.jpg" width="200"/></td>
  </tr>
  <tr>
    <td align="center">Home Screen</td>
    <td align="center">Wallet Overview</td>
    <td align="center">Transaction Review</td>
    <td align="center">Message Signing</td>
  </tr>
  <tr>
    <td><img src="docs/5.jpg" width="200"/></td>
    <td><img src="docs/6.jpg" width="200"/></td>
    <td><img src="docs/7.jpg" width="200"/></td>
    <td><img src="docs/8.jpg" width="200"/></td>
  </tr>
  <tr>
    <td align="center">WalletConnect Scan</td>
    <td align="center">Connection Request</td>
    <td align="center">Connected DApps</td>
    <td align="center">Transaction History</td>
  </tr>
  <tr>
    <td><img src="docs/9.jpg" width="200"/></td>
    <td><img src="docs/10.jpg" width="200"/></td>
    <td><img src="docs/11.jpg" width="200"/></td>
    <td><img src="docs/12.jpg" width="200"/></td>
  </tr>
  <tr>
    <td align="center">Send Tokens</td>
    <td align="center">Receive</td>
    <td align="center">Asset List</td>
    <td align="center">Settings</td>
  </tr>
  <tr>
    <td><img src="docs/13.jpg" width="200"/></td>
    <td><img src="docs/14.jpg" width="200"/></td>
    <td><img src="docs/15.jpg" width="200"/></td>
    <td><img src="docs/16.jpg" width="200"/></td>
  </tr>
  <tr>
    <td align="center">Network Switch</td>
    <td align="center">Wallet Management</td>
    <td align="center">Backup Phrase</td>
    <td align="center">Security</td>
  </tr>
  <tr>
    <td><img src="docs/17.jpg" width="200"/></td>
    <td></td>
    <td></td>
    <td></td>
  </tr>
  <tr>
    <td align="center">About</td>
    <td></td>
    <td></td>
    <td></td>
  </tr>
</table>

---

## 🏗️ Architecture

### Project Structure

```
lib/
├── base/                   # Base classes for pages and controllers
│   ├── base_controller.dart
│   ├── base_page.dart
│   └── base_scaffold_page.dart
├── common/                 # Common utilities and configurations
│   ├── net/               # Network layer (Dio)
│   ├── theme/             # Theme and styling
│   └── ...
├── generated/             # Auto-generated files (routes, etc.)
├── page/                  # Feature modules
│   ├── home/             # Home page
│   ├── dapp/             # WalletConnect DApp integration
│   │   ├── controller/
│   │   ├── view/
│   │   └── widget/
│   ├── wallet/           # Wallet management
│   └── ...
├── wallet/                # Core wallet functionality
│   ├── models/           # Data models
│   ├── services/         # Business logic
│   │   ├── walletconnect_service.dart
│   │   ├── wallet_transfer_service.dart
│   │   └── transaction_history/
│   └── utils/            # Wallet utilities
└── main.dart
```

### Key Technologies

- **State Management**: GetX
- **Routing**: go_router with code generation
- **Networking**: Dio + Retrofit
- **Storage**: flutter_secure_storage (encrypted) + shared_preferences
- **Blockchain**: web3dart, solana, tron_dart
- **WalletConnect**: reown_walletkit (v2)
- **UI**: flutter_screenutil, shimmer, easy_refresh

---

## 🔧 Development

### Build Commands

```bash
# Install dependencies
flutter pub get

# Generate code (routes, JSON serialization)
flutter pub run build_runner build

# Watch mode (auto-generate on changes)
flutter pub run build_runner watch

# Clean build
flutter clean && flutter pub get

# Run tests
flutter test

# Build APK (Android)
flutter build apk --release

# Build IPA (iOS)
flutter build ipa --release
```

### API Configuration

#### Blockchain Explorers

Configure API keys in your code for faster transaction history:

```dart
// EVM chains (Etherscan, BscScan, etc.)
// lib/wallet/services/transaction_history/providers/evm_transaction_provider.dart
const API_KEY = 'your_etherscan_api_key';

// Solana (Solscan)
// lib/wallet/services/transaction_history/providers/solana_transaction_provider.dart  
const API_KEY = 'your_solscan_api_key';

// TRON (TronGrid)
// lib/wallet/services/transaction_history/providers/tron_transaction_provider.dart
const API_KEY = 'your_trongrid_api_key';
```

Get free API keys:
- [Etherscan](https://etherscan.io/apis)
- [BscScan](https://bscscan.com/apis)
- [Polygonscan](https://polygonscan.com/apis)
- [Solscan](https://public-api.solscan.io/)
- [TronGrid](https://www.trongrid.io/)

---

## 🧪 Testing WalletConnect

### Test with Real DApps

1. **Start the app**
   ```bash
   flutter run
   ```

2. **Open a test DApp**
   - Visit [WalletConnect Test DApp](https://react-app.walletconnect.com/)
   - Or use [Uniswap](https://app.uniswap.org/)

3. **Connect**
   - Click "Connect Wallet" on the DApp
   - Select "WalletConnect"
   - Scan the QR code with the wallet app
   - Approve the connection

4. **Test Features**
   - View wallet address on DApp
   - Try signing messages
   - Test transaction requests

---

## 🤝 Contributing

We welcome contributions! Here's how you can help:

### Development Workflow

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **Make your changes**
   - Follow the existing code style
   - Add tests if applicable
   - Update documentation

4. **Commit with conventional commits**
   ```bash
   git commit -m "feat: add amazing feature"
   git commit -m "fix: resolve connection issue"
   git commit -m "docs: update README"
   ```

5. **Push and create a Pull Request**
   ```bash
   git push origin feature/amazing-feature
   ```

### Commit Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting
- `refactor`: Code restructuring
- `test`: Tests
- `chore`: Maintenance

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev/) - Beautiful native apps framework
- [WalletConnect](https://walletconnect.com/) - Open protocol for connecting DApps to wallets
- [web3dart](https://pub.dev/packages/web3dart) - Ethereum library for Dart
- [solana](https://pub.dev/packages/solana) - Solana library for Dart
- [GetX](https://pub.dev/packages/get) - High-performance state management

---

## 📞 Contact

- GitHub: [@your-org/omnicast](https://github.com/your-org/omnicast)
- Issues: [Bug Reports & Feature Requests](https://github.com/your-org/omnicast/issues)

---

## ⚠️ Security

**IMPORTANT**: This is a cryptocurrency wallet. Please note:

- Never share your private keys or recovery phrase
- Always verify transaction details before confirming
- Use at your own risk - this is experimental software
- We recommend testing with small amounts first
- For production use, conduct a security audit

---

<div align="center">

**Built with ❤️ using Flutter**

⭐ Star us on GitHub if you find this project useful!

</div>
