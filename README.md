# Flutter Wallet

一个基于 Flutter + GetX 的多链本地热钱包。项目当前定位为测试和学习用途，覆盖钱包创建/导入、多链资产、转账收款、交易历史、网络管理、资产显示控制、主题和语言切换等核心能力。

English: [README_EN.md](./README_EN.md)

## 功能清单

### 钱包与安全

- 创建钱包：生成 12 位助记词。
- 导入钱包：支持助记词和私钥导入。
- 多钱包管理：支持新增、切换、重命名和删除钱包。
- 多链地址：同一钱包派生 EVM、TRON、Solana 地址。
- 本地加密：助记词和私钥使用钱包密码加密后存储在设备本地。
- 敏感操作校验：查看私钥/助记词、转账签名等操作需要密码验证。
- 密码缓存设置：支持配置密码缓存时长。
- 备份状态：记录助记词是否已备份，并在钱包详情中展示。

### 支持的链

内置链：

- Ethereum
- BNB Smart Chain
- Arbitrum
- X Layer
- Solana
- TRON

网络管理：

- 支持编辑内置链 RPC 列表。
- 支持添加自定义 EVM 网络。
- 支持 RPC 延迟检测、可用性检测和手动测速。
- 支持启用、禁用、编辑和删除自定义网络。

### 资产与余额

- 首页按链展示资产。
- 支持原生币和默认 Token 余额查询。
- 支持添加自定义 Token。
- 自定义 EVM Token 自动读取 symbol/name/decimals。
- 支持 Token logo 和热门 Token 快速添加。
- 支持隐藏 0 余额资产。
- 支持本地余额缓存，先显示缓存再后台刷新。
- 支持 USD 估值，价格源包含 Binance、OKX、CoinGecko、DeFiLlama、CoinPaprika、CryptoCompare 等兜底路径。

### 转账与收款

- 支持 EVM 原生币和 ERC20 转账。
- 支持 TRON TRX 和 TRC20 转账。
- 支持 Solana SOL 和 SPL Token 转账。
- 支持收款二维码和地址复制。
- 支持扫码填充转账地址。
- 转账前进行安全检查：地址格式、金额、余额、手续费、大额转账、新地址等。
- 转账提交后记录本地 pending 交易，并支持交易状态刷新。
- 交易详情支持跳转区块浏览器。

### 交易历史

- 默认每页加载 10 条，支持加载更多。
- 支持本地缓存，优先展示缓存记录。
- 支持本地 pending 交易与链上记录合并展示。
- EVM 数据源：
  - BSC 和 Arbitrum 优先使用 Moralis。
  - Ethereum 支持 Etherscan V2 和 Blockscout 兜底。
  - X Layer Token 交易通过 RPC logs 分页兜底；X Layer 原生 OKB 交易需要 indexer，普通 RPC 无法完整查询。
- Solana 数据源：
  - 配置 Helius 后优先使用 Helius Enhanced Transactions。
  - 支持 SOL 和 SPL Token。
  - 支持 `nativeTransfers`、`tokenTransfers` 以及 `accountData` 余额变化解析。
  - Helius 不可用时回退 Solana RPC。
- TRON 数据源：
  - 配置 TronGrid API Key 后请求会携带 `TRON-PRO-API-KEY`。
  - 支持 TRX 和 TRC20 历史记录。

### 用户体验

- 中文和英文国际化。
- 亮色/暗色主题切换。
- 地址簿管理。
- 内置区块浏览器 WebView，支持返回、前进、刷新、复制链接和外部浏览器打开。
- 资产显示管理。
- 网络管理页面。

## API Key 与环境变量

交易历史在没有 API Key 时会尽量走公共 RPC 或公开 Explorer 兜底，但稳定性和完整性会下降。建议开发和测试时配置 `.env.local`。

### 创建本地配置

```bash
cp .env.example .env.local
```

`.env.local` 支持：

```bash
ETHERSCAN_API_KEY=your_etherscan_v2_key
TRONGRID_API_KEY=your_trongrid_key
HELIUS_API_KEY=your_helius_key
MORALIS_API_KEY=your_moralis_key
```

### 变量用途和申请地址

| 变量 | 用途 | 申请位置 |
|------|------|----------|
| `ETHERSCAN_API_KEY` | Ethereum 等 EVM Explorer API；Etherscan V2 使用同一个 key 通过 `chainid` 区分多链 | Etherscan 注册账号后，在 API Dashboard 创建 key：https://etherscan.io/myapikey |
| `TRONGRID_API_KEY` | TRON/TRC20 历史记录和 TRON API 稳定访问 | TronGrid Dashboard：https://www.trongrid.io |
| `HELIUS_API_KEY` | Solana/SPL 交易历史，优先使用 Helius Enhanced Transactions | Helius Dashboard：https://dashboard.helius.dev |
| `MORALIS_API_KEY` | BSC 和 Arbitrum 原生交易、ERC20/BEP20 Token 历史记录 | Moralis Dashboard：https://admin.moralis.com |

