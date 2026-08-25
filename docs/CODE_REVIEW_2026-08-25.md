# 代码审查与优化建议（2026-08-25）

## 1. 审查目标与范围

本次审查基于当前 `main` 分支，重点检查：

- 大文件是否仍存在职责混杂；
- 页面、Controller、Service、ChainAdapter 之间的依赖方向；
- 钱包创建、导入、删除、解锁和转账等高风险链路；
- 新增链时仍需修改的固定模型和分支；
- Web、Android、iOS、macOS 等平台兼容性；
- 测试结构、静态分析和发布流程。

本文初稿只记录审查结论；第 4.1、4.2、4.3、4.5 节已在后续改造中完成，落地情况记录在对应问题和文末验收记录。

## 2. 当前质量基线

### 2.1 规模

- `lib/` 下非生成 Dart 代码约 39,296 行；
- 测试文件 56 个；
- 当前最大生产文件：

| 文件 | 行数 | 主要职责 |
| --- | ---: | --- |
| `lib/wallet/services/wallet_transfer_service.dart` | 739 | 多链转账入口、地址规范化、金额转换、签名和通用编码 |
| `lib/wallet/services/crypto/wallet_crypto_service.dart` | 681 | 多链密钥派生、地址生成、助记词和编码算法 |
| `lib/page/transfer/controller/transfer_controller.dart` | 672 | 转账页面状态和流程编排 |
| `lib/page/setting/view/widgets/add_custom_asset_sheet.dart` | 654 | 自定义资产表单、元数据加载、热门资产和提交状态 |
| `lib/wallet/services/transfer/evm_wallet_transfer.dart` | 567 | EVM 费用估算、模拟、签名和广播 |
| `lib/wallet/services/transfer/tron_transaction_validator.dart` | 565 | TRON 节点交易签名前校验 |

### 2.2 验证结果

已执行：

```bash
flutter test --no-pub
flutter analyze --no-pub
bash scripts/check_secrets.sh
```

结果：

- 389 项测试全部通过；
- 静态分析没有 error 或 warning，但仍有 14 条 info；
- 敏感信息扫描通过，没有发现已提交的真实密钥；
- 本次没有执行真实链转账、真实第三方 API 集成测试和各平台 Release 构建。

## 3. 总体结论

项目已经完成了 Controller 拆分、余额路由收口、交易历史 Provider 拆分、资产模型拆分和页面展示策略共享，结构相比上一轮 Review 明显改善。当前没有阻止编译或单元测试的错误。

剩余问题主要集中在四个方向：

1. 钱包密钥、元数据和缓存跨多个存储写入，但没有事务或失败恢复；
2. 敏感信息生命周期保护尚未覆盖创建和导入流程；
3. ChainAdapter 目前主要负责识别、校验和展示策略，链上读写能力及地址模型仍是固定分支；
4. Release 签名和客户端第三方 API Key 仍有发布安全风险。

建议不要继续优先做纯 UI 重构。下一阶段应先处理第 4 节的 P0/P1 问题，再继续拆大文件。

## 4. 已确认问题

### 4.1 P0：钱包密钥与元数据保存、删除不是可恢复事务（已完成）

位置：

- `lib/page/home/controller/home_wallet_lifecycle_service.dart:150`
- `lib/wallet/services/wallet_repository.dart:172`
- `lib/wallet/services/wallet_repository.dart:351`

创建或导入钱包时，当前顺序是：

```text
并行保存私钥/助记词 -> 保存钱包元数据和当前钱包 ID
```

删除钱包时，当前顺序是：

```text
删除钱包元数据 -> 删除 Secure Storage 中的私钥/助记词
```

这几步跨越 Secure Storage 和 SharedPreferences，任何一步失败都会产生部分成功状态：

- 私钥写入成功、助记词写入失败，会留下不完整密钥；
- 密钥写入成功、元数据写入失败，会留下 UI 不可见的孤立密钥；
- 删除元数据成功、密钥删除失败，会让敏感信息继续残留在设备上；
- 更新已有钱包时，如果密钥已被新密码重写但元数据保存失败，用户看到“导入失败”，实际解锁密码却可能已经变化。

现有 `home_wallet_lifecycle_service_test.dart` 使用 Fake Repository 验证成功路径，没有 Secure Storage/SharedPreferences 故障注入，因此 389 项测试通过并不能覆盖上述场景。

