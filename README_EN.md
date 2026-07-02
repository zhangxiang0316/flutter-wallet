# Flutter Wallet

[简体中文](./README.md) | English

Flutter Wallet is a Flutter + GetX multi-chain local hot wallet. It is currently intended for testing and learning, covering wallet creation/import, multi-chain assets, transfers, receiving, transaction history, network management, asset visibility, themes, and language switching.

## Feature List

### Wallet And Security

- Create wallets with a 12-word mnemonic.
- Import wallets by mnemonic or private key.
- Manage multiple wallets: add, switch, rename, and remove.
- Derive EVM, TRON, and Solana addresses from the same wallet.
- Store mnemonics and private keys locally after password-based encryption.
- Require password verification for sensitive operations such as viewing private keys, viewing mnemonics, and signing transfers.
- Password cache settings.
- Mnemonic backup status tracking.

### Supported Chains

Built-in chains:

- Ethereum
- BNB Smart Chain
- Arbitrum
- X Layer
- Solana
- TRON

Network management:

- Edit RPC lists for built-in chains.
- Add custom EVM networks.
- Check RPC latency and availability.
- Enable, disable, edit, and delete custom networks.

### Assets And Balances

- Display assets grouped by chain on the home page.
- Query native coin and default token balances.
- Add custom tokens.
- Auto-read EVM token metadata: symbol, name, and decimals.
- Support token logos and quick-add popular token lists.
- Hide zero-balance assets.
- Cache balances locally and refresh in the background.
- Display USD valuation with multiple price sources, including Binance, OKX, CoinGecko, DeFiLlama, CoinPaprika, and CryptoCompare.

### Transfers And Receiving

- EVM native coin and ERC20 transfers.
- TRON TRX and TRC20 transfers.
- Solana SOL and SPL token transfers.
- Receive address QR code and one-tap copy.
- QR scanning for recipient address input.
- Transfer safety checks: address format, amount, balance, fee, large transfer, and new recipient warning.
- Save local pending records after submission and refresh transaction status.
- Transaction detail page with block explorer entry.

### Transaction History

- Default page size is 10 records, with load-more support.
- Cache-first loading.
- Merge local pending records with remote on-chain records.
- EVM data sources:
  - BSC and Arbitrum prefer Moralis.
  - Ethereum supports Etherscan V2 and Blockscout fallback.
  - X Layer token history uses paged RPC logs as fallback; native OKB history needs an indexer because normal RPC cannot query complete address history.
- Solana data sources:
  - Helius Enhanced Transactions are preferred when `HELIUS_API_KEY` is configured.
  - Supports SOL and SPL tokens.
  - Parses `nativeTransfers`, `tokenTransfers`, and `accountData` balance changes.
  - Falls back to Solana RPC when Helius is unavailable.
- TRON data sources:
  - Requests include `TRON-PRO-API-KEY` when `TRONGRID_API_KEY` is configured.
  - Supports TRX and TRC20 history.

### User Experience

- Chinese and English localization.
- Light and dark themes.
- Address book.
- Embedded block explorer WebView with back, forward, refresh, copy link, and external browser opening.
- Asset visibility management.
- Network management page.

## API Keys And Environment Variables

Transaction history can fall back to public RPC or public explorers without API keys, but stability and completeness will be lower. For development and testing, configure `.env.local`.

### Create Local Config

```bash
cp .env.example .env.local
```

Supported variables:

```bash
ETHERSCAN_API_KEY=your_etherscan_v2_key
TRONGRID_API_KEY=your_trongrid_key
HELIUS_API_KEY=your_helius_key
MORALIS_API_KEY=your_moralis_key
```

### Where To Get Keys

| Variable | Usage | Where to apply |
|----------|-------|----------------|
| `ETHERSCAN_API_KEY` | Ethereum and other EVM explorer APIs. Etherscan V2 uses one key and the `chainid` parameter for multiple chains. | Create an Etherscan account and generate a key in the API Dashboard: https://etherscan.io/myapikey |
| `TRONGRID_API_KEY` | Stable access for TRON/TRC20 history and TRON APIs. | TronGrid Dashboard: https://www.trongrid.io |
| `HELIUS_API_KEY` | Solana/SPL transaction history through Helius Enhanced Transactions. | Helius Dashboard: https://dashboard.helius.dev |
| `MORALIS_API_KEY` | BSC and Arbitrum native transactions plus ERC20/BEP20 token history. | Moralis Dashboard: https://admin.moralis.com |

