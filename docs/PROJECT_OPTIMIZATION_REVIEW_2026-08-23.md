# Flutter Wallet 当前代码优化审查

> 审查日期：2026-08-23  
> 审查分支：`main`  
> 当前提交：`01a4c71`  
> 文档性质：只读代码审查结果，不代表以下问题已经完成改造。

## 1. 总体结论

项目当前已经具备较完整的多链钱包基础能力，已有较好的测试基础：

- `flutter test --no-pub`：370 项测试全部通过；
- `flutter analyze --no-pub`：没有 error，仅有 14 条已有的 info；
- 工作区保持干净，本次审查没有修改业务代码；
- 当前最需要优化的不是 UI 小细节，而是交易广播状态、资产精度、密钥持久化和跨平台安全边界。

如果准备承载真实资产，建议先完成 P0 项，再继续增加新的链或资产功能。

## 2. 优先级定义

| 优先级 | 含义 | 建议 |
| --- | --- | --- |
| P0 | 可能导致错误转账、重复支付或敏感信息泄露 | 真实资产使用前完成 |
| P1 | 影响数据正确性、稳定性、性能或平台兼容 | 下一轮迭代完成 |
| P2 | 架构和长期维护问题 | 新增大型链功能前完成 |

## 3. P0：优先处理的问题

### 3.1 广播超时可能导致重复转账

**严重级别：高｜类型：交易安全｜范围：较大改造**

位置：

- `lib/page/transfer/controller/transfer_controller.dart:511`
- `lib/wallet/services/transfer/evm_wallet_transfer.dart:190`
- `lib/wallet/services/transfer/bitcoin_wallet_transfer.dart:102`

当前只有 RPC 返回交易 hash 后才保存本地交易记录。若节点已经接收交易但客户端发生超时，备用 RPC 可能返回“已知交易”或拒绝，页面却会提示失败，用户可能重新发起一笔有效转账。

建议：

1. 签名完成后先计算并保存本地交易 hash；
2. 增加 `signed`、`broadcastUnknown` 等中间状态；
3. 广播超时、网络断开或 `already known` 时，先按 hash 查询链上状态；
4. 在状态未确认前禁止用户直接重新构造交易；
5. EVM、Bitcoin、Solana、TRON 使用统一的广播状态模型。

### 3.2 自定义代币 decimals 可被修改（已完成，2026-08-23）

**严重级别：高｜类型：资产正确性｜范围：小到中等**

位置：

- `lib/page/setting/view/widgets/add_custom_asset_sheet.dart:324`
- `lib/page/setting/view/widgets/add_custom_asset_sheet.dart:357`
- `lib/wallet/services/config/wallet_custom_asset_service.dart:168`

链上读取 metadata 后，用户仍可修改 decimals，服务层只校验 `0..30`。转账时会直接使用保存的 decimals 计算原始单位，输入错误会造成数量级错误。

建议：

- EVM 合约读取成功后将 decimals 设为只读；
- 添加资产时校验合约代码确实存在；
- 转账预检时重新读取并校验 decimals；
- 手动填写的未验证精度只允许用于展示，不允许直接签名转账。

本次实现：

- EVM 资产必须先读取链上 `symbol/name/decimals`，读取成功后 decimals 输入框只读；
- EVM 资产不允许绕过链上 metadata 校验直接手动提交；热门资产使用预置的已验证 metadata；
- 同一链+合约的自定义资产再次保存时，禁止覆盖既有 decimals；
- 新增服务层和持久化测试，覆盖未验证 EVM 资产与 decimals 篡改场景。

### 3.3 非最终确认状态被当成成功

**严重级别：高｜类型：交易状态｜范围：较小**

位置：

- `lib/wallet/services/transaction/wallet_transaction_status_service.dart:57`
- `lib/wallet/services/transaction/wallet_transaction_status_service.dart:75`
- `lib/page/transfer/controller/transfer_controller.dart:851`

Solana 当前只要状态对象存在且 `err == null` 就返回成功，没有区分 `processed`、`confirmed` 和 `finalized`。EVM receipt 状态也应只接受明确的 `0x1` 或 `0x0`。

建议：

- Solana 将 `processed` 视为 pending；
- 明确产品采用 `confirmed` 还是 `finalized` 作为成功标准；
- EVM 未知 receipt 状态返回 unknown，不得默认 success；
- 为每条链补全 pending、unknown、confirmed、failed 测试。