建议：

1. 新增 `WalletPersistenceTransaction`，为创建、导入和删除记录 `pending/committed/cleanupPending` journal；
2. 创建/导入先写临时密钥 key，元数据提交成功后再切换正式 key；
3. 删除使用 tombstone，密钥和缓存清理全部完成后再移除 tombstone；
4. 启动时扫描未完成 journal 并自动回滚或继续清理；
5. 增加“私钥写失败、助记词写失败、元数据写失败、删除失败、应用中断恢复”测试。

完成情况（2026-08-25）：

- 新增 `WalletPersistenceTransaction` journal，记录 upsert/remove 操作、旧元数据快照和事务阶段，不保存私钥、助记词或密码；
- 新增独立 `WalletPersistenceCoordinator`，使用 staging/backup Secure Storage key 提交创建、导入和删除事务；
- journal 使用 `pending`、`secretsPrepared`、`metadataCommitPending`、`metadataCommitted`、`cleanupPending` 和 `rollbackPending` 阶段，使元数据写到一半、密钥切换失败及应用中断都可以恢复；
- `WalletRepository` 的钱包读写使用进程内串行屏障，读取前自动恢复未完成事务，避免多个仓储实例并发覆盖同一 journal；
- 删除操作的 remove journal 同时作为 tombstone，正式提交后清理 Secure Storage、余额缓存、交易历史、助记词备份状态和内存密码；清理失败保留 `cleanupPending` 并在后续读取时重试；
- 创建和导入入口已统一调用 `saveWalletWithSecret()`，不再由页面流程分别保存密钥和元数据；
- 已增加 Secure Storage/元数据故障注入、删除回滚、应用中断恢复和钱包级缓存清理测试。

### 4.2 P0：Android Release 缺少签名配置时会静默使用 Debug 签名（已完成）

位置：

- `android/app/build.gradle.kts:42`
- `android/app/build.gradle.kts:53`
- `scripts/build_android.sh:35`
- `scripts/build_android_bundle.sh:35`

改造前，`release` 在找不到 `key.properties` 时回退到：

```kotlin
signingConfigs.getByName("debug")
```

改造前的构建脚本只检查 APK/AAB 是否生成，不校验证书。这样在新电脑、清理环境或路径配置错误时，仍会得到名为 `app-release` 的 Debug 签名产物，并可能被上传到 GitHub Release。后续使用正式证书构建时，该安装包无法作为同一签名身份正常升级。

建议：

1. Release 缺少 `key.properties` 或任一签名字段时直接构建失败；
2. 在构建脚本中使用 `apksigner verify --print-certs` 校验证书 SHA-256；
3. 将预期证书 fingerprint 保存为非敏感配置并做精确匹配；
4. Debug 签名只保留在 `debug` build type；
5. GitHub Release 上传前同时校验版本号、签名、文件哈希和产物名称。

完成情况（2026-08-25）：

- Gradle 仅在签名文件、四个必填字段和 keystore 全部有效时创建 Release signing config；Release 任务缺少任一配置会直接失败，不再回退 Debug 签名；
- 新增 `android/release-signing.properties`，保存可公开的 applicationId 和正式证书 SHA-256；
- APK 构建后使用 Android SDK `apksigner` 验证签名和证书指纹，并使用 `aapt` 核对 applicationId、versionName、versionCode；
- AAB 构建后使用 JDK `jarsigner` 和 `keytool` 验证归档签名及证书指纹，并核对 Release manifest 构建元数据中的 applicationId、versionName、versionCode；
- APK/AAB 只接受 `flutter-Wallet-v<pubspec version>` 文件名，并生成同名 `.sha256` 文件；任一校验失败时不会报告构建成功；
- APK 与 AAB 构建脚本复用 `scripts/android_release_common.sh`，避免两套发布校验逻辑漂移。

### 4.3 P1：创建和导入流程未接入敏感页面生命周期保护（已完成）

位置：

- `lib/page/home/view/home_page.dart:201`
- `lib/page/home/view/widgets/password_setup_sheet.dart:52`
- `lib/page/home/view/widgets/password_setup_sheet.dart:165`
- `lib/page/home/view/widgets/import_wallet_sheet.dart:35`
- `lib/utils/sensitive_data_lifecycle.dart:7`
- `lib/widget/secure_screen.dart:46`
- `lib/utils/screen_security.dart:15`

