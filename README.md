# 沐晨钱包

沐晨钱包是一个基于 Flutter 和 GetX 构建的多链加密钱包应用。项目当前定位为本地热钱包 Demo/测试应用，已覆盖钱包创建、导入、多钱包切换、多链余额查询、USD 估值、转账、收款、交易记录、内嵌区块浏览器、资产显示管理、自定义代币、网络管理、语言切换和主题切换等核心流程。

## 应用截图

以下截图位于 `docs/` 目录，展示当前应用的主要页面和功能流程。

| 截图 1                                              | 截图 2 | 截图 3 |
|---------------------------------------------------| --- | --- |
| <img src="docs/1.jpg" width="220" alt="应用截图 1">   | <img src="docs/2.jpg" width="220" alt="应用截图 2"> | <img src="docs/3.jpg" width="220" alt="应用截图 3"> |
| 截图 4                                              | 截图 5 | 截图 6 |
| <img src="docs/4.jpg" width="220" alt="应用截图 4">   | <img src="docs/5.jpg" width="220" alt="应用截图 5"> | <img src="docs/6.jpg" width="220" alt="应用截图 6"> |
| 截图 7                                              | 截图 8 | 截图 9 |
| <img src="docs/7.jpg" width="220" alt="应用截图 7">   | <img src="docs/8.jpg" width="220" alt="应用截图 8"> | <img src="docs/9.jpg" width="220" alt="应用截图 9"> |
| 截图 10                                             | 截图 11 | 截图 12 |
| <img src="docs/10.jpg" width="220" alt="应用截图 10"> | <img src="docs/11.jpg" width="220" alt="应用截图 11"> | <img src="docs/12.jpg" width="220" alt="应用截图 12"> |
| 截图 13                                             | 截图 14 | 截图 15 |
| <img src="docs/13.jpg" width="220" alt="应用截图 13"> | <img src="docs/14.jpg" width="220" alt="应用截图 14"> | <img src="docs/15.jpg" width="220" alt="应用截图 15"> |
| 截图 16                                             | 截图 17 |  |
| <img src="docs/16.jpg" width="220" alt="应用截图 16"> | <img src="docs/17.jpg" width="220" alt="应用截图 17"> |  |

## 钱包功能详解

### 钱包创建与导入

- 支持创建新钱包，创建时生成助记词，并用用户设置的钱包密码加密保存私钥和助记词。
- 支持通过助记词导入钱包，自动派生 EVM、TRON 和 Solana 地址。
- 支持通过私钥导入钱包，复用同一套私钥派生 EVM/TRON/Solana 地址。
- 创建和导入过程带 loading 状态，避免重复点击造成多次写入。
- 旧版本明文私钥会提示用户设置密码并迁移到本地加密存储。

### 多钱包管理

- 首页支持多个钱包共存，可以新增、切换、移除钱包。
- 钱包切换弹窗中展示当前钱包和钱包列表，移除钱包需要二次确认。
- 钱包详情页支持修改钱包名称，修改后首页会同步刷新。
- 钱包详情页可查看各链地址，并在输入钱包密码后查看私钥或助记词。

### 支持链与网络

内置支持：

- BNB Smart Chain
- Ethereum
- Arbitrum
- X Layer
- Solana
- TRON

网络管理页支持编辑内置链的名称、符号和 RPC 列表。自定义网络当前支持 EVM 兼容链，用户可填写网络名称、原生币符号、Chain ID 和多条 RPC 地址。添加或编辑 EVM 网络时会校验 RPC 返回的 `eth_chainId`，确保节点和链 ID 匹配。自定义网络可以启用、停用、编辑和删除。

### 资产与余额

- 首页按链展示资产，默认只展示链汇总，点击链卡片后展开该链下的币种明细。
- 支持下拉刷新，同时在首页启动 30 秒定时余额刷新。
- 支持每条链右侧显示当前链 USD 估值。
- 支持总资产 USD 估值：稳定币直接计价，非稳定币会按实时价格换算成 USD 后参与汇总。
- 支持非稳定币在资产明细中展示对应的稳定币价值。
- 币种数量展示最多保留 8 位小数，避免长小数影响界面。

默认资产覆盖原生币、稳定币和常见封装资产，例如 BNB、ETH、OKB、SOL、TRX、USDT、USDC、DAI、WBTC、BTCB、ARB 等。实际展示还会受到资产显示设置和用户自定义资产影响。

### 资产显示与自定义代币