### Runtime Injection

Recommended local run:

```bash
scripts/flutter_run_with_env.sh
```

Android build scripts also read `.env.local`:

```bash
scripts/build_android.sh
scripts/build_android_bundle.sh
```

If you run directly from Android Studio, `.env.local` is not loaded automatically. Add these to Run Configuration -> Additional run args:

```bash
--dart-define=ETHERSCAN_API_KEY=...
--dart-define=TRONGRID_API_KEY=...
--dart-define=HELIUS_API_KEY=...
--dart-define=MORALIS_API_KEY=...
```

Notes:

- `.env.local` is ignored by Git. Do not commit real keys.
- Do not write real API keys in Dart source code, README files, or tests.
- `String.fromEnvironment` is read at launch/build time. After changing `.env.local`, fully restart the app or rebuild it; Hot Reload will not update keys.

## Quick Start

### Requirements

- Flutter SDK 3.24 or later
- Dart SDK 3.5 or later
- Android Studio or Xcode

### Install Dependencies

```bash
flutter pub get
```

### Generate Code

```bash
flutter pub run build_runner build
flutter pub run intl_utils:generate
```

### Run

```bash
flutter run

# Recommended: inject API keys from .env.local
scripts/flutter_run_with_env.sh
```

### Build

```bash
# Android APK
scripts/build_android.sh

# Android App Bundle
scripts/build_android_bundle.sh

# iOS
flutter build ipa --release
```

## Project Structure

```text
lib/
├── base/                         # BaseController / BasePage
├── common/                       # Shared theme, network, and models
├── generated/                    # Generated routes and i18n code
├── l10n/                         # ARB localization source files
├── page/                         # Pages, controllers, widgets
├── utils/                        # Shared utilities
├── widget/                       # Shared widgets
└── wallet/
    ├── constants/                # Wallet constants
    ├── models/                   # Wallet and chain models
    ├── utils/                    # Wallet utilities
    └── services/
        ├── balance/              # Balance query part implementations
        ├── config/               # Chain config, address book, custom assets, visibility
        ├── crypto/               # Key derivation and secure storage
        ├── transaction/          # Transaction cache, block explorer, transaction status
        ├── transaction_history/  # Transaction history providers
        ├── transfer/             # Transfer part implementations
        ├── chain_balance_service.dart
        ├── wallet_repository.dart
        ├── wallet_transfer_service.dart
        └── wallet_transaction_history_service.dart
```

## Common Commands

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter test test/wallet_crypto_service_test.dart
flutter pub run build_runner build
flutter pub run intl_utils:generate
```

## Tests

Current tests mainly cover:

- Wallet key derivation and address generation
- Address book
- Mnemonic backup status
- Block explorer links
- Balance and custom asset logic
- Transfer encoding and submission logic
- BSC / Arbitrum / X Layer / TRON / Solana transaction history providers

## Security Notes

This is a local hot wallet project. It is not equivalent to a hardware wallet or a multi-signature wallet.

- Do not commit real private keys, mnemonics, API keys, or production wallet data.
- Do not print private keys, mnemonics, or signing material in logs.
- Transfer code is high-risk. Carefully verify address, amount, chain selection, fees, and error handling after changes.
- Use test wallets and small amounts for verification.

## Current Limitations

- Dynamically added networks currently support EVM-compatible chains only.
- Solana and TRON are built-in chains and cannot currently be added as custom network types.
- X Layer native OKB transaction history lacks a stable indexer; normal RPC cannot query complete address history.
- Asset valuation and transaction history depend on third-party APIs and can be affected by rate limits, plan restrictions, or provider incidents.

## Screenshots

Screenshots are stored in `docs/`:

| Home | Wallet Switch | Wallet Management | Transfer |
|------|---------------|-------------------|----------|
| <img src="docs/1.jpg" width="180"> | <img src="docs/2.jpg" width="180"> | <img src="docs/3.jpg" width="180"> | <img src="docs/4.jpg" width="180"> |

| Receive | Transaction History | Settings | Asset Management |
|---------|---------------------|----------|------------------|
| <img src="docs/5.jpg" width="180"> | <img src="docs/6.jpg" width="180"> | <img src="docs/7.jpg" width="180"> | <img src="docs/8.jpg" width="180"> |

## License

This project is for learning and research purposes only.