钱包详情页已经使用 `SecureScreen` 并注册 `SensitiveDataLifecycle`，但以下流程没有覆盖：

- 创建钱包后展示助记词；
- 助记词抽词确认；
- 导入助记词；
- 导入私钥；
- 上述流程中的钱包密码输入。

`PasswordSetupSheet` 会把助记词保存在 `_mnemonic` 中；`ImportWalletSheet` 在异步导入期间仍把助记词/私钥和密码保存在三个 `TextEditingController` 中。应用进入 inactive/paused 时，`SensitiveDataLifecycle.clearAll()` 不会清理这些 Widget 状态。

另外，`screen_security.dart` 直接依赖 `dart:io Platform`，且平台判断位于 `try` 外。Web 端存在运行时不支持风险；macOS/Windows 当前也不会启用任何窗口保护。`SecureScreen` 在原生调用被静默吞掉后仍会显示“保护已开启”，提示状态不一定真实。

建议：

1. 创建和导入 Sheet 统一包裹敏感页面作用域；
2. Widget 注册/注销生命周期清理回调，后台时清空助记词、私钥、密码和确认输入；
3. 导入提交前把必要数据复制到最短生命周期变量后立即清空 Controller；
4. ScreenSecurity 改为条件导入，并返回 `enabled/unsupported/failed` 明确结果；
5. 只有平台确认启用成功后才显示提示；
6. 使用引用计数或 token 管理嵌套敏感页面，避免一个页面释放时提前关闭全局保护；
7. 增加 Web、Android、iOS/macOS 生命周期 Widget 测试或平台通道测试。

完成情况（2026-08-25）：

- 新增 `SensitiveDataScope`，创建、迁移和导入 Sheet 统一注册/注销敏感数据清理回调，并持有屏幕保护租约；
- `PasswordSetupSheet` 在 inactive/paused/hidden/detached 对应的全局清理事件中清空密码、确认密码、助记词、钱包 ID 和抽词确认输入；异步创建在清理后返回时不会重新展示助记词；
- `ImportWalletSheet` 在提交前把 secret/password 复制到本次调用的短生命周期变量，随即清空三个 `TextEditingController`；生命周期清理发生在提交前时不会继续发起导入；
- `screen_security.dart` 使用条件导入，Web 不再加载 `dart:io`；Android/iOS 调用原生通道，Web/macOS/Windows 返回 `unsupported`，原生异常返回 `failed`；
- `SecureScreen` 只有收到 `enabled` 才显示保护提示，不再把 unsupported/failed 当成成功；
- 屏幕保护改为 token/引用计数租约，嵌套敏感页面只启用一次，最后一个租约释放后才关闭保护；
- 增加屏幕保护状态、嵌套租约、作用域注册注销、创建/导入生命周期和异步中断测试，并完成 Web Release 构建验证。

### 4.4 P1：删除钱包后余额和交易历史缓存仍长期残留（核心清理已完成）

位置：

- `lib/page/home/controller/home_wallet_lifecycle_service.dart:97`
- `lib/wallet/services/chain_balance_cache.dart:132`
- `lib/wallet/services/transaction/transaction_history_cache.dart:121`
- `lib/wallet/services/transaction/transaction_history_cache.dart:176`

删除钱包目前只清理：

- 钱包元数据；
- 私钥和助记词；
- 密码缓存；
- 助记词备份状态。

但 `ChainBalanceCache` 和 `TransactionHistoryCache` 仍在 SharedPreferences 中保留钱包地址、余额、交易 hash、收付款地址、金额和本地 pending 记录。缓存 key 都包含 walletId，却没有统一的 `clearWallet(walletId)`，删除流程也没有调用缓存清理。

这会造成：

- 用户认为钱包已删除，但设备仍保留可关联其资产和交易行为的数据；
- 重新导入同一 walletId 后可能读取旧缓存；
- 本地 pending 记录没有明确过期或钱包删除清理策略。

建议：

