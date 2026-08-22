# Flutter Wallet

一个基于 Flutter + GetX 的多链本地热钱包。项目当前定位为测试和学习用途，覆盖钱包创建/导入、多链资产、转账收款、交易历史、网络管理、资产显示控制、主题和语言切换等核心能力。

English: [README_EN.md](./README_EN.md)

## 最近更新

- 首页从“按网络分组”升级为“按代币聚合”：同一可信代币会汇总所有网络的数量和 USD 价值，点击后可查看各网络明细。
- 首页聚合改为数据驱动；新增网络和资产可通过 `canonicalTokenId` 进入现有代币组合，不再依赖固定链数量或硬编码列表。
- 新增 Bitcoin、Sui、Aptos、Base、Polygon 和 Avalanche C-Chain 主网支持，补齐地址派生、余额、转账、历史记录和区块浏览器能力。
- 首页余额加载采用缓存优先、链级并发、渐进式刷新和 EVM JSON-RPC 批量查询；无缓存时展示 Shimmer 骨架屏。
- 更新首页资产 Hero 卡片、钱包切换入口以及收款/转账快捷操作区，并清理未使用代码和依赖。

## 功能清单

### 钱包与安全

- 创建钱包：生成由 12 个英文单词组成的助记词。
- 导入钱包：支持助记词和私钥导入。
- 多钱包管理：支持新增、切换、重命名和删除钱包。
- 多链地址：同一钱包派生 EVM、TRON、Solana、Bitcoin、Sui 和 Aptos 地址。
- 本地加密：助记词和私钥使用钱包密码加密后存储在设备本地。
- 敏感操作校验：查看私钥/助记词、转账签名等操作需要密码验证。
- 密码缓存设置：支持配置密码缓存时长。
- 备份状态：记录助记词是否已备份，并在钱包详情中展示。

### 支持的链

当前内置 12 条主网：

| 网络 | 类型 | 原生资产 | 主要资产能力 |
|------|------|----------|--------------|
| Ethereum | EVM | ETH | 原生币、ERC20 |
| BNB Smart Chain | EVM | BNB | 原生币、BEP20/ERC20 |
| Arbitrum | EVM | ETH | 原生币、ERC20 |
| X Layer | EVM | OKB | 原生币、ERC20 |
| Base | EVM | ETH | 原生币、ERC20 |
| Polygon PoS | EVM | POL | 原生币、ERC20 |
| Avalanche C-Chain | EVM | AVAX | 原生币、ERC20 |
| Bitcoin | UTXO | BTC | Native SegWit P2WPKH |
| Solana | Solana | SOL | SOL、SPL Token |
| Sui | Move | SUI | SUI、Sui Coin/USDC |
| Aptos | Move | APT | APT、Fungible Asset/USDC |
| TRON | TRON | TRX | TRX、TRC20 |

网络管理：

- 支持编辑内置链名称、简称和 RPC 列表。
- 支持添加自定义 EVM 网络。
- 支持 RPC 延迟检测、可用性检测和手动测速。
- 支持启用、禁用、编辑和删除自定义网络。
- 新增或修改网络后，首页余额、资产设置、收款、转账和历史记录统一读取同一份链配置。

### 资产与余额

- 首页按可信代币身份聚合资产，而不是按链分组。
- 每个代币展示跨链总数量、USD 总价值和持有网络数量；点击后查看各网络余额，并可继续进入单链交易历史。
- 内置代币通过链和合约地址安全映射到 `canonicalTokenId`；未确认的同名自定义代币保持隔离，避免错误合并和错误估值。
- 支持原生币和默认 Token 余额查询。
- 支持添加自定义 Token。
- 自定义 EVM Token 自动读取 symbol/name/decimals。
- 支持 Token logo 和热门 Token 快速添加。
- 支持在资产设置中控制资产显示与隐藏；首页不提供临时“隐藏 0 余额”开关。
- 支持本地余额缓存，先显示最近快照再后台刷新；网络失败时保留最后一次成功数据。
- 多条链并发查询，每条链完成后立即更新首页；EVM 同链多资产优先使用 JSON-RPC Batch。
- 首次没有缓存时展示代币列表 Shimmer 骨架屏，钱包卡片和安全提示仍立即显示。
- 支持 USD 估值，价格源包含 Binance、OKX、CoinGecko、DeFiLlama、CoinPaprika、CryptoCompare 等兜底路径。

