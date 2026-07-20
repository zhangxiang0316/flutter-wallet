# Flutter Wallet 项目优化审查报告

> 审查日期：2026-07-20
>
> 审查范围：`lib/`、`test/`、Android/iOS 配置、依赖与工程配置
>
> 项目规模：约 197 个 Dart 文件、3.7 万行应用代码、24 个测试文件
>
> 说明：本报告基于只读代码审查、`flutter analyze` 和 `flutter test` 结果整理，未修改业务代码。

## 1. 总体结论

项目已经具备较完整的多链钱包能力，包括：

- EVM、TRON、Solana 地址派生、余额查询和转账；
- 私钥、助记词加密存储和旧数据迁移；
- 多数据源交易历史、RPC fallback、缓存与分页；
- 资产估值、自定义网络、自定义资产；
- 较完整的核心服务单元测试。

下一阶段不建议大规模重写。应优先补齐交易签名安全边界、修复当前回归、完善敏感信息生命周期管理，然后再处理测试结构、模块体量和 UI/可访问性。

## 2. 优先级总览

| 优先级 | 优化项 | 主要风险 | 建议完成时间 |
|---|---|---|---|
| P0 | TRON 待签名交易本地复核 | 恶意或异常 RPC 可能篡改待签名交易 | 立即 |
| P0 | 修复 Moralis 分页回归 | 当前测试不通过、额外 API 请求和 fallback 异常 | 立即 |
| P1 | 密码缓存按钱包隔离并在后台清除 | 多钱包密码混用、敏感数据驻留内存 | 1 周内 |
| P1 | 完善截屏、后台快照和剪贴板保护 | 私钥、助记词泄露 | 1 周内 |
| P1 | 提交前校验余额及手续费 | 交易失败、错误的最大金额体验 | 1 周内 |
| P1 | 提升钱包密码与 KDF 升级能力 | 弱密码离线尝试风险 | 2 周内 |
| P2 | 测试去重并建立 CI 门禁 | 测试干扰、回归发现不及时 | 2 周内 |
| P2 | 拆分大文件和统一错误模型 | 维护成本和问题定位成本上升 | 持续进行 |
| P2 | API Key 与网络配置安全治理 | 客户端密钥暴露、HTTP/RPC 风险 | 2–4 周 |
| P3 | 可访问性、国际化和静态分析清理 | 体验与长期维护质量 | 持续进行 |

## 3. P0：必须优先处理

### 3.1 TRON 待签名交易缺少本地复核

#### 现状

TRON 转账先请求 RPC 创建交易，然后直接对 RPC 返回的 `raw_data_hex` 签名：

- `lib/wallet/services/transfer/tron_wallet_transfer.dart:74`
- `lib/wallet/services/transfer/tron_wallet_transfer.dart:121`
- `lib/wallet/services/transfer/tron_wallet_transfer.dart:148`
- `lib/wallet/services/transfer/tron_wallet_transfer.dart:244`

当前只检查返回值是否包含交易和 `raw_data_hex`，没有验证返回交易仍与用户确认内容一致。

用户还可以覆盖内置 TRON RPC，而 Solana/TRON 配置当前仅检查 URL：

- `lib/wallet/services/config/wallet_chain_config_service.dart:275`
- `lib/wallet/services/config/wallet_chain_config_service.dart:428`

#### 风险

不可信、被劫持或实现异常的 RPC 可以返回另一笔待签名交易。如果签名方不复核交易内容，用户界面确认的信息可能与实际签名内容不一致。

#### 修改建议

签名前必须解析并逐字段验证：

- owner 地址等于当前钱包地址；
- 原生转账的收款地址和金额与用户输入一致；
- TRC20 合约地址正确；
- 方法选择器为 `transfer(address,uint256)`；
- ABI 参数中的收款地址、金额正确；
- `call_value`、`fee_limit` 在允许范围内；
- 时间戳、过期时间和链参数合理；
- 私钥派生地址与发送地址一致。

更理想的方案是尽量在本地构造交易，只从节点获取区块引用、资源参数等非决定性数据。

#### 测试要求

增加恶意 RPC 测试，分别篡改：

- 收款地址；
- 金额；
- owner；
- TRC20 合约地址；
- ABI 参数；
- fee limit。

验收标准：任何字段不一致时必须在签名前失败，不能产生签名或广播请求。

### 3.2 修复 Moralis 连续扫描导致的回归

#### 现状

当前工作区为处理“过滤后空页”增加了最多 5 页连续扫描：