1. 为余额缓存和交易缓存增加 `clearWallet(walletId)`；
2. 引入 `WalletDataCleanupService`，由删除事务统一清理密钥、缓存、备份状态和密码缓存；
3. 对交易缓存增加版本、最大保留期和总量上限；
4. 将清理失败纳入 4.1 的 tombstone 重试；
5. 增加删除后 SharedPreferences 不再包含 walletId、地址、余额和交易记录的测试。

完成情况（2026-08-25）：

- `WalletLocalDataCleanupService` 已统一清理余额缓存、远程/本地交易历史、助记词备份状态和内存密码；
- 清理已并入钱包删除事务，失败时保留 `cleanupPending` journal，并在下一次仓储读取时自动重试；
- 已增加删除后钱包级 SharedPreferences 数据清理，以及 `cleanupPending` 重试测试；
- 缓存版本、最大保留期和总量上限仍属于后续独立优化，不影响钱包删除清理闭环。

### 4.5 P1：ChainAdapter 尚未真正解除新增非 EVM 链的固定代码修改（已完成）

位置：

- `lib/wallet/adapters/chain_adapter.dart:44`
- `lib/wallet/adapters/chain_adapter.dart:116`
- `lib/wallet/models/wallet_account.dart:1`
- `lib/wallet/services/crypto/wallet_crypto_service.dart:644`
- `lib/wallet/services/wallet_transfer_service.dart:93`
- `lib/wallet/services/chain_balance_service.dart:268`
- `lib/wallet/services/wallet_transaction_history_service.dart:130`
- `lib/wallet/services/transaction/wallet_transaction_status_service.dart:41`
- `lib/page/transfer/controller/transfer_scan_address_parser.dart:14`
- `lib/page/setting/view/widgets/chain_asset_visibility_card.dart:87`

当前 Adapter 已统一链识别、地址校验、展示和 Explorer 策略，但链上能力仍由中心服务维护 `WalletChainType -> handler` 映射。地址模型也仍固定包含：

```text
evm / tron / solana / bitcoin / sui / aptos
```

因此再新增一种非 EVM 链时，至少仍要修改：

- `WalletAccount` 字段、copyWith、JSON 和旧数据迁移；
- `WalletKeyPair` 和 `WalletCryptoService` 派生逻辑；
- 余额、转账、手续费、历史和交易状态中心 handler；
- 付款请求 scheme 白名单和内置链查找；
- 自定义资产按钮的链类型排除列表。

这说明当前 Registry 更接近“链策略目录”，还不是“链能力实现注册表”。特别是 `chain_asset_visibility_card.dart` 用“不等于 Bitcoin/Sui/Aptos”决定是否显示添加 Token，新增不支持 Token 的链时默认会错误显示入口。

建议按以下顺序继续：

1. 将钱包地址迁移为 `Map<String, String> addressesByNamespace` 或 `Map<WalletAddressKind, String>`，保留旧字段只做读取迁移；
2. 将派生结果改为 `Map<WalletAddressKind, DerivedAccount>`，密钥读取交给 KeyMaterial Adapter；
3. 让 Adapter 注册 `loadBalances/estimateFee/transfer/loadHistory/loadStatus` 实现，中心服务只负责编排和统一错误模型；
4. 为付款 URI scheme、自定义资产、扫码、收款等增加明确 capability，不再使用链类型排除列表；
5. 增加“注册一个测试链而不修改中心服务”的 contract test，作为架构验收条件。

完成情况（2026-08-25）：

- `WalletAccount` 改为持久化 `addressesByNamespace`；旧版 `bscAddress/tronAddress/...` 仅在反序列化时迁移，兼容 getter 暂时保留给现有调用方，新链地址不再要求增加模型字段；
- `WalletChainConfig` 新增字符串 `adapterId`，注册表按 adapterId 而不是 `WalletChainType` 查找实现；`type` 仅保留为旧配置兼容元数据；
- `WalletKeyPair` 改为 `derivedAccountsByNamespace`，`WalletCryptoService` 支持注入派生 Adapter；`WalletRepository` 按 Adapter 声明的 key-material namespace 读取签名材料，转账编排不再判断 Bitcoin/Solana/Sui/Aptos；
- 新增泛型 `ChainOperationRegistry`，余额、转账、手续费、历史、交易状态和 RPC 健康检查均按 adapterId 注册类型安全实现，中心请求路径已删除 `WalletChainType -> handler` 映射；
- 增加 `customAssets/paymentUri/rpcHealth` capability；自定义资产按钮、资产地址标准化、付款 URI scheme、扫码、收款链筛选和钱包地址展示均由 Adapter 能力与 namespace 驱动；
- 新增扩展性 contract test：在不增加 `WalletChainType` 枚举值的情况下注册 `test-chain` adapter，并注入地址派生、KeyMaterial、余额、手续费、转账、历史、状态和付款 URI 实现，不修改任何中心 Service handler。