### 3.4 Android Release 仍使用 Debug 签名

**严重级别：高｜类型：发布安全｜范围：较小**

位置：`android/app/build.gradle.kts:33`

Release 构建明确使用 `signingConfigs.getByName("debug")`。这不适合作为正式发布签名，也会影响应用更新身份和发布可信度。

建议：

- 使用 CI Secret 或本地安全文件配置独立 release keystore；
- 缺少 release 签名时直接阻止 release 构建；
- 在构建流程中校验证书 fingerprint；
- 不要将 keystore、密码或真实签名配置提交到仓库。

### 3.5 助记词和私钥输入页面没有统一截屏保护

**严重级别：高｜类型：敏感信息安全｜范围：较小到中等**

钱包详情页使用了 `SecureScreen`，但创建钱包展示助记词、导入助记词和导入私钥页面没有统一保护。

位置：

- `lib/page/home/view/widgets/password_setup_sheet.dart:165`
- `lib/page/home/view/widgets/import_wallet_sheet.dart:83`
- `lib/widget/secure_screen.dart:48`
- `lib/utils/screen_security.dart:1`

另外，截屏保护失败时当前实现会静默吞掉异常，但界面仍可能显示“保护已开启”的提示；`screen_security.dart` 直接导入 `dart:io`，也会阻碍 Web 构建。

建议：

- 所有助记词、私钥输入和展示页面统一接入敏感页面控制器；
- 使用条件导入隔离 Android/iOS/Web 实现；
- `enable/disable` 返回明确成功结果；
- 只有原生调用确认成功后才显示保护提示；
- 对嵌套弹窗使用引用计数，避免一个弹窗关闭时误解除另一个页面的保护。

## 4. P1：稳定性、性能和平台兼容

### 4.1 密钥与钱包元数据不是原子保存

位置：

- `lib/wallet/services/wallet_repository.dart:153`
- `lib/wallet/services/wallet_repository.dart:336`
- `lib/page/home/controller/home_controller.dart:224`

私钥、助记词和钱包元数据是多次独立写入。创建或删除过程中任一步失败，都可能留下不完整钱包、不可见的孤立密钥或删除后残留的密钥。

建议引入轻量事务协调器：保存阶段记录、失败回滚、删除 tombstone 和启动恢复；同时增加 secure storage 写入失败的故障注入测试。

### 4.2 Web 端密码学仍可能阻塞主线程（已完成，2026-08-23）

移动端继续使用 `compute`/isolate；Web 端新增条件导入的 Web Crypto 实现，将 PBKDF2-HMAC-SHA256 和 AES-GCM 放到浏览器原生异步 `SubtleCrypto` 中执行。这样钱包创建、导入和解锁时的本地加密不会再把 100000 次 KDF 迭代直接放在 Flutter UI 线程上。

本次实现：

- `lib/wallet/services/crypto/web_wallet_crypto.dart` 按平台选择 WebCrypto 或原有 PointyCastle 实现；
- WebCrypto 生成的 payload 仍沿用现有 `version/kdf/iterations/salt/nonce/cipherText` 格式，可与移动端互解；
- 浏览器不支持 `SubtleCrypto` 时自动回退到 PointyCastle，不影响钱包可用性；
- 原生端保持 isolate 路径，避免改变既有密钥存储行为；
- 已通过 Web release 构建和 `wallet_secret_store_test.dart` 回归测试。

### 4.3 启动和首页刷新存在重复读取（已完成，2026-08-23）

位置：

- `lib/page/splash/view/splash_page.dart:77`
- `lib/page/home/controller/home_controller.dart:170`
- `lib/page/home/controller/home_controller_balance.dart:169`

Splash 固定等待约 1.35 秒，首页随后还会重新读取钱包、网络、隐藏资产和缓存配置。多个独立配置也存在串行读取。

本次实现：

- 启动时通过 `WalletRepository.loadWalletSnapshot` 一次解析钱包列表并确定当前钱包；
- 首页钱包、隐藏资产和启用链配置使用 `Future.wait` 并行读取；
- 首次余额刷新复用首页已经加载的链配置，不再重复读取链配置和隐藏资产配置；
- 余额服务支持接收首页快照中的链配置，避免同一轮刷新再次解析网络配置；
- Splash 仍保留必要的品牌动画时长，首页初始化不再额外串行等待配置读取。

### 4.4 自定义 RPC 允许 HTTP，非 EVM 网络缺少身份校验

