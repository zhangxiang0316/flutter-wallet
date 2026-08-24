# 代码审查建议（2026-08-24）

## 审查范围

本次重点审查以下方面：

- 大文件和职责集中问题；
- 方法调用封装和依赖方向；
- 链适配器、页面控制器与服务之间的耦合；
- 交易、余额、历史记录流程的逻辑紧密性。

本次只做代码审查，没有修改业务代码。

## 总体结论

当前链适配器已经完成第一轮抽象，代码可以通过 `flutter analyze`，没有发现编译错误或静态分析 error。但转账、余额、交易历史和首页控制器仍保留较多集中式业务逻辑。

新增一条链时，当前仍可能需要同时修改转账服务、余额服务、交易历史服务和页面控制器。后续重点应该从“统一路由”继续推进到“能力由 Adapter 自己实现，业务服务只负责编排”。

## 重点问题

### 1. TransferController 职责过重

文件：`lib/page/transfer/controller/transfer_controller.dart`

定位：[transfer_controller.dart:472](/Users/zhangxiang/workpalce/flutter/flutter-wallet/lib/page/transfer/controller/transfer_controller.dart:472)

文件约 934 行。`submit()` 同时负责：

- 表单校验；
- 余额刷新；
- 手续费估算；
- 私钥读取；
- 按链读取不同密钥；
- 调用转账；
- 保存交易记录；
- 启动交易状态轮询；
- Toast 提示和页面状态更新。

尤其是 498-525 行仍然通过多个链类型判断读取密钥。页面控制器因此直接依赖钱包存储、余额服务、转账服务、交易缓存和交易状态服务。

建议拆分为：

```text
TransferController
 ├── TransferUseCase
 ├── TransferPreflightService
 ├── WalletKeyMaterialProvider
 ├── TransferSubmissionService
 └── TransactionStatusTracker
```

Controller 最终只保留页面状态和用户交互逻辑。

### 2. WalletTransferService 仍是转账总线和密码学实现中心

文件：`lib/wallet/services/wallet_transfer_service.dart`

定位：[wallet_transfer_service.dart:47](/Users/zhangxiang/workpalce/flutter/flutter-wallet/lib/wallet/services/wallet_transfer_service.dart:47)

文件约 739 行，并通过多个 `part` 文件承载 EVM、TRON、Solana、Bitcoin、Sui、Aptos 实现。

`transfer()` 和 `estimateFee()` 中仍维护完整的链处理映射：

- [wallet_transfer_service.dart:103](/Users/zhangxiang/workpalce/flutter/flutter-wallet/lib/wallet/services/wallet_transfer_service.dart:103)
- [wallet_transfer_service.dart:169](/Users/zhangxiang/workpalce/flutter/flutter-wallet/lib/wallet/services/wallet_transfer_service.dart:169)

这意味着新增链仍需要修改核心服务，而不是只注册新 Adapter。

建议让每个 Adapter 直接实现统一能力契约：

```dart
abstract interface class ChainTransferAdapter {
  Future<String> transfer(TransferContext context);
  Future<TransferFeeEstimate> estimateFee(FeeContext context);
}
```

`WalletTransferService` 只负责查找 Adapter、传递上下文和统一错误处理。

### 3. ChainBalanceService 存在重复链路由逻辑

文件：`lib/wallet/services/chain_balance_service.dart`

定位：

- [chain_balance_service.dart:210](/Users/zhangxiang/workpalce/flutter/flutter-wallet/lib/wallet/services/chain_balance_service.dart:210)
- [chain_balance_service.dart:279](/Users/zhangxiang/workpalce/flutter/flutter-wallet/lib/wallet/services/chain_balance_service.dart:279)

`loadBalances()` 和 `loadChainBalances()` 各自维护一套相同的 `WalletChainType` handler 映射。后续修改链逻辑时容易出现一处修改、另一处遗漏。

建议抽取公共方法：

```dart
Future<List<ChainBalance>> _loadByChain({
  required WalletChainConfig chain,
  required String address,
  required List<WalletAsset> assets,
});
```

