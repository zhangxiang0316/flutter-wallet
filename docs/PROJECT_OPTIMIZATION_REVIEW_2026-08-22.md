# Flutter Wallet 项目优化审查与功能路线图

> 审查日期：2026-08-22
> 审查分支：`main`
> 文档目的：记录当前仍需修改的问题、建议新增功能、实施顺序及验收标准。
> 本文仅作为改造计划，不代表对应功能已经实现。

## 1. 当前结论

项目目前已经具备多链钱包的主要基础能力，包括：

- EVM、TRON、Solana、Bitcoin、Sui、Aptos 等链的地址和资产支持；
- 首页按代币聚合资产，并可查看代币在不同链上的余额；
- 钱包创建、导入、加密存储、助记词备份确认；
- 收款二维码、转账确认、风险提示和交易记录；
- 自定义 EVM 网络和代币；
- 余额缓存、骨架屏和后台刷新；
- 中英文、本地主题和生物识别相关设置。

本次检查结果：

- 已跟踪测试共执行 197 项，全部通过；
- `flutter analyze` 没有 error 或 warning；
- 当前有 14 条 info，主要是弃用 API、文件命名和 `const` 建议；
- 项目作为测试钱包已经比较完整；
- 如果准备承载真实资产，仍需优先完成转账签名、手续费、二维码和敏感信息保护等安全闭环。

## 2. 优先级说明

| 优先级 | 含义 | 处理要求 |
| --- | --- | --- |
| P0 | 可能影响资产安全或导致错误签名、错误转账 | 真实资产使用前完成 |
| P1 | 影响数据正确性、稳定性、性能或安全体验 | 下一轮迭代完成 |
| P2 | 架构、工程质量和长期维护问题 | 在新增大型功能前完成 |
| P3 | 产品增强功能 | 按产品价值逐步实施 |

## 3. P0：真实资产使用前必须处理

### 3.1 TRON 节点返回交易的签名前校验（已完成，2026-08-22）

#### 改造前问题

TRON 转账先请求 RPC 节点创建交易，然后直接对节点返回的 `raw_data_hex` 进行签名。当前只检查返回结果是否包含 `raw_data_hex` 或 `transaction`，没有验证交易里的发送方、收款方、金额、Token 合约、调用方法、手续费上限和过期时间是否与用户确认内容一致。

相关代码：

- `lib/wallet/services/transfer/tron_wallet_transfer.dart:84`
- `lib/wallet/services/transfer/tron_wallet_transfer.dart:121`
- `lib/wallet/services/transfer/tron_wallet_transfer.dart:148`
- `lib/wallet/services/transfer/tron_wallet_transfer.dart:244`

#### 实施结果

- 新增 `tron_transaction_validator.dart`，直接解析真正参与签名的 TRON protobuf
  `raw_data_hex`；
- 签名前校验私钥派生地址与发送地址一致；
- TRX 校验唯一合约、合约类型、发送方、收款方、金额和交易有效期；
- TRC20 额外校验 Token 合约、`transfer(address,uint256)` ABI 数据、
  `call_value`、TRC10 附加值和 `fee_limit`；
- 校验 `txID` 必须等于 `SHA-256(raw_data_hex)`；
- 同时校验广播 JSON 的交易意图与实际签名字节一致；
- 新增 15 项专项测试，覆盖正常 TRX/TRC20 及 RPC 篡改场景；
- 已对照 TRON 官方 `Tron.proto` 和合约 protobuf 定义核对字段编号。

#### 改造任务

1. [x] 对节点返回的 TRON 交易结构进行完整解析。
2. [x] 原生 TRX 转账校验：
   - `owner_address`；
   - `to_address`；
   - `amount`；
   - 合约类型；
   - 时间戳和过期时间。
3. [x] TRC20 转账校验：
   - Token 合约地址；
   - `transfer(address,uint256)` 方法；
   - ABI 参数中的收款地址和数量；
   - `call_value`；
   - `fee_limit`。