### 运行时注入

推荐使用项目脚本读取 `.env.local`：

```bash
scripts/flutter_run_with_env.sh
```

Android 构建脚本也会读取 `.env.local`：

```bash
scripts/build_android.sh
scripts/build_android_bundle.sh
```

如果你直接在 Android Studio 点 Run，`.env.local` 不会自动生效，需要在 Run Configuration 的 Additional run args 中手动添加：

```bash
--dart-define=ETHERSCAN_API_KEY=...
--dart-define=TRONGRID_API_KEY=...
--dart-define=HELIUS_API_KEY=...
--dart-define=MORALIS_API_KEY=...
```

注意：

- `.env.local` 已被 `.gitignore` 忽略，不要提交真实 key。
- 不要把真实 API Key 写入 Dart 源码、README 或测试文件。
- `String.fromEnvironment` 只在启动/编译时读取，修改 `.env.local` 后必须完全重启或重新打包，Hot Reload 不会更新 key。

## 快速开始

### 环境要求

- Flutter SDK 3.24 或更高版本
- Dart SDK 3.5 或更高版本
- Android Studio 或 Xcode

### 安装依赖

```bash
flutter pub get
```

### 生成代码

```bash
flutter pub run build_runner build
flutter pub run intl_utils:generate
```

### 运行

```bash
flutter run

# 推荐：带 API key 注入
scripts/flutter_run_with_env.sh
```

### 构建

```bash
# Android APK
scripts/build_android.sh

# Android App Bundle
scripts/build_android_bundle.sh

# iOS
flutter build ipa --release
```

## 项目结构

```text
lib/
├── base/                         # BaseController / BasePage
├── common/                       # 通用主题、网络和模型
├── generated/                    # 生成的路由和国际化代码
├── l10n/                         # ARB 国际化源文件
├── page/                         # 页面、Controller、Widget
├── utils/                        # 通用工具
├── widget/                       # 通用组件
└── wallet/
    ├── constants/                # 钱包常量
    ├── models/                   # 钱包和链模型
    ├── utils/                    # 钱包工具
    └── services/
        ├── balance/              # 余额查询 part 实现
        ├── config/               # 链配置、地址簿、自定义资产、显示设置
        ├── crypto/               # 密钥派生和安全存储
        ├── transaction/          # 交易缓存、区块浏览器、交易状态
        ├── transaction_history/  # 交易历史 Provider
        ├── transfer/             # 转账 part 实现
        ├── chain_balance_service.dart
        ├── wallet_repository.dart
        ├── wallet_transfer_service.dart
        └── wallet_transaction_history_service.dart
```

## 常用命令

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter test test/wallet_crypto_service_test.dart
flutter pub run build_runner build
flutter pub run intl_utils:generate
```

## 测试

当前测试重点覆盖：

- 钱包密钥派生和地址生成
- 地址簿
- 助记词备份状态
- 区块浏览器链接
- 余额与自定义资产逻辑
- 转账编码和提交逻辑
- BSC / Arbitrum / X Layer / TRON / Solana 交易历史 Provider

## 安全说明

这是本地热钱包项目，不等同于硬件钱包或多签钱包。开发和测试时请注意：

- 不要提交真实私钥、助记词、API Key 或生产钱包数据。
- 不要在日志中打印私钥、助记词、签名材料。
- 转账相关代码属于高风险逻辑，修改后必须重点验证地址、金额、链选择、手续费和错误处理。
- 建议使用测试钱包和少量资金验证。

## 当前限制

- 动态添加网络目前只支持 EVM 兼容链。
- Solana/TRON 作为内置链存在，暂不支持用户动态添加同类网络。
- X Layer 原生 OKB 历史记录缺少稳定 indexer，普通 RPC 无法完整查询地址历史。
- 资产估值和交易历史依赖第三方 API，可用性受 API 限流、套餐和服务状态影响。

## 截图

截图位于 `docs/` 目录：

| 首页 | 钱包切换 | 钱包管理 | 转账 |
|------|----------|----------|------|
| <img src="docs/1.jpg" width="180"> | <img src="docs/2.jpg" width="180"> | <img src="docs/3.jpg" width="180"> | <img src="docs/4.jpg" width="180"> |

| 收款 | 交易历史 | 设置 | 资产管理 |
|------|----------|------|----------|
| <img src="docs/5.jpg" width="180"> | <img src="docs/6.jpg" width="180"> | <img src="docs/7.jpg" width="180"> | <img src="docs/8.jpg" width="180"> |

## 许可证

本项目仅用于学习和研究。