### 4.6 P1：密钥 payload 参数缺少严格验证和升级机制

位置：

- `lib/wallet/services/crypto/wallet_secret_store.dart:76`
- `lib/wallet/services/crypto/wallet_secret_store.dart:148`
- `lib/wallet/services/crypto/wallet_secret_store.dart:200`
- `lib/page/home/view/home_page.dart:345`

写入 payload 时保存了 `version`、`kdf`、`iterations`、`salt`、`nonce` 和 `cipherText`，但读取时：

- 不验证 `version` 和 `kdf`；
- 直接信任 `iterations`，没有上下限；
- 不显式校验 salt、nonce、cipherText 的长度和大小；
- 多数字段异常最终会被转换成“密码错误”，损坏和密码错误难以诊断；
- 密码策略只要求至少 6 个字符；
- 成功解密旧参数后没有自动用新安全参数重加密。

本地存储损坏或被篡改时，超大 iterations 可能造成高 CPU 消耗；过短密码也会降低本地加密抵御离线猜测的能力。

建议：

1. 定义版本化 `WalletSecretEnvelope` 并集中解析；
2. 严格校验 version、kdf、iterations 范围、salt/nonce 长度和 cipherText 最大长度；
3. 将“损坏、版本不支持、密码错误”映射为内部不同错误码，UI 可继续使用统一提示；
4. 引入密码强度评估，不只校验长度 6；
5. 解锁旧 payload 成功后后台重加密升级；
6. 增加边界 iterations、错误 version/kdf、截断 nonce、超大 cipherText 和升级测试。

### 4.7 P1：各链“交易成功”语义不一致，EVM/Solana 可能过早标记成功

位置：

- `lib/wallet/services/transaction/wallet_transaction_status_service.dart:55`
- `lib/wallet/services/transaction/wallet_transaction_status_service.dart:73`
- `lib/page/transfer/controller/transfer_status_tracker.dart:56`

当前 EVM 逻辑只把 `0x0` 判定为失败，其余值（包括缺失或异常状态）都会返回 success。更安全的规则应是：

```text
0x1 -> success
0x0 -> failed
其它/缺失 -> unknown
```

Solana 在 signature status 存在且 `err == null` 时立即返回 success，没有检查 `confirmationStatus`。这可能把 `processed` 状态提前展示为最终成功。EVM、Solana、Bitcoin、TRON、Sui、Aptos 当前没有统一的确认级别契约。

仓库中也没有 `WalletTransactionStatusService` 或 `TransferStatusTracker` 的聚焦测试，因此异常 receipt、processed/confirmed/finalized、404、轮询停止和缓存状态更新均未形成回归保护。

建议：

1. 定义统一 `TransactionConfirmation`，包含 `state`、`confirmations/commitment`、`isFinal`；
2. 明确产品使用 Solana `confirmed` 还是 `finalized`；
3. EVM 只接受明确的 `0x1/0x0`；
4. Tracker 仅在达到目标确认级别时停止轮询并写 success；
5. 为六类链补充 pending、unknown、success、failed 和超时测试。

### 4.8 P1：第三方 API Key 被编译进公开客户端产物

位置：

- `lib/wallet/services/wallet_history_api_config.dart:12`
- `scripts/build_android.sh:35`
- `scripts/build_android_bundle.sh:35`
- `README.md:134`

Etherscan、TronGrid、Helius 和 Moralis Key 通过 `--dart-define` 注入，并以 `String.fromEnvironment` 编译进应用。它们不会出现在 Git 仓库源码中，但不能被视为客户端秘密；发布到 GitHub 的 APK、桌面程序或 Web 资源都可能被逆向或搜索出这些值。

风险主要是第三方额度被盗用、计费异常、Key 被封禁后所有已发布客户端同时失效。

建议：

