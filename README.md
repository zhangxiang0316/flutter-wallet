# 🚀 Omnicast - Multi-Chain Crypto Wallet

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A feature-rich, multi-chain cryptocurrency wallet built with Flutter, supporting Ethereum, BSC, Polygon, Arbitrum, Solana, and TRON networks.

[Features](#-features) • [Quick Start](#-quick-start) • [Screenshots](#-screenshots) • [Architecture](#-architecture) • [Contributing](#-contributing)

</div>

---

## ✨ Features

### 🔐 Phase 1: Secure Transaction Review
- **Smart Risk Detection** - Automatically identifies high-risk transactions
  - Large amount transfers
  - New address warnings
  - High gas fee alerts
- **Two-Step Confirmation** - Review transaction details before signing
- **Transaction Preview** - Clear display of from/to addresses, amounts, and fees

### ✍️ Phase 2: Message Signing
- **EIP-191 (personal_sign)** - Sign personal messages
- **EIP-712 (Typed Data)** - Sign structured data with clear type information
- **Solana Ed25519** - Native Solana message signing
- **TRON Signing** - TRON network message signing support
- **Beautiful UI** - User-friendly message signing confirmation interface

### 🌐 Phase 3: WalletConnect Integration
- **QR Code Scanning** - Connect to DApps by scanning QR codes
- **Real-time Connection** - Instant connection with web3 applications
- **Session Management** - View and manage connected DApps
- **Multiple Networks** - Support for EVM chains (Ethereum, BSC, Polygon, etc.)
- **Request Handling** - Handle transaction and signing requests from DApps

### 💎 Core Features
- **Multi-Chain Support** - EVM chains, Solana, and TRON in one wallet
- **HD Wallet** - BIP39/BIP44 compliant hierarchical deterministic wallet
- **Secure Storage** - Encrypted private key storage using flutter_secure_storage
- **Transaction History** - Fast transaction lookup with caching (10-100x faster)
- **Beautiful UI** - Modern, responsive design with smooth animations
- **GetX State Management** - Efficient and reactive state management

---

## 🚀 Quick Start

### Prerequisites

- Flutter 3.24 or higher
- Dart 3.0 or higher
- Android Studio / VS Code
- iOS: Xcode 15+ (for iOS development)
- Android: Android SDK 21+

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/omnicast.git
   cd omnicast
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate route files**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Set up WalletConnect (Required for DApp connections)**
   
   a. Get your Project ID:
   - Visit [WalletConnect Cloud](https://cloud.walletconnect.com/)
   - Create a new project
   - Copy your Project ID

   b. Update the code:
   ```dart
   // lib/wallet/services/walletconnect_service.dart (line 42)
   const projectId = 'YOUR_PROJECT_ID_HERE'; // Replace with your actual ID
   ```

5. **Run the app**
   ```bash
   flutter run
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