位置：`lib/wallet/services/config/wallet_chain_config_service.dart:285`、`:438`

当前 RPC URL 接受 `http://`，EVM 会校验 chain ID，但非 EVM 网络没有等价的 genesis/network identity 校验。

建议：生产环境只允许 HTTPS，调试环境仅允许 localhost HTTP；添加 Solana genesis hash、Sui/Aptos 网络身份等校验，并在签名前再次确认链身份。

### 4.5 日志可能暴露 API Key、地址和余额信息

位置：

- `lib/wallet/services/balance/chain_balance_routes.dart:120`
- `lib/wallet/utils/rpc_retry_helper.dart:47`
- `lib/main.dart:59`

API Key 可能出现在 URL，RPC 重试日志包含完整 URL，余额日志包含地址、金额和合约信息；同时全局错误上报函数目前为空，生产异常可能被直接吞掉。

建议：

- 日志统一脱敏 URL query、地址、金额和合约；
- 默认关闭详细余额日志；
- 用户配置的 provider key 使用安全存储；
- 增加可注入的生产错误上报接口，但禁止上报私钥、助记词和密码。

### 4.6 Solana SPL Token 手续费可能遗漏 ATA 租金

位置：`lib/wallet/services/transfer/solana_wallet_transfer.dart:136`、`:172`

SPL 转账可能创建目标 ATA，当前固定费用估算不一定包含账户租金，可能导致确认页通过但提交时 SOL 不足。

建议：检查目标 ATA 是否存在，按最终交易消息估算 fee，并将创建 ATA 所需租金纳入余额校验。

## 5. P2：长期架构优化

当前转账、余额、手续费、广播和交易状态仍分别通过链类型分发。新增链时需要同步修改多个服务，容易出现某一处漏接或确认策略不一致。

建议让 `ChainAdapter` 完整拥有以下能力：

```text
地址校验 → 余额查询 → 手续费估算 → 交易构造 → 签名 → 广播 → 状态确认
```

共享层只保留 HTTP/RPC 重试、金额解析、错误类型和缓存能力。每个 Adapter 配套一组统一的契约测试，覆盖地址、余额、手续费、广播和 finality。

## 6. 推荐实施顺序

### 第一批：真实资产安全闭环

1. 修复交易状态确认逻辑；
2. 增加广播超时和重复支付保护；
3. 锁定并复核代币 decimals；
4. 移除 Android Debug release 签名；
5. 完善助记词/私钥页面截屏保护。

### 第二批：稳定性和性能

1. 密钥与钱包元数据原子保存；
2. 启动和首页配置并行加载；
3. Web Worker/Web Crypto 优化；
4. RPC HTTPS 和网络身份校验；
5. 日志脱敏与错误上报。

### 第三批：链适配器重构

1. 统一 ChainAdapter 契约；
2. 迁移 EVM、Solana、TRON、Bitcoin、Sui、Aptos；
3. 增加 Adapter contract tests；
4. 删除散落在页面和服务中的链类型分支。

## 7. 建议补充的测试

- RPC 已接收但客户端超时后的广播恢复；
- 交易 hash 已存在时禁止重复发送；
- Solana `processed/confirmed/finalized` 状态；
- EVM receipt 未知状态；
- 自定义代币 decimals 被篡改或与链上不一致；
- SPL Token 已存在 ATA/不存在 ATA 两种手续费；
- secure storage 部分写入失败和删除失败；
- 混合正常/损坏钱包记录的启动恢复；
- Web 全量构建和原生截屏保护通道失败；
- release 签名证书校验。

## 8. 验收基线

每一批改造完成后至少执行：

```bash
flutter analyze
flutter test
flutter build apk --debug
scripts/check_secrets.sh
```

Web 端还应执行完整构建并验证浏览器运行；当前项目的 Web 构建仍需单独处理 `image_picker_for_web` 依赖和平台实现问题。

发布检查清单：

1. 修复 Android release 签名；
2. 更新 pubspec.yaml 版本号；
3. 在 macOS 构建 Android、macOS 和 iOS；
4. 在 Windows 构建 Windows；
5. 对 DMG、ZIP、APK 做安装测试；
6. 生成 SHA256 校验文件；
7. 创建 GitHub Tag；
8. 发布 GitHub Release；
9. iOS 通过 TestFlight 或 App Store 分发；
10. 将下载链接补充到 README。