4. [x] 校验私钥派生的 TRON 地址与交易发送地址一致。
5. [x] 任意字段不一致时停止签名。
6. [x] 增加恶意 RPC 返回内容的对抗测试。

#### 验收标准

- 节点篡改收款地址、金额或合约地址时无法签名；
- 节点篡改手续费上限或过期时间时无法签名；
- 错误钱包私钥无法为当前发送地址签名；
- 正常 TRX 和 TRC20 转账测试继续通过。

### 3.2 转账前余额与原生手续费校验（已完成，2026-08-22）

#### 改造前问题

最终提交阶段只校验金额格式和地址格式，没有完整校验余额：

- 转账金额可能超过当前资产余额；
- 原生币转账没有校验“金额 + 手续费”是否超过余额；
- Token 转账没有校验当前链原生币是否足够支付 Gas；
- 余额可能在确认页打开后发生变化，签名前没有再次检查。

相关代码：

- `lib/page/transfer/controller/transfer_controller.dart:226`
- `lib/page/transfer/controller/transfer_controller.dart:250`
- `lib/page/transfer/controller/transfer_input_validator.dart:38`

#### 完成内容

1. [x] 将余额校验从手续费估算入口提取为独立校验器，所有金额统一转为链上最小单位 `BigInt`。
2. [x] 原生币转账校验 `amount + maxFee <= nativeBalance`。
3. [x] Token 转账分别校验：
   - `tokenAmount <= tokenBalance`；
   - `maxFee <= nativeBalance`。
4. [x] 增加单链余额刷新入口，在用户确认后、读取私钥前重新获取必要余额和手续费。
5. [x] 将“余额不足”“手续费余额不足”“手续费未就绪”和“余额刷新失败”区分成本地化提示。
6. [x] 支持安全的“全部转出”：Token 填写完整余额，原生币自动扣除预估手续费。
7. [x] 增加原生币、Token、零余额、精度和全部转出边界测试。

#### 验收标准

- 原生币余额不足时不能进入签名；
- Token 余额足够但 Gas 币不足时给出明确提示；
- “全部转出”不会因为遗漏手续费而失败；
- 所有计算使用 `Decimal` 或链上最小单位 `BigInt`。

### 3.3 EVM Gas、nonce 和签名交易一致性（已完成，2026-08-22）

#### 改造前问题

EVM 手续费估算阶段使用 `eth_estimateGas`，但真正发送时重新使用固定 Gas Limit。nonce 使用 `latest`，有未确认交易时可能重复使用 nonce。发送前也没有显式校验私钥派生地址与资产发送地址一致。

相关代码：

- `lib/wallet/services/transfer/evm_wallet_transfer.dart:48`
- `lib/wallet/services/transfer/evm_wallet_transfer.dart:96`
- `lib/wallet/services/transfer/evm_wallet_transfer.dart:117`
- `lib/wallet/services/transfer/evm_wallet_transfer.dart:131`

#### 已完成任务

1. [x] 建立不可变的 EVM 交易草稿对象，保存：
   - chain ID；
   - from/to；
   - value/data；
   - nonce；
   - gas limit；
   - gas price 或 EIP-1559 参数；
   - 最大手续费。
2. [x] 确认前刷新余额并生成草稿；发送时复用确认页展示的草稿，不再重新请求或使用固定 Gas 参数。
3. [x] `eth_getTransactionCount` 使用 `pending`。
4. [x] `eth_estimateGas` 增加 20% 安全系数，并设置 1,500,000 Gas 的拒绝上限；只有 RPC 估算失败时才使用链类型兜底值。
5. [x] 根据最新区块 `baseFeePerGas` 自动选择 EIP-1559，支持 `maxFeePerGas`、`maxPriorityFeePerGas` 和 type-2 签名；不支持时回退 legacy。
6. [x] 私钥派生 EVM 地址必须与 `asset.address` 和草稿 `from` 一致。
7. [x] 签名前使用草稿的 from/to/value/data/Gas 参数执行 `eth_call` 模拟。
8. [x] Base L1 数据费上限写入草稿并计入确认页最大手续费，签名广播期间保持不变。
9. [x] 增加 legacy、EIP-1559、pending nonce、非标准 Token Gas、Gas 上限、错误私钥和 Base L1 费回归测试。