长期建议让 Balance Adapter 暴露统一的 `loadBalances()` 能力，余额服务不再维护链类型映射。

### 4. 交易历史 Provider 文件过大

实施状态：已完成（2026-08-24）。EVM 已拆分为协调器、Explorer Client、RPC Provider 和 Record Parser；Solana 已拆分为协调器、Helius Provider、RPC Provider 和 Helius Helpers；分页模型也已从统一服务文件移出。

主要文件：

- `lib/wallet/services/transaction_history/evm_transaction_history_provider.dart`，约 898 行；
- `lib/wallet/services/transaction_history/solana_transaction_history_provider.dart`，约 776 行；
- `lib/wallet/services/wallet_transaction_history_service.dart`，约 340 行。

EVM Provider 同时负责 Explorer API、Blockscout API、JSON-RPC、日志分页、交易解析、fallback、游标生成和记录组装。

例如：

- [evm_transaction_history_provider.dart:26](/Users/zhangxiang/workpalce/flutter/flutter-wallet/lib/wallet/services/transaction_history/evm_transaction_history_provider.dart:26)
- [evm_transaction_history_provider.dart:203](/Users/zhangxiang/workpalce/flutter/flutter-wallet/lib/wallet/services/transaction_history/evm_transaction_history_provider.dart:203)

建议拆分为：

```text
EvmHistoryCoordinator
 ├── EvmExplorerClient
 ├── EvmRpcHistoryClient
 ├── EvmHistoryPaginator
 └── EvmTransactionRecordParser
```

Solana Provider 也建议将 Helius、RPC、Token Account 查询和交易解析拆开。

### 5. EVM 原生交易记录可能过早返回空结果

文件：`lib/wallet/services/transaction_history/evm_transaction_history_provider.dart`

定位：[evm_transaction_history_provider.dart:70](/Users/zhangxiang/workpalce/flutter/flutter-wallet/lib/wallet/services/transaction_history/evm_transaction_history_provider.dart:70)

当前逻辑在 Explorer 请求成功但返回空列表时，对原生资产直接返回空结果：

```dart
if (result.records.isNotEmpty || result.hasMore) return result;
if (asset.isNative) return result;
```

如果 Explorer 暂时返回空数据，后续 Provider 或 RPC fallback 不会执行，用户可能看到错误的“没有交易记录”。

建议：

1. Explorer 返回空原生记录时继续尝试下一个数据源；
2. 所有 Provider 都确认无记录后再返回空；
3. 区分“成功查询但无记录”和“Provider 请求失败”。

### 6. Adapter Registry 被页面重复创建

以下页面或组件直接调用 `createDefaultChainAdapterRegistry()`：

- `home_styles.dart`；
- `receive_styles.dart`；
- `transfer_styles.dart`；
- `transfer_review_flow.dart`；
- `transaction_history_styles.dart`；
- `wallet_address_section.dart`；
- `transfer_form_panel.dart`。

例如：[transfer_review_flow.dart:182](/Users/zhangxiang/workpalce/flutter/flutter-wallet/lib/page/transfer/view/widgets/transfer_review_flow.dart:182)

问题包括：

- UI 层直接依赖完整 Adapter 注册表；
- 每次构建样式或弹窗时可能重复创建对象；
- 自定义链注册后，不同调用方可能拿到不同 Registry 实例。

建议在应用 Composition Root 中创建共享 Registry，通过构造函数注入。页面只依赖 `ChainPresentationPolicy`，不要直接依赖完整的 `ChainAdapterRegistry`。

### 7. HomeController 仍承担过多领域职责

文件：`lib/page/home/controller/home_controller.dart`

定位：[home_controller.dart:33](/Users/zhangxiang/workpalce/flutter/flutter-wallet/lib/page/home/controller/home_controller.dart:33)

当前同时负责：

- 钱包创建、导入、删除和切换；
- 明文私钥迁移；
- 新链地址升级；
- 余额刷新和定时器；
- 缓存处理；
- 资产可见性；
- Token Portfolio 聚合；
- USD 估值；
- 页面状态更新。