1. 对需要保密、计费或高额度的 API 使用后端代理；
2. 客户端只持有短期、可撤销、受限 token；
3. 暂时不能上代理时，至少配置最小权限、配额、告警和定期轮换；
4. 每个发布环境使用独立 Key，出现泄露时能单独吊销；
5. 文档明确说明 `dart-define` 只避免源码提交，不能保护已发布二进制中的秘密。

### 4.9 P2：GetX Controller 仍在 Widget build 阶段注册

位置：

- `lib/base/base_page.dart:18`
- `lib/generated/route_table.dart:40`

所有 `BaseScaffoldPage` 最终都会在 `BasePage.build()` 中执行：

```dart
if (!Get.isRegistered<T>()) {
  Get.put(generateController());
}
```

路由表没有 Binding。页面构建、依赖创建和生命周期绑定因此耦合在一起，并以 Controller 类型作为全局唯一判断。重复打开相同页面、父级重建、路由参数变化或 Controller 未按预期释放时，都可能复用旧状态。

建议：

1. 由每个 `GetPage` 的 Binding 注册 Controller；
2. 页面只负责 `GetView<T>` 和 UI；
3. 对可能重复打开的详情页明确使用 route-scoped tag 或实例；
4. 建立 Controller 资源释放清单，并测试重复进入/退出后 Timer、listener、TextEditingController 均被释放；
5. 修改路由生成模板，而不是只改 `generated/route_table.dart`。

### 4.10 P2：大文件已拆职责，但底层算法和测试仍过度集中

位置：

- `lib/wallet/services/wallet_transfer_service.dart:47`
- `lib/wallet/services/crypto/wallet_crypto_service.dart:28`
- `test/wallet_crypto_service_test.dart:35`

`WalletTransferService` 虽已把各链流程放入 part 文件，但主库仍同时包含：

- 多链路由；
- ECDSA 签名与公钥恢复；
- EVM/TRON/Solana/Sui/Aptos/Bitcoin 地址规范化；
- amount/raw units 转换；
- RLP、Base58Check、Bech32 和字节工具。

`WalletCryptoService` 同时负责六类链的路径解析、密钥派生、地址编码和助记词。新增链仍会扩大同一个类。

测试侧更明显：`test/wallet_crypto_service_test.dart` 约 2,724 行，但实际包含 WalletAccount、AssetRegistry、自定义资产、Explorer、交易缓存、交易历史、链配置、SecretStore、余额、估值和转账等十多个 group；同时仓库中又存在对应的聚焦测试文件。文件名和覆盖范围不一致，容易产生重复用例和修改遗漏。

建议：

1. 提取 `AmountCodec`、`EvmAddressCodec`、`BitcoinAddressCodec`、`RlpCodec` 等纯模块；
2. 每条链的签名/序列化代码与运行时 Adapter 放在同一模块；
3. `WalletCryptoService` 只编排派生器，不直接实现全部编码算法；
4. 将 2,724 行测试按生产模块迁移，合并与现有聚焦测试重复的用例；
5. 为纯算法保留向量测试，为 Service 保留编排测试，避免同一行为在多个大文件重复验证。

### 4.11 P3：静态分析 info 尚未清零

当前 14 条主要包括：

- `lib/Initializer.dart:1` 文件名不符合 snake_case；
- `lib/page/transfer/view/widgets/transfer_selector_row.dart:134` 使用已弃用表单字段参数；
- `lib/utils/log_util.dart:8` 使用已弃用日志参数；
- `lib/widget/transaction_review_sheet.dart` 多处使用已弃用 `withOpacity`，并有少量可加 `const`；
- `lib/generated/route_table.dart:55` 有生成代码 const 提示。

这些不是运行时故障，但长期保留会降低 Analyzer 对新增问题的信噪比，也可能在 Flutter SDK 升级后转为更严重的问题。

建议建立“业务代码 analyzer info 为 0”的基线；生成文件问题应修改生成模板或在规则中单独管理，不要手工反复修改生成产物。

## 5. 推荐实施顺序

### 第一阶段：发布前安全闭环

1. 禁止 Android Release 回退 Debug 签名，并增加证书校验；
2. 为创建、导入、删除实现钱包存储事务和恢复 journal；
3. 删除钱包时统一清理余额、交易和密码等本地数据；
4. 创建/导入流程接入敏感生命周期和平台屏幕保护；
5. 明确第三方 API Key 代理、限额和轮换方案。