- 资产显示页支持按链控制每个币种在首页显示或隐藏。
- 隐藏资产不会删除链上余额，只是不参与首页展示和总资产汇总。
- 支持在指定链下手动添加自定义代币。
- EVM 自定义代币支持通过合约地址尝试读取 symbol、name 和 decimals。
- 自定义资产支持删除，删除前会弹出确认提示。

### 转账

- 转账页支持在页面内切换网络和当前网络下的币种。
- 支持原生币和代币转账：EVM 原生币/ERC20、TRON TRX/TRC20、Solana SOL/SPL Token。
- 输入收款地址和金额后会实时估算手续费；手续费以对应链原生币展示，例如 BNB、ETH、OKB、TRX 或 SOL。
- 提交交易前需要输入钱包密码解锁本地私钥。
- 支持扫码填入收款地址，二维码可以是纯地址，也可以是常见链 URI。
- 交易广播成功后展示交易哈希，并支持复制。

### 收款

- 收款页支持同一行下拉选择网络和币种。
- 根据当前钱包和所选链展示收款地址。
- 自动生成二维码，支持一键复制地址。
- 收款页面只展示公开地址，不读取私钥，也不做签名操作。

### 交易记录与区块浏览器

- 首页点击某个币种后进入交易记录页，按当前钱包、链和币种展示链上交易记录。
- 交易记录会展示交易方向、金额、状态、时间、手续费、发送方、接收方和交易哈希。
- EVM 链优先使用配置的浏览器 API、内置 Blockscout 兜底和 token logs 查询；TRON 和 Solana 使用各自链上接口。
- 部分链的公开历史接口需要 API Key 或索引服务，应用内可能查不到完整历史。
- 当应用内没有记录或加载失败时，可进入内嵌区块浏览器查看该地址的链上记录。
- 内嵌区块浏览器支持返回、前进、刷新、复制链接和外部浏览器打开。

### 设置

- 设置页入口位于首页右上角。
- 当前设置包含语言、主题、资产显示和网络管理。
- 语言和主题会保存到本地，下次启动自动恢复。

## 技术实现概览

- `GetX`：页面路由、控制器状态管理和依赖组织。
- `flutter_screenutil`：移动端尺寸适配。
- `dio`：RPC 和 HTTP 请求。
- `decimal`：资产估值和金额展示中的高精度计算。
- `pointycastle`：EVM/TRON secp256k1 签名相关逻辑。
- `solana`：Solana 地址、PDA、指令和交易构造。
- `flutter_secure_storage`：本地密钥安全存储。
- `qr_flutter`：收款二维码展示。
- `mobile_scanner`：转账扫码录入收款地址。
- `webview_flutter`：应用内嵌区块浏览器。
- `url_launcher`：区块浏览器外部打开兜底。

## 项目结构

```text
lib/
  base/                 基础页面和控制器
  common/               通用网络、主题和模型
  generated/            路由和国际化生成文件
  l10n/                 ARB 国际化源文件
  page/                 页面、控制器和页面组件
    home/               首页、钱包切换、余额展示
    transfer/           转账页面和扫码页面
    receive/            收款页面、二维码和地址展示
    transaction/         交易记录页面
    browser/             内嵌区块浏览器
    wallet/             钱包详情、地址、私钥/助记词查看
    setting/            设置、资产显示、网络管理
  utils/                通用工具方法
  wallet/               钱包模型、链上服务、密钥和转账逻辑
assets/
  icons/ img/ svg/      应用图标和静态资源
test/                   单元测试
```

平台相关配置位于 `android/`、`ios/`、`web/`、`macos/`、`linux/`、`windows/`。除包名、权限、图标、签名等平台事项外，优先在 `lib/` 内实现业务逻辑。

## 环境要求

- Flutter SDK：项目 `pubspec.yaml` 当前要求 Dart SDK `^3.10.7`。
- Android Studio 或 Xcode：用于 Android/iOS 真机运行和打包。
- 首次拉取后先安装依赖：

```bash
flutter pub get
```

## 常用开发命令

```bash
flutter run
```

运行到当前选中的设备。

```bash
flutter analyze
```

执行静态检查，规则来自 `analysis_options.yaml`。

```bash
flutter test
```

运行全部测试。

```bash
flutter test test/wallet_crypto_service_test.dart
```

运行钱包加密服务的单文件测试。

```bash
dart analyze lib/page/transaction lib/wallet/services test/wallet_crypto_service_test.dart
```

对交易记录、区块浏览器和钱包服务做局部静态检查。

```bash
dart format lib test
```

格式化 Dart 代码。

## 代码生成

修改路由注解、JSON 模型或其他 generator 相关代码后运行：

```bash
flutter pub run build_runner build
```