### 转账与收款

- 支持 EVM 原生币和 ERC20 转账。
- 支持 TRON TRX 和 TRC20 转账。
- 支持 Solana SOL 和 SPL Token 转账。
- 支持 Bitcoin Native SegWit P2WPKH 转账、UTXO 选择、动态手续费、找零、签名和 Esplora 广播。
- 支持 Sui SUI/Coin 转账、交易模拟、Gas 估算和 Ed25519 签名提交。
- 支持 Aptos APT/Fungible Asset 转账、交易模拟、Gas 估算和 Ed25519 签名提交。
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
  - BSC、Arbitrum、Base、Polygon 和 Avalanche 在配置 Key 后优先使用 Moralis。
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
- Bitcoin 数据源：
  - 使用 mempool.space / Blockstream Esplora 查询 BTC 历史、分页和单笔交易。
- Sui 数据源：
  - 使用 Sui GraphQL 按地址分页查询，并解析 Coin 余额变化和 Gas。
- Aptos 数据源：
  - 使用 Aptos Indexer GraphQL 查询 APT/Fungible Asset 活动，并结合 Fullnode 补充交易状态。
- Base、Polygon 和 Avalanche：
  - 支持 Etherscan V2、配置的 Explorer、Blockscout（可用链）和 RPC logs 等数据源或兜底路径。

### 用户体验

- 中文和英文国际化。
- 亮色/暗色主题切换。
- 地址簿管理。
- 内置区块浏览器 WebView，支持返回、前进、刷新、复制链接和外部浏览器打开。
- 资产显示管理。
- 网络管理页面。
- 首页使用代币级资产组合、首载骨架屏、缓存优先加载和链级渐进式更新。
- 首页钱包切换、收款和转账入口采用统一的轻量交互样式，并提供按压反馈和语义标签。

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
| `MORALIS_API_KEY` | BSC、Arbitrum、Base、Polygon、Avalanche 原生交易及 ERC20/BEP20 Token 历史记录 | Moralis Dashboard：https://admin.moralis.com |

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

- 包含 Dart 3.10.7 或更高版本的 Flutter SDK（以 `pubspec.yaml` 为准）
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
├── common/                       # 通用主题
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
        ├── asset_valuation/      # 多行情源价格查询
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
- EVM、Bitcoin、Solana、Sui、Aptos、TRON 链类型与地址规则
- 地址簿
- 助记词备份状态
- 区块浏览器链接
- 余额与自定义资产逻辑
- 转账编码和提交逻辑
- EVM / Bitcoin / TRON / Solana / Sui / Aptos 交易历史 Provider
- 首页跨链代币聚合、可信资产隔离、估值和排序
- 缓存迁移、链级渐进加载及自定义网络/资产绑定

## 安全说明

这是本地热钱包项目，不等同于硬件钱包或多签钱包。开发和测试时请注意：

- 不要提交真实私钥、助记词、API Key 或生产钱包数据。
- 不要在日志中打印私钥、助记词、签名材料。
- 转账相关代码属于高风险逻辑，修改后必须重点验证地址、金额、链选择、手续费和错误处理。
- 建议使用测试钱包和少量资金验证。

## 当前限制

