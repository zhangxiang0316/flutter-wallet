# Omnicast 项目优化清单

生成日期：2026-07-08

## 当前基线

本清单基于当前本地代码检查，重点关注发布可靠性、钱包高风险路径和维护成本。

最近相关提交：

- `b9b5d1e fix: support evm transaction hash lookup`
- `341b9ac test: add wallet service coverage`

当前验证结果：

```bash
flutter analyze
```

结果：58 个 issue，其中包含 warning、deprecated、lint/info。

```bash
flutter test --concurrency=1 --reporter expanded
```

结果：全量测试仍有 2 个失败，失败集中在交易历史缓存 fallback 场景。

单独验证通过：

```bash
flutter test test/wallet_crypto_service_test.dart --reporter expanded
flutter test test/wallet/services/wallet_transfer_service_rpc_test.dart --reporter expanded
```

说明：转账和旧大测试文件单独运行通过，当前全量失败点更集中在缓存语义，不是转账逻辑本身。

## P0：先恢复全量测试基线

### 1. 修复 TransactionHistoryCache fallback

失败用例：

- `test/wallet/services/transaction_history_cache_test.dart:101`
- `test/wallet/services/transaction_history_cache_test.dart:148`

当前现象：

- 当前 contract-aware cache key 存在但记录为空时，没有 fallback 到 legacy key 的非空记录。
- 过期但非空的远程历史没有作为 stale fallback 返回。

相关代码：

- `lib/wallet/services/transaction/transaction_history_cache.dart`

建议修复：

- `load()` 同时读取 current key 和 legacy key。
- 优先返回未过期且非空的 current records。
- 如果 current records 为空，允许 fallback 到 legacy 非空 records。
- 如果记录已过期但仍非空，可以作为 stale fallback 返回，用于页面先展示旧数据再后台刷新。
- 损坏 JSON 仍然返回 `null`，不要影响页面主流程。

建议验证：

```bash
flutter test test/wallet/services/transaction_history_cache_test.dart
flutter test --concurrency=1
```

### 2. 修复 DioClient.doPatch 运行时风险

相关代码：

- `lib/common/net/dio_client.dart`

当前问题：

`doPatch` 的参数名是 `path`，方法体里调用了 `return path(...)`，实际应调用 Dio 的 `patch(...)`。这会导致 PATCH 请求运行时不可用。

建议修复：

- 将参数改名为 `requestPath`。
- 调用 `patch(requestPath, ...)`。
- 给 `doGet/doPost/doPut/doPatch/doDelete/uploadFile` 的路径参数补 `String` 类型。
- 最好补一个最小单测或 mock adapter 验证 PATCH 方法被正确调用。

## P1：降低钱包路径回归风险

### 1. 收敛 BasePage Controller 注入方式

相关代码：

- `lib/base/base_page.dart`
- `lib/base/base_scaffold_page.dart`
- `lib/widget/line_item.dart`

当前问题：

- `BasePage` 继承 Widget，但持有可变字段 `BuildContext? context`，触发 `must_be_immutable` warning。
- `build()` 内执行 `Get.put(generateController())`，多次 build 时存在重复注入和生命周期不清晰风险。

建议方向：

- 移除 `BasePage.context` 可变字段。
- 页面需要 context 时使用 `build` 参数传递。
- Controller 注册迁移到 GetX Binding 或路由初始化层。
- 如果短期不重构路由，至少在 `Get.put` 前判断 `Get.isRegistered<T>()`，并明确 dispose 策略。

### 2. 清理 analyzer warning 和 correctness 类问题

当前 `flutter analyze` 仍有 58 个 issue。建议优先清理：

- `BasePage.context` 的 `must_be_immutable`。
- `lib/wallet/services/balance/tron_chain_balance.dart` 的 dead code / dead null-aware expression。
- `lib/page/wallet/view/widgets/wallet_password_unlock_sheet.dart` 的 `use_build_context_synchronously`。
- `DropdownButtonFormField.value` deprecated。
- `Logger.printTime` deprecated。
- `Color.withOpacity` deprecated。

低风险 lint 可后续批量处理：

- `Initializer.dart` 文件名。
- 常量命名。
- 无用 import。
- `prefer_const_constructors`。

### 3. 拆分并去重旧的大测试文件

当前 `test/wallet_crypto_service_test.dart` 仍包含大量已经拆到 `test/wallet/services/*` 的用例。

风险：

- 同一逻辑存在两套断言，维护成本高。
- 全量测试输出噪音大，不利于快速定位失败。

建议：

- 保留拆分后的 `test/wallet/services/*` 作为主测试入口。
- 逐步删除或迁移 `wallet_crypto_service_test.dart` 中重复的服务用例。
- 每次删除一组重复测试后跑全量测试，避免误删覆盖点。

## P2：安全与发布流程

### 1. 增加提交前 secret scan

建议扫描内容：

- `.env.local`
- `android/key.properties`
- `*.keystore`
- `*.jks`
- EVM 私钥格式
- 助记词格式
- API key 字段

目标：

防止测试私钥、RPC key、签名文件被误提交。

### 2. 加固 release 构建参数

建议发布构建默认使用：

```bash
flutter build apk --release --obfuscate --split-debug-info=build/debug-info
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info
```

同时明确 debug-info 归档策略，避免线上崩溃无法符号化。

## P2：网络与存储基础设施

### 1. 收敛 DioClient 全局可变 options

当前 `DioClient.updateBaseOptions` 会直接修改单例 Dio 的 `options.baseUrl`、`headers`、`responseType`。

风险：

并发请求或不同业务模块交错调用时，配置可能串到其他请求。

建议：

- 优先在单次请求中传 `Options`。
- 钱包 RPC、价格源、普通业务 API 拆分独立 client。
- 避免持久修改单例 `responseType`。

### 2. 继续推进 Storage 类型化

项目已有 Storage 测试，但仍建议继续控制动态类型边界：

- 缺失值保持可区分，避免 `null` 和空字符串语义混用。
- JSON map/list 使用类型化 API。
- 钱包数据通过 repository 读写，不让业务页面直接操作动态 storage。

## P3：文档整理

当前文档目录有多份优化、完成、交接类文档，信息存在重复。

建议：

- 保留最新优化入口文档。
- 过时阶段性报告移动到 `docs/archive/`。
- README 只放关键入口链接。
- 删除或归档根目录旧文档前，确认团队仍不需要这些入口。

当前未提交文档改动仍存在：

- 删除 `NEXT_STEPS.md`
- 删除 `PROJECT_OPTIMIZATION_REVIEW.md`
- 删除 `PROJECT_OPTIMIZATION_TODO.md`
- 新增 `docs/PROJECT_OPTIMIZATION_REVIEW_2026-07-05.md`

建议更新确认后再统一提交文档整理。

## 推荐落地顺序

1. 修复 `TransactionHistoryCache` 两个失败测试。
2. 修复 `DioClient.doPatch`。
3. 清理 analyzer warning：`BasePage.context`、TRON dead code、async context。
4. 拆分并去重 `wallet_crypto_service_test.dart`。
5. 收敛 `DioClient` 全局 options。
6. 增加 secret scan 和 release 构建安全参数。
7. 整理 `docs/` 和 README 入口。

## 建议修复后验证

```bash
dart format lib test
flutter analyze
flutter test --concurrency=1
flutter test test/wallet/services/transaction_history_cache_test.dart
flutter test test/wallet/services/wallet_transaction_history_service_test.dart
```

涉及发布配置时再执行：

```bash
flutter build apk --release
flutter build appbundle --release
```