- `lib/wallet/services/transaction_history/moralis_evm_transaction_history_provider.dart:58`

但当 Moralis 原始 `result` 本身为空、同时返回 cursor 时，代码仍继续请求下一页，导致已有 fallback 测试失败：

- `test/wallet/services/wallet_transaction_history_service_test.dart:148`

失败表现：期望 Moralis 请求一次，实际请求两次。

#### 修改建议

区分两类空页：

1. 原始 `result` 为空：立即结束 Moralis 扫描，让服务进入 Etherscan/Blockscout fallback。
2. 原始 `result` 非空，但当前资产合约过滤后为空：允许使用 cursor 继续扫描。

同时保留：

- cursor 去重；
- 最大扫描页数；
- 记录 ID 去重；
- 跨页时间倒序；
- API 限流和无效 Key 的错误分类。

#### 验收标准

- 原始空页只请求一次 Moralis；
- 错币种占满第一页时可以继续到下一页；
- cursor 重复时停止；
- 达到最大扫描页数后停止；
- `flutter test test/wallet/services/wallet_transaction_history_service_test.dart` 全部通过。

## 4. P1：安全与交易正确性

### 4.1 密码缓存需要按钱包隔离

#### 现状

`lib/utils/password_cache_service.dart:9` 使用全局静态字段缓存一个密码，没有记录对应的 `walletId`。密码缓存默认开启，且没有全局应用生命周期清理逻辑。

#### 问题

- 多个钱包使用不同密码时可能读取到不属于当前钱包的缓存；
- 应用进入后台或锁屏后，密码仍可能驻留内存；
- 修改密码、移除钱包或切换钱包后没有统一失效机制；
- 缓存功能默认开启，用户可能不了解其行为。

#### 修改建议

将缓存模型改为：

```dart
class CachedWalletCredential {
  const CachedWalletCredential({
    required this.walletId,
    required this.password,
    required this.expiresAt,
  });

  final String walletId;
  final String password;
  final DateTime expiresAt;
}
```

并做到：

- 获取缓存时必须传入 `walletId`；
- 切换钱包、删除钱包、修改密码时清除；
- 应用进入 `inactive`、`paused`、`detached` 时清除；
- 生物识别只负责授权读取当前钱包缓存；
- 建议默认关闭，或首次启用时明确说明风险。

### 4.2 敏感页面保护范围不完整

#### 现状

Android 已通过 `FLAG_SECURE` 阻止截屏：

- `android/app/src/main/kotlin/com/zx/wallet/MainActivity.kt:37`

但 iOS 没有发现对应的 `screen_security` MethodChannel 实现。Dart 层调用失败后会静默忽略：

- `lib/utils/screen_security.dart:15`

`SecureScreen` 主要用于钱包详情页，而以下敏感流程没有统一保护：

- 创建钱包后展示助记词：`lib/page/home/view/widgets/password_setup_sheet.dart:141`
- 导入助记词或私钥：`lib/page/home/view/widgets/import_wallet_sheet.dart:83`

#### 修改建议

- 在 iOS 实现对应 MethodChannel；
- 应用进入后台时覆盖模糊或纯色遮罩，避免任务切换器快照泄露；
- 将保护提升到完整的创建、导入、备份、查看密钥流程；
- 原生调用失败时保留脱敏诊断信息，不能完全静默；
- 真机测试 Android 截屏、录屏和 iOS app switcher 快照。

### 4.3 私钥和助记词剪贴板治理

#### 现状

钱包详情页会把任意展示值写入系统剪贴板：

- `lib/page/wallet/view/widgets/wallet_detail_common.dart:21`

复制后没有自动清理。

#### 修改建议

- 私钥、助记词复制前增加二次确认和风险提示；
- 助记词默认不提供整体复制，或允许逐词查看；
- 30–60 秒后读取剪贴板，只有内容仍等于原敏感值时才清除；
- 应用进入后台时尝试清除本应用写入的敏感剪贴板；
- 地址和交易哈希不需要采用同样严格的清理策略。

### 4.4 提升钱包密码强度和 KDF 可升级性

#### 现状

钱包密码目前只要求至少 6 个字符：

- `lib/page/home/view/home_page.dart:334`

密钥存储采用 PBKDF2-HMAC-SHA256 和 AES-GCM：

- `lib/wallet/services/crypto/wallet_secret_store.dart:42`

加密 payload 虽保存了 `version`、`kdf`、`iterations`，读取时尚未严格验证 version/kdf，也没有自动升级弱参数的流程。