地址升级逻辑位于：[home_controller.dart:432](/Users/zhangxiang/workpalce/flutter/flutter-wallet/lib/page/home/controller/home_controller.dart:432)

建议拆出：

```text
WalletLifecycleService
WalletMigrationService
WalletAddressUpgradeService
HomeBalanceCoordinator
HomePortfolioPresenter
```

首页 Controller 最终只负责组合和暴露页面状态。

### 8. 余额失败时统一返回零余额，容易掩盖真实故障

文件：`lib/wallet/services/chain_balance_service.dart`

定位：[chain_balance_service.dart:327](/Users/zhangxiang/workpalce/flutter/flutter-wallet/lib/wallet/services/chain_balance_service.dart:327)

当前超时或异常后会调用 fallback，生成零余额对象。风险包括：

- 用户可能误以为余额确实为 0；
- 转账页可能基于错误余额继续执行；
- 网络故障和真实零余额在展示层难以区分。

建议使用明确的结果状态：

```dart
ChainBalanceResult {
  data
  status: success | stale | timeout | unavailable
  errorCode
}
```

UI 只在 `success` 或明确允许的 `stale` 状态下展示可用余额。

### 9. WalletAsset 模型包含过多业务规则

文件：`lib/wallet/models/wallet_asset.dart`

定位：[wallet_asset.dart:59](/Users/zhangxiang/workpalce/flutter/flutter-wallet/lib/wallet/models/wallet_asset.dart:59)

文件约 653 行，同时包含：

- 资产模型；
- JSON 序列化；
- 旧数据迁移；
- canonical token 归类；
- 默认资产注册表；
- 自定义资产合并逻辑。

建议拆成：

```text
wallet_asset.dart
wallet_asset_registry.dart
wallet_asset_serialization.dart
wallet_asset_identity_policy.dart
```

这样新增代币、兼容旧数据和首页归类不会继续堆积在同一个文件。

### 10. 页面生命周期和依赖注入仍有隐患

文件：`lib/base/base_page.dart`

定位：[base_page.dart:20](/Users/zhangxiang/workpalce/flutter/flutter-wallet/lib/base/base_page.dart:20)

Controller 在 `build()` 中执行：

```dart
Get.put(generateController());
```

问题包括：

- 页面构建和依赖注入绑定；
- 可能发生重复构建和重复注册；
- Controller 生命周期不清晰；
- BasePage 无法统一负责释放资源。

另外，`BaseController` 没有统一的 `onClose()` 资源释放约定。Timer、TextEditingController、StreamSubscription 等资源需要由各子类自行管理，容易遗漏。

建议使用 Binding 负责注入，Page 只使用 `GetView`，并在 BaseController 中建立统一的资源释放规范。

## 推荐改造顺序

### 第一阶段：转账链路解耦

1. 拆分 `TransferController.submit()`；
2. 提取 `TransferUseCase` 和 `WalletKeyMaterialProvider`；
3. 将交易状态轮询和交易缓存从 Controller 移出；
4. 增加转账预检、密钥读取和提交失败场景测试。

### 第二阶段：转账 Adapter 化

1. 定义 `ChainTransferAdapter`；
2. 将 EVM、TRON、Solana、Bitcoin、Sui、Aptos 转账实现分别注册；
3. 删除 `WalletTransferService` 中的链类型 handler 映射；
4. 增加 Adapter contract tests。

### 第三阶段：余额和历史记录解耦

1. 抽取 `ChainBalanceService` 公共链路由；
2. 引入统一的余额结果状态；
3. 拆分 EVM/Solana 历史 Provider；
4. 修复 EVM 原生历史空结果的 fallback 行为；
5. 增加分页、超时、fallback 和空结果测试。

### 第四阶段：页面和基础设施整理

1. 统一注入共享 `ChainAdapterRegistry`；
2. 拆分 `HomeController`；
3. 拆分 `WalletAsset` 模型及注册表；
4. 将 GetX Controller 生命周期迁移到 Binding；
5. 补充架构约束测试，避免页面直接创建服务或 Registry。

## 验证情况

已执行：

```bash
flutter analyze --no-pub
```

结果：无 error，共 14 条 info/deprecation 提示。