#### 验收标准

- 确认页手续费与最终签名交易参数一致；
- 存在 pending 交易时不会重复 nonce；
- 非标准 ERC20 不再固定使用 65,000 Gas；
- 错误私钥无法签名当前账户交易；
- legacy 和 EIP-1559 网络均有覆盖测试。

### 3.4 链感知二维码与付款请求（已完成，2026-08-22）

#### 改造前问题

收款二维码可以携带 chain、symbol、contract、amount 和 memo，但转账扫码目前只提取地址。EVM 地址在多条链通用，因此可能把其他 EVM 网络的二维码地址填入当前网络。

相关代码：

- `lib/page/receive/controller/receive_controller.dart:140`
- `lib/page/transfer/controller/transfer_scan_address_parser.dart:7`
- `lib/page/transfer/controller/transfer_controller.dart:188`

#### 完成内容

1. [x] 新增 `PaymentRequest` 数据模型；填写金额或备注时生成 `omnicast://receive` 链感知 URI，空请求保留纯地址兼容性。
2. [x] 严格解析并保留以下字段：
   - scheme；
   - chain ID；
   - address；
   - symbol；
   - contract；
   - amount；
   - memo。
3. [x] 当前链与二维码链不一致时禁止静默填入，通过二次确认明确展示目标网络并切链。
4. [x] Token 优先按合约匹配；合约不一致时要求用户确认切换资产，不存在的资产直接拒绝。
5. [x] 金额、备注、已有金额覆盖行为全部进入二次确认，确认前不修改表单。
6. [x] 兼容纯地址二维码，并在确认面板明确展示当前使用的网络。
7. [x] 未知 scheme、任意文本、缺失字段、非法金额和损坏地址不再自动提取。
8. [x] 增加 EVM、TRON、Solana、Bitcoin、Sui、Aptos、跨链、Token 合约和纯地址测试。

#### 验收标准

- Polygon 付款请求不能在 Ethereum 页面静默使用；
- Token 合约不一致时能够识别；
- TRON、Solana、Bitcoin、Sui、Aptos 和 EVM 都有解析测试；
- 未知 scheme 或格式损坏时不会自动填入地址。

## 4. P1：数据正确性、性能和安全体验

### 4.1 重构交易风险检查

当前问题：

- 使用 `double` 计算金额和百分比；
- Token 数量与原生币手续费直接比较，单位不一致；
- `historyAddresses` 固定为空，首次收款地址提醒没有生效；
- 部分风险提示为硬编码英文。

相关代码：

- `lib/page/transfer/view/widgets/transfer_review_flow.dart:171`
- `lib/page/transfer/view/widgets/transfer_review_flow.dart:269`
- `lib/page/transfer/view/widgets/transfer_review_flow.dart:307`
- `lib/utils/transaction_risk_checker.dart:32`
- `lib/utils/transaction_risk_checker.dart:73`
- `lib/utils/transaction_risk_checker.dart:101`

改造要求：

1. 全部金额计算使用 `Decimal` 或 `BigInt`。
2. 只有同币种时才比较手续费与转账金额；否则换算成统一法币后比较。
3. 接入链感知的历史收款地址。
4. 使用实际钱包名称，不再显示 `Wallet` 或 `Current Wallet`。
5. 所有风险提示进入 ARB 本地化文件。

### 4.2 敏感信息生命周期保护

当前问题：