#### 修改建议

- 增加密码强度检测，阻止常见弱密码；
- 建议更长的密码或短语，并提供强度提示；
- 严格校验 payload 的 version、kdf、salt、nonce 和 iterations 范围；
- 解锁成功后检测旧 KDF 参数，并自动重新加密为当前参数；
- 为 KDF 升级、损坏 payload、超大 iterations 增加测试。

### 4.5 提交前重新校验余额和手续费

#### 现状

提交前的校验只验证金额格式和地址：

- `lib/page/transfer/controller/transfer_controller.dart:226`

余额比较只用于判断是否进行手续费估算：

- `lib/page/transfer/controller/transfer_input_validator.dart:26`

#### 修改建议

在确认页和真正提交前分别校验：

- 转账金额不能超过资产余额；
- 原生币必须满足 `amount + fee <= nativeBalance`；
- Token 转账必须有足够原生币支付 gas、energy 或 rent；
- 手续费估算过期或输入改变时必须重新估算；
- 防止用户确认后资产、链、地址或金额被异步状态改变；
- 提供“最大金额”计算，自动预留手续费。

#### 验收标准

- 原生币全额转账不会因未预留手续费而广播失败；
- Token 余额足够但 gas 币不足时，在签名前给出明确提示；
- 确认页内容和实际签名参数完全一致。

## 5. P2：工程与架构优化

### 5.1 测试去重和稳定性

#### 现状

`test/wallet_crypto_service_test.dart` 约 2670 行，与 `test/wallet/**` 下拆分后的测试存在大量重复。

本次验证结果：

- 全量测试出现 187 个通过、3 个失败；
- 聚合测试文件单独运行可以通过；
- 交易历史拆分测试可以稳定复现 1 个 Moralis 请求次数失败。

重复测试和共享 mock 状态会增加执行时间，也可能产生并行干扰。

#### 修改建议

- 删除聚合测试中已拆分的重复用例；
- 每个测试文件独立初始化 `SharedPreferences` 和 mock；
- 避免跨测试静态状态；
- 将大型 `_FallbackRpcAdapter` 按链或服务拆分；
- CI 同时运行默认并行测试和 `flutter test -j 1`；
- 增加 Widget 和 integration 测试目录。

### 5.2 静态分析清零并纳入 CI

本次 `flutter analyze` 共报告 49 项，其中两个 warning：

- `lib/wallet/services/balance/tron_chain_balance.dart:166` 存在死代码；
- 同一位置存在永远不会执行的 null fallback。

其余主要包括：

- 弃用 API；
- `BuildContext` 跨异步间隔；
- 文件、变量和常量命名；
- 缺少 `const`；
- 无用 import。

建议分两阶段处理：

1. 立即做到 error/warning 为零，并设置 CI 阻断。
2. 逐步清理 info，必要时只对明确的遗留代码使用局部 ignore。

### 5.3 拆分大文件

建议优先处理以下高复杂度文件：

- `lib/wallet/services/transaction_history/evm_transaction_history_provider.dart`
- `lib/wallet/services/transaction_history/solana_transaction_history_provider.dart`
- `lib/page/transfer/controller/transfer_controller.dart`
- `lib/page/home/controller/home_controller.dart`
- `lib/page/setting/view/widgets/add_custom_asset_sheet.dart`

推荐拆分边界：

- API Client：只负责请求与响应状态；
- Parser：只负责把响应转换为领域模型；
- Provider/Strategy：只负责数据源路由和 fallback；
- Controller：只维护页面状态和触发 use case；
- Validator：集中管理输入和业务约束；
- Error Mapper：把领域错误映射为本地化 UI 信息。

### 5.4 统一错误模型和可观测性

项目中仍有较多 `catch (_)`，用户只能看到统一失败 Toast，开发阶段也难以定位具体 provider、RPC 和错误类型。

建议：

- 定义 `WalletFailure`、`TransferFailure`、`RpcFailure` 等领域错误；
- 区分超时、限流、API Key、RPC 响应错误、余额不足和数据损坏；
- 日志只记录脱敏后的链、provider、方法、状态码和错误分类；
- 不记录私钥、助记词、密码、签名和完整敏感 payload；
- 为关键 fallback 建立计数，便于判断某个数据源是否长期不可用。

### 5.5 API Key 和自定义网络配置

#### 现状

交易历史 API Key 通过编译参数注入客户端：

- `lib/wallet/services/wallet_history_api_config.dart:12`

自定义 explorer API Key 会随网络配置序列化到 `SharedPreferences`：