修改 `lib/l10n/*.arb` 后运行：

```bash
flutter pub run intl_utils:generate
```

如果生成文件冲突，可以在确认无本地手改生成文件后使用：

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## 打包

Android release APK：

```bash
flutter build apk --release
```

iOS release IPA：

```bash
flutter build ipa --release
```

## 开发约定

- 使用 GetX 进行路由、状态管理和依赖查找。
- 页面文件放在 `lib/page/<feature>/view/`，控制器放在 `controller/`。
- 页面拆分组件优先放在对应页面的 `view/widgets/` 下。
- UI 文案优先走国际化：同时维护 `lib/l10n/intl_zh.arb` 和 `lib/l10n/intl_en.arb`。
- UI 尺寸继续使用 `flutter_screenutil` 的 `.w`、`.h`、`.sp`。
- 文件命名使用 `snake_case.dart`，类名使用 `UpperCamelCase`，变量和方法使用 `lowerCamelCase`。

## 安全说明

本项目包含私钥、助记词、转账签名等高风险逻辑。当前实现会使用钱包密码加密私钥和助记词，并保存在设备安全存储中，但它仍属于本地热钱包方案，不等同于硬件钱包或多方签名方案。

请遵守以下约束：

- 不要提交真实私钥、助记词、API 密钥或生产钱包数据。
- 不要在日志中打印私钥、助记词、未加密密钥材料或完整交易签名数据。
- 涉及转账、密钥读取、RPC 节点、资产估值的改动需要重点验证地址校验、金额精度、链选择、异常提示和失败回滚。
- 公共 RPC 可能限流或不可用，生产环境应配置稳定 RPC、监控和错误降级策略。
- 内嵌区块浏览器只用于查看公开链上页面，不应在 WebView 中输入助记词、私钥或钱包密码。

## 当前边界

- 动态添加网络当前只支持 EVM 兼容链。
- 自定义链复用 EVM 地址，暂不支持用户动态添加 Solana/TRON 类型网络。
- 资产价格和链上余额依赖第三方价格接口与各链 RPC，可用性会影响总资产估值。
- Solana SPL Token 转账需要发送方已有可用 token account；收款方 ATA 会在交易中使用幂等创建指令。
- 交易记录依赖第三方索引接口或区块浏览器 API。普通 RPC 不能可靠查询某个地址的完整原生币历史。
- 内嵌区块浏览器页面由第三方站点提供，加载速度、可用性和展示内容不由应用控制。

## 待做功能

1. 交易记录增强
    - 接入更稳定的多链索引服务，例如 Etherscan V2、Helius 或自建后端索引器。
    - 增加交易状态跟踪、确认数、失败原因和区块浏览器交易详情跳转。

2. RPC 健康检查和自动切换
    - 现在已经支持多 RPC，但还可以做成“延迟检测、失败自动切换、手动设默认节点”。
    - 对余额、估值、转账都很关键。

3. 安全增强
    - 钱包打开后增加自动锁定。
    - 转账、查看私钥/助记词继续强制二次验证。
    - 支持 Face ID/Touch ID/指纹作为快捷解锁，但底层仍保留钱包密码。
    - 私钥/助记词页面禁止截图，复制后定时清空剪贴板。

4. 助记词备份流程
    - 创建钱包后要求用户按顺序确认助记词。
    - 未完成备份的钱包首页给明显提醒。
    - 钱包详情里显示“已备份/未备份”状态。

5. 转账体验优化
    - 增加“全部转出”按钮。
    - 显示预计到账、手续费币种余额是否足够。
    - EVM 支持 gas 自定义、nonce 展示、失败原因更细化。
    - 转账前增加确认页，突出链、币种、地址、金额、手续费。

中期可以加

- 地址簿：保存常用收款地址，支持备注、链类型校验。
- 自动发现代币：扫描 EVM/ERC20、Solana token account、TRON TRC20，用户确认后加入资产列表。
- 资产排序：按 USD 价值、余额、链、手动排序。
- 小额资产隐藏：一键隐藏低于某个 USD 金额的资产。
- 测试网模式：Sepolia、BSC Testnet、Solana Devnet 等，和主网明确隔离。
- 区块浏览器配置：每条链配置 explorer，用于交易和地址跳转。

暂时不建议太早做

- Swap、跨链桥、法币入金：产品价值高，但合规、报价、滑点、失败处理都复杂。
- DApp 浏览器：攻击面大，建议先做 WalletConnect，再考虑内置浏览器。
- 动态添加非 EVM 链：Solana/TRON 的地址、资产、转账模型差异大，成本明显高于 EVM。