### 第二阶段：交易正确性和密钥存储加固

1. 统一六类链交易确认状态；
2. 增加 TransactionStatusService 和 Tracker 测试；
3. 引入版本化 WalletSecretEnvelope 和参数边界校验；
4. 增强密码策略并设计旧 payload 自动升级。

### 第三阶段：真正完成 ChainAdapter 能力下沉

1. 地址模型从固定字段迁移为映射；
2. 将余额、转账、历史、状态和 KeyMaterial 能力注册到 Adapter；
3. 删除中心 Service 的 WalletChainType handler 表；
4. 用“无需修改中心代码即可注册测试链”的 contract test 验收。

### 第四阶段：工程质量清理

1. Controller 注入迁移到 Bindings；
2. 拆分通用密码学/编码模块；
3. 重组两个超大测试文件；
4. 清零 analyzer info；
5. 再评估 UI 大文件，优先按状态和业务边界拆分，不按行数机械拆分。

## 6. 建议验收清单

- 任意一次钱包写入失败后，不存在不可见密钥或不可解锁钱包；
- 删除钱包并重启后，Secure Storage、余额缓存和交易缓存均无该 walletId 数据；
- 应用切到后台时，创建/导入页面不再保留助记词、私钥和密码；
- Web 打开钱包详情不会触发 `dart:io Platform` 不支持异常；
- Android Release 缺少正式签名时构建失败，证书 fingerprint 不匹配时上传失败；
- EVM 异常 receipt 不会显示成功，Solana 未达到目标 commitment 不会显示最终成功；
- 注册一类测试链时，不修改 WalletAccount、中心 Service handler 和页面排除列表；
- `flutter test --no-pub` 全部通过；
- `flutter analyze --no-pub` 业务代码 info 清零；
- Secret scan 和平台 Release 构建通过。

## 7. 优先级摘要

| 优先级 | 数量 | 建议处理时间 |
| --- | ---: | --- |
| P0 | 0（2 项均已完成） | 已完成，Release 前持续回归 |
| P1 | 4（另 2 项已完成） | P0 完成后的第一个迭代 |
| P2 | 2 | 架构迭代内分批处理 |
| P3 | 1 | 随近期 Flutter 兼容性维护清理 |

如果只选择三个任务立即开始，建议依次选择：

1. 钱包确认状态和广播结果校验；
2. 密钥 payload 参数验证和升级机制；
3. 第三方 API Key 服务端代理。

## 8. 本次复核记录（2026-08-25）

本文件在 2026-08-25 又一次独立复核，确认以下事实成立后定稿：

```bash
flutter analyze --no-pub   # → 14 issues, 全部 info; 0 error / 0 warning
flutter test --no-pub      # → 389 项全部通过 (All tests passed)
bash scripts/check_secrets.sh
```

逐项核对：

- `lib/` 非生成代码 39,296 行；测试文件 56 个；`test/wallet_crypto_service_test.dart` 2,724 行；最大生产文件行数 739 / 672 / 654 / 567 等，均与正文吻合。
- analyzer 的 14 条 info 与第 4.11 节逐一对应：`lib/Initializer.dart:1`（file_names）、`lib/generated/route_table.dart:55`（prefer_const_constructors）、`lib/page/transfer/view/widgets/transfer_selector_row.dart:134`（已弃用 `value` 形参）、`lib/utils/log_util.dart:8`（已弃用 `printTime`）、`lib/widget/transaction_review_sheet.dart` 多处 `withOpacity` 与 `prefer_const_constructors`。
- 第 4.1 节引用的 `lib/base/base_page.dart:20-22` 经读码确认，确实在 `build()` 中执行 `Get.put(generateController())`。
- 第 4.2 节引用的 `android/app/build.gradle.kts:55-59` 经读码确认，`release` 在无 `key.properties` 时确实回退到 `signingConfigs.getByName("debug")`。
- 第 4.6 节引用的 `lib/wallet/services/crypto/wallet_secret_store.dart:76` 经读码确认，PBKDF2 `_iterations = 100000`。

说明：本记录只复核了静态与单元测试层面；真实链转账、第三方 API 集成测试和各平台 Release 构建仍属第 2 节的未执行范围，需在发布流水线中单独完成。