- `lib/wallet/models/wallet_chain.dart:209`
- `lib/wallet/services/config/wallet_chain_config_service.dart:81`

网络 URL 允许 `http://`：

- `lib/wallet/services/config/wallet_chain_config_service.dart:428`

#### 修改建议

- 不能把移动端编译参数中的 Key 当成真正秘密；
- 对需要保密或计费的第三方 API，使用后端代理、短期令牌、域名/配额限制；
- 用户自定义 explorer Key 存入安全存储，配置对象只保存引用；
- 默认只允许 HTTPS；开发模式需要 HTTP 时明确提示并单独放行；
- 对自定义 RPC 显示信任风险提示；
- Solana/TRON RPC 增加链身份和基本能力检查。

## 6. P3：体验与维护

### 6.1 国际化清理

仍存在少量硬编码 UI 文案，例如：

- `lib/widget/base_easy_refresh.dart`
- `lib/page/wallet/view/widgets/wallet_password_unlock_sheet.dart:85`

建议全部迁移到 `intl_en.arb` 和 `intl_zh.arb`，并在 CI 增加语言 Key 一致性检查。

### 6.2 可访问性

项目已经在部分核心按钮使用 `Semantics` 和 `tooltip`，但需要继续覆盖：

- 纯图标按钮；
- 二维码、地址和余额；
- 密码强度及错误提示；
- 交易状态变化；
- 自定义手势组件；
- 大字体和系统缩放；
- 屏幕阅读器下的助记词展示策略。

### 6.3 UI 性能

现有代码已经处理部分动画生命周期和请求 ID 防旧响应覆盖。后续建议：

- 使用 Flutter DevTools 对首页和长交易列表做真机 profile；
- 避免大范围 `GetBuilder.update()` 导致整页重建；
- 将余额、价格、展开状态拆分为更小的更新域；
- 长列表使用惰性构建并控制图片缓存；
- 对持续动画支持系统“减少动态效果”设置。

## 7. 已有优势

以下设计建议保留并继续完善：

- 私钥和助记词使用 AES-GCM 加密；
- 密文存入 `flutter_secure_storage`；
- 钱包元数据序列化时排除私钥；
- Android 已禁用应用数据备份；
- EVM 和 Solana 主要采用本地构造和签名；
- 金额处理使用 `Decimal`/`BigInt`，避免浮点数直接参与链上金额；
- 余额、估值和交易历史具有缓存、超时和 fallback；
- provider 和解析辅助类已经开始拆分；
- 未发现提交到 Git 的真实 `.env`、keystore 或明显硬编码秘密；
- 核心钱包纯逻辑已有较好的单元测试基础。

## 8. 推荐实施计划

### 第 1 阶段：立即处理

- [ ] 修复 Moralis 原始空页继续扫描问题；
- [ ] 恢复交易历史测试全绿；
- [ ] TRON 签名前复核 owner、to、amount、contract、ABI 参数和 fee limit；
- [ ] 增加恶意 TRON RPC 测试；
- [ ] 修复 `flutter analyze` 的两个 warning。

### 第 2 阶段：1–2 周

- [x] 密码缓存绑定钱包 ID；
- [x] 应用进入后台或退出时清除全部密码缓存；
- [ ] iOS 敏感页面快照遮罩；
- [ ] 创建、导入和备份流程启用屏幕保护；
- [ ] 敏感剪贴板定时清理；
- [ ] 提交前校验余额和手续费；
- [ ] 增加原生币最大金额功能。

### 第 3 阶段：2–4 周

- [ ] 测试去重并拆分大型 mock adapter；
- [ ] 建立 CI：format、analyze、test、构建 smoke test；
- [ ] 统一领域错误模型和脱敏日志；
- [ ] API Key 迁移到代理或安全存储；
- [ ] 默认拒绝生产环境 HTTP RPC；
- [ ] 开始拆分交易历史和 Controller 大文件。

### 第 4 阶段：持续改进

- [ ] 补充 Widget 和 integration 测试；
- [ ] 完成国际化和 Semantics 审计；
- [ ] 真机性能 profile；
- [ ] Android/iOS 发布配置和安全测试；
- [ ] 定期进行依赖、签名流程和链协议兼容性审查。

## 9. 提交前验收命令

```bash
dart format lib test
flutter analyze
flutter test
flutter test -j 1
flutter build apk --release
```

涉及密钥、转账或平台安全功能时，还应执行 Android/iOS 真机验证，不能只依赖单元测试。