- 私钥和助记词解锁后保留在控制器字符串中；
- 应用进入后台时只清除密码缓存，没有清除已展示密钥；
- 复制到剪贴板后不会自动清除；
- Android 已实现 `FLAG_SECURE`，iOS 尚无对应 MethodChannel 实现。

相关代码：

- `lib/page/wallet/controller/wallet_detail_controller.dart:29`
- `lib/page/wallet/view/widgets/wallet_detail_common.dart:21`
- `lib/main.dart:112`
- `lib/utils/screen_security.dart:15`
- `ios/Runner/AppDelegate.swift:5`

改造要求：

1. 私钥和助记词显示增加自动隐藏倒计时。
2. 页面退出、应用 inactive/paused/hidden 时立即清空明文状态。
3. 剪贴板定时清除；清除前确认剪贴板仍是本应用复制的值。
4. iOS 增加应用切换遮罩和录屏/截屏状态处理。
5. 密码输入框关闭输入法学习、建议和自动填充。
6. 增加对应生命周期和平台集成测试。

### 4.3 余额缓存重新绑定链配置

当前问题：

- 自定义 EVM 网络从缓存恢复时 RPC 被构造为 `http://localhost`；
- 内置链的用户 RPC 覆盖值不会随缓存恢复；
- 首页允许展示超过 30 分钟的旧缓存；
- 刷新失败后保留旧余额，但没有展示“旧数据”或更新时间。

相关代码：

- `lib/wallet/services/chain_balance_cache.dart:32`
- `lib/wallet/services/chain_balance_cache.dart:108`
- `lib/wallet/services/chain_balance_cache.dart:164`
- `lib/page/home/controller/home_controller_balance.dart:70`
- `lib/page/home/controller/home_controller_balance.dart:101`

改造要求：

1. 缓存只保存余额快照，不保存可直接使用的 RPC 配置对象。
2. 加载缓存后，根据当前链注册表重新绑定 `WalletChainConfig`。
3. 保存并展示 `asOf`、来源、刷新状态和错误状态。
4. 旧数据仍可展示，但必须明确标识。
5. 缓存资产不能携带占位 RPC 进入转账流程。

### 4.4 修复交易记录合并和首屏加载

当前问题：

- 当前使用 transaction hash 作为主要合并键；
- 同一笔交易包含多个 Token Transfer 事件时可能被合并成一条；
- 本地交易状态串行刷新完成后才加载普通缓存，影响首屏速度。

相关代码：

- `lib/page/transaction/controller/transaction_history_controller.dart:211`
- `lib/page/transaction/controller/transaction_history_controller.dart:238`
- `lib/page/transaction/controller/transaction_history_controller.dart:256`
- `lib/wallet/services/transaction_history/evm_transaction_record_parsers.dart:191`

改造要求：

1. 远程事件使用 `txHash + logIndex/transferIndex` 作为唯一键。
2. 本地提交记录与远程记录使用独立的对账规则。
3. 先展示缓存，再在后台刷新 pending 记录。
4. 状态刷新采用有限并发，不串行等待所有请求。
5. 状态只能单向从 pending 更新到 confirmed/failed，避免旧响应覆盖新状态。

### 4.5 WebView 导航限制

当前区块浏览器 WebView 开启 unrestricted JavaScript，但没有导航域名限制。

相关代码：

- `lib/page/browser/controller/block_explorer_controller.dart:65`
- `lib/page/browser/controller/block_explorer_controller.dart:131`

改造要求：

1. 仅允许 HTTPS；
2. 仅允许当前区块浏览器配置的 host；
3. 跨域链接交给系统浏览器并提示用户；
4. 非必要时关闭 JavaScript；
5. 禁止危险 scheme。

### 4.6 密钥存储和仓储原子性

当前已经使用 PBKDF2-HMAC-SHA256、AES-256-GCM 和平台安全存储，但仍应补充：