## 9. 第 4.1 节改造验收记录（2026-08-25）

实现文件：

- `lib/wallet/services/wallet_persistence_transaction.dart`；
- `lib/wallet/services/wallet_persistence_coordinator.dart`；
- `lib/wallet/services/wallet_local_data_cleanup_service.dart`；
- `lib/wallet/services/wallet_repository.dart`；
- `lib/wallet/services/crypto/wallet_secret_store.dart`；
- `test/wallet/services/wallet_persistence_transaction_test.dart`。

验证结果：

```bash
flutter test --no-pub
# 410 项全部通过

flutter analyze --no-pub
# 0 error、0 warning；保留审查时已有的 14 条 info

bash scripts/check_secrets.sh
# Sensitive information scan passed.
```

本次未执行真实链转账、真实第三方 API 集成测试和各平台 Release 构建。

## 10. 第 4.2 节改造验收记录（2026-08-25）

实现文件：

- `android/app/build.gradle.kts`；
- `android/release-signing.properties`；
- `scripts/android_release_common.sh`；
- `scripts/build_android.sh`；
- `scripts/build_android_bundle.sh`；
- `test/tooling/android_release_configuration_test.dart`。

验证结果：

- Gradle `signingReport` 构建成功，Release 与 Debug 显示不同证书，Release SHA-256 与固定配置一致；
- Gradle `assembleRelease --dry-run` 成功经过任务图级签名检查，覆盖 `gradlew build` 间接加入 Release 任务的场景；
- `scripts/build_android.sh` 完整构建成功，APK 通过签名、固定证书指纹、`com.zx.wallet`、`1.0.0+1` 和文件名校验；
- `scripts/build_android_bundle.sh` 完整构建成功，AAB 通过 JAR 签名、固定证书指纹和 Release manifest 构建元数据校验；
- 将预期指纹临时替换为错误值后，校验函数按预期返回失败；
- APK/AAB 均生成同名 `.sha256` 文件；
- 新增 `test/tooling/android_release_configuration_test.dart`，防止 Debug 回退、固定指纹和共享校验入口回归。

## 11. 第 4.3 节改造验收记录（2026-08-25）

实现文件：

- `lib/utils/screen_security.dart`；
- `lib/utils/screen_security_platform_io.dart`；
- `lib/utils/screen_security_platform_stub.dart`；
- `lib/widget/secure_screen.dart`；
- `lib/widget/sensitive_data_scope.dart`；
- `lib/page/home/view/widgets/password_setup_sheet.dart`；
- `lib/page/home/view/widgets/import_wallet_sheet.dart`。

验证结果：

- 14 项屏幕保护、敏感作用域、创建和导入生命周期定向测试全部通过；
- `flutter test --no-pub` 共 410 项全部通过；
- `flutter build web --release` 成功，屏幕保护代码未触发 `dart:io Platform` 不支持错误；
- `flutter analyze --no-pub` 为 0 error、0 warning，保留审查时已有的 14 条 info；
- 敏感信息扫描和 `git diff --check` 通过。

## 12. 第 4.5 节改造验收记录（2026-08-25）

主要实现：

- `lib/wallet/models/wallet_account.dart`、`wallet_chain.dart`、`wallet_key_material.dart`；
- `lib/wallet/adapters/chain_adapter.dart`、`chain_adapter_registry.dart`、`chain_operation_registry.dart`；
- `lib/wallet/services/crypto/wallet_crypto_service.dart`、`wallet_repository.dart`；
- 余额、转账、手续费、交易历史、交易状态和 RPC 健康检查服务；
- 扫码、收款、钱包地址展示和自定义资产入口；
- `test/wallet/adapters/chain_adapter_extensibility_contract_test.dart`。

验证结果：

- 扩展性 contract test 覆盖地址持久化、派生、KeyMaterial、余额、手续费、转账、历史、状态和付款 URI；
- `flutter test --no-pub` 共 411 项全部通过；
- `flutter analyze --no-pub` 为 0 error、0 warning，保留审查时已有的 14 条 info；
- Web Release 构建成功；
- 旧钱包 JSON、现有六类链、EVM 自定义网络、TRON/Solana 自定义资产和已有扫码协议定向测试全部通过；
- 敏感信息扫描和 `git diff --check` 通过。