- 动态添加网络目前只支持 EVM 兼容链。
- Bitcoin、Solana、Sui、Aptos、TRON 作为内置链存在，暂不支持用户动态添加同类网络。
- Bitcoin 首版只支持 Mainnet Native SegWit P2WPKH（`bc1q...`）地址和转账。
- X Layer 原生 OKB 历史记录缺少稳定 indexer，普通 RPC 无法完整查询地址历史。
- 资产估值和交易历史依赖第三方 API，可用性受 API 限流、套餐和服务状态影响。
- 这是测试/学习用本地热钱包；新增链和转账能力仍应先用测试钱包、小额资金完成真机验证。

## 相关设计文档

- [首页按代币聚合改造](docs/HOME_TOKEN_PORTFOLIO_REFACTOR.md)
- [首页余额加载优化](docs/BALANCE_LOADING_OPTIMIZATION.md)
- [Bitcoin Mainnet 接入任务](docs/BITCOIN_MAINNET_IMPLEMENTATION_TASKS.md)
- [Sui Mainnet 接入任务](docs/SUI_MAINNET_IMPLEMENTATION_TASKS.md)
- [Aptos Mainnet 接入任务](docs/APTOS_MAINNET_IMPLEMENTATION_TASKS.md)

## 截图

以下截图直接引用 `assets/img/` 中的最新项目界面，在 GitHub 和支持 HTML 的 Markdown 阅读器中可直接预览：

| 首页资产 | 切换钱包 | 添加钱包 | 创建钱包 |
|----------|----------|----------|----------|
| <img src="assets/img/home.png" width="180" alt="首页资产"> | <img src="assets/img/Screenshot_20260822_152622.png" width="180" alt="切换钱包"> | <img src="assets/img/Screenshot_20260822_152648.png" width="180" alt="添加钱包"> | <img src="assets/img/Screenshot_20260822_152658.png" width="180" alt="创建钱包"> |

| 助记词备份确认 | 钱包详情 | 多链地址与密钥 | 修改钱包名称 |
|----------------|----------|----------------|--------------|
| <img src="assets/img/Screenshot_20260822_152723.png" width="180" alt="助记词备份确认"> | <img src="assets/img/Screenshot_20260822_152746.png" width="180" alt="钱包详情"> | <img src="assets/img/Screenshot_20260822_152757.png" width="180" alt="多链地址与密钥"> | <img src="assets/img/Screenshot_20260822_152809.png" width="180" alt="修改钱包名称"> |

| 代币跨链明细 | 交易历史 | 交易详情 | 收款二维码 |
|----------------|----------|----------|------------|
| <img src="assets/img/Screenshot_20260822_152824.png" width="180" alt="代币跨链明细"> | <img src="assets/img/Screenshot_20260822_152836.png" width="180" alt="交易历史"> | <img src="assets/img/Screenshot_20260822_152845.png" width="180" alt="交易详情"> | <img src="assets/img/Screenshot_20260822_152856.png" width="180" alt="收款二维码"> |

| 设置 | 安全设置 | 地址簿 | 添加联系人 |
|------|----------|--------|------------|
| <img src="assets/img/Screenshot_20260822_153116.png" width="180" alt="设置"> | <img src="assets/img/Screenshot_20260822_153123.png" width="180" alt="安全设置"> | <img src="assets/img/Screenshot_20260822_153133.png" width="180" alt="地址簿"> | <img src="assets/img/Screenshot_20260822_153139.png" width="180" alt="添加联系人"> |

| 资产显示管理 | 添加自定义代币 | 网络管理 | 添加自定义网络 |
|--------------|----------------|----------|----------------|
| <img src="assets/img/Screenshot_20260822_153152.png" width="180" alt="资产显示管理"> | <img src="assets/img/Screenshot_20260822_153205.png" width="180" alt="添加自定义代币"> | <img src="assets/img/Screenshot_20260822_153223.png" width="180" alt="网络管理"> | <img src="assets/img/Screenshot_20260822_153232.png" width="180" alt="添加自定义网络"> |

## 许可证

本项目仅用于学习和研究。