- 校验 payload 的 `version` 和 `kdf`；
- 限制 iterations、salt、nonce 和 cipherText 的合法范围；
- 提升密码强度要求，不只要求六位字符；
- 验证旧明文密钥迁移后的删除结果；
- 处理密钥写入成功但钱包元数据写入失败等部分失败场景；
- 删除钱包时避免先删除元数据、后删除密钥造成不一致。

相关代码：

- `lib/wallet/services/crypto/wallet_secret_store.dart:42`
- `lib/wallet/services/crypto/wallet_secret_store.dart:109`
- `lib/wallet/services/crypto/wallet_secret_store.dart:175`
- `lib/wallet/services/wallet_repository.dart:157`
- `lib/wallet/services/wallet_repository.dart:293`
- `lib/wallet/services/wallet_repository.dart:330`

## 5. P2：架构和工程质量

### 5.1 引入 ChainAdapter 注册机制

当前转账、余额、交易历史、交易状态、收款和区块浏览器分别维护链类型分支。添加新的非 EVM 链时，需要修改多个位置，容易出现只实现部分能力的问题。

建议定义统一的 `ChainAdapter`：

```dart
abstract interface class ChainAdapter {
  WalletChainType get type;
  ChainCapabilities get capabilities;

  String deriveAddress(...);
  void validateAddress(String address);
  Future<List<ChainBalance>> loadBalances(...);
  Future<PreparedTransaction> prepareTransfer(...);
  Future<SignedTransaction> sign(...);
  Future<String> broadcast(...);
  Future<TransactionPage> loadHistory(...);
  Future<WalletTransactionStatus> loadStatus(...);
  Uri buildExplorerUrl(...);
}
```

实施原则：

1. 先定义能力模型和接口；
2. 先迁移 EVM，验证自定义 EVM 网络；
3. 再迁移 TRON、Solana、Bitcoin、Sui、Aptos；
4. 删除旧 switch 分发；
5. 新增链只需注册 Adapter、网络元数据和资产配置。

### 5.2 自动化测试与 CI

需要补充的测试：

- TRON 节点篡改交易内容的对抗测试；
- EVM Gas、pending nonce、EIP-1559 和 signer 地址测试；
- Token 余额和原生手续费余额联合校验；
- 全链二维码和链不匹配测试；
- 余额缓存链配置重新绑定和过期状态测试；
- 首页并发刷新、切换钱包和旧请求覆盖测试；
- 同交易多 Token 事件合并测试；
- 密钥写入、迁移、删除的部分失败测试；
- 私钥显示、剪贴板和生命周期 Widget/集成测试；
- 地址、金额、付款 URI 的属性测试或 fuzz 测试。

建议增加 CI 步骤：

```text
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
敏感信息扫描
```

### 5.3 仓库清理

1. 处理 14 条 analyzer info。
2. 将 `lib/Initializer.dart` 重命名为 snake_case 文件名。
3. 替换已弃用的 `withOpacity`、表单 `value` 和 Logger 参数。
4. 从 Git 移除 `scripts/build/ios/` 下已经跟踪的 Xcode 缓存文件。
5. 确认 `/scripts/build/ios/XCBuildData/` 持续被 `.gitignore` 忽略。
6. 更新 `pubspec.yaml` 中的默认项目描述和版本信息。
7. 更新或删除已经与代码不一致的 `TESTING_GUIDE.md`。
8. 为真实崩溃上报实现 `reportError`，避免异步错误被静默标记为已处理。

## 6. P3：推荐新增功能

### 6.1 第一阶段：安全能力

#### 交易模拟和内容解码

- 签名前模拟 EVM 合约调用；
- 展示实际资产变化；
- 解码 approve、transfer、swap 等常见方法；
- 标记无限授权、可疑合约和高滑点；
- 展示最坏情况下的最大手续费。

#### Token 授权管理

- 查询 ERC20 allowance；
- 展示被授权合约和授权额度；
- 支持撤销授权；
- 标记无限授权和未知合约。

