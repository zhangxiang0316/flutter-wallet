# 沐晨钱包

沐晨钱包是一个基于 Flutter 和 GetX 构建的多链加密钱包应用。项目当前定位为本地热钱包 Demo/测试应用，已覆盖钱包创建、导入、多钱包切换、多链余额查询、USD 估值、转账、收款、资产显示管理、自定义代币、网络管理、语言切换和主题切换等核心流程。

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

## 当前边界

- 动态添加网络当前只支持 EVM 兼容链。
- 自定义链复用 EVM 地址，暂不支持用户动态添加 Solana/TRON 类型网络。
- 资产价格和链上余额依赖第三方价格接口与各链 RPC，可用性会影响总资产估值。
- Solana SPL Token 转账需要发送方已有可用 token account；收款方 ATA 会在交易中使用幂等创建指令。