#### 交易生命周期管理

- 慢速、标准、快速 Gas 档位；
- 加速 pending 交易；
- 取消 pending 交易；
- nonce 冲突提示；
- pending、confirmed、failed 本地通知。

#### 钱包访问保护

- App 启动锁；
- 后台超过指定时间自动锁定；
- 生物识别解锁；
- 转账签名前可选生物识别确认；
- 助记词备份健康检查。

### 6.2 第二阶段：账户和连接能力

#### 观察钱包与硬件钱包

- 只导入地址，不保存私钥；
- 支持离线签名和二维码签名；
- 后续接入 Ledger 等硬件钱包；
- 清晰区分可签名账户和观察账户。

#### 多账户派生

- 支持同一助记词多个账户；
- 允许选择 derivation index；
- 自动扫描已有余额账户；
- 为不同链展示派生路径。

#### WalletConnect v2

- DApp 会话授权；
- 连接网络和账户权限管理；
- personal_sign；
- EIP-712 typed data；
- 交易签名；
- 会话查看和主动断开；
- 来源域名、签名内容和权限风险提示。

WalletConnect 应在交易模拟、签名意图展示和权限管理完成后再接入。

### 6.3 第三阶段：资产和增长功能

- NFT 资产展示；
- 垃圾 Token/NFT 过滤；
- Token 搜索、收藏和排序；
- 法币切换；
- 价格走势图；
- 持仓成本和盈亏；
- 地址资产变化通知；
- 交易记录 CSV 导出；
- 主网/测试网切换；
- RPC 健康检查和自动切换。

### 6.4 第四阶段：交易聚合

- DEX Swap；
- 多路报价；
- 滑点和价格影响提示；
- 跨链桥；
- 跨链到账状态跟踪；
- 可疑 Token 和路由过滤。

Swap 和跨链桥涉及合约授权、报价可信度、滑点、MEV 和跨链失败恢复，建议最后实施。

## 7. 推荐实施顺序

### 阶段 A：转账安全闭环

1. TRON 返回交易校验；
2. 全链 signer 地址校验；
3. 余额和手续费联合校验；
4. EVM Gas、nonce、EIP-1559；
5. 链感知二维码；
6. 增加对抗测试。

### 阶段 B：数据正确性与隐私

1. 风险计算改为精确数值；
2. 接入真实收款历史；
3. 缓存链配置重新绑定；
4. 交易记录事件级合并；
5. 私钥生命周期和 iOS 屏幕保护；
6. WebView 导航限制。

### 阶段 C：架构和工程质量

1. 清理 analyzer info 和构建缓存；
2. 建立 CI；
3. 定义 ChainAdapter；
4. 分链迁移；
5. 补充 Widget 和 integration tests；
6. 更新项目文档。

### 阶段 D：新增产品能力

1. 交易模拟和授权管理；
2. Gas 档位、加速和取消；
3. App 锁、观察钱包和多账户；
4. WalletConnect；
5. NFT、行情和通知；
6. Swap 和跨链桥。

## 8. 每个任务的完成标准

每项改造完成时应满足：

- 代码经过 `dart format lib test`；
- `flutter analyze` 不新增问题；
- `flutter test` 全部通过；
- 新逻辑包含正常、边界和异常测试；
- 转账相关改动包含恶意或异常 RPC 场景；
- UI 文案同步更新中英文 ARB；
- 涉及生成文件时执行对应生成命令；
- 涉及 UI 时提供 Android 和 iOS 截图；
- 文档状态从“计划”更新为“已完成”，并记录对应提交。

## 9. 本次审查未改动范围

本次审查和文档创建不修改任何钱包业务逻辑，也不处理工作区中原有的未跟踪文件。后续实施时应按本文阶段逐项修改、测试和提交，避免把多项高风险转账改动合并到同一个不可回滚提交中。
