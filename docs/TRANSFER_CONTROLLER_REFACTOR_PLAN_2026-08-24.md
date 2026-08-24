# TransferController 解耦改造方案

## 目标

降低 `TransferController` 的领域职责，保持现有转账流程和页面交互不变，让页面控制器只负责：

- 表单和页面状态；
- 调用校验器；
- 调度转账用例；
- 将领域结果转换为 Toast、页面状态和导航结果。

## 当前问题

文件：`lib/page/transfer/controller/transfer_controller.dart`

当前 Controller 同时依赖并协调：

1. 输入校验和资产切换；
2. 余额刷新和手续费预估；
3. 自定义 Token decimals 校验；
4. 钱包密码解锁和各链私钥读取；
5. 各链交易构造和广播；
6. 本地交易记录写入；
7. 交易状态轮询；
8. 区块浏览器跳转和页面提示。

其中 `submit()` 还直接按链类型读取不同私钥，再调用 `WalletTransferService`，导致新增链时页面控制器也可能需要修改。

## 本次改造边界

本次先处理最紧密的“转账执行链路”，不一次性重写整个页面：

```text
TransferController
  └── TransferExecutionService
        ├── 刷新链余额
        ├── 校验 Token decimals
        ├── 重新估算手续费
        ├── 校验资产余额和原生手续费余额
        ├── 读取对应链密钥
        └── 调用 WalletTransferService 广播交易
```

Controller 继续保留页面特有逻辑：

- `isSubmitting`、`feeEstimate`、`transactionHash` 等响应式状态；
- 输入框和资产选择；
- 收款地址历史缓存；
- 本地交易记录展示和状态轮询；
- Toast、导航和剪贴板操作。

## 新增服务设计

新增文件：`lib/page/transfer/controller/transfer_execution_service.dart`

### `TransferPreflightResult`

用于返回一次完整的转账前检查结果：

- 刷新后的资产；
- 刷新后的同链余额列表；
- 刷新后的原生币余额；
- 最新手续费估算。

### `TransferExecutionService.refreshPreflight()`

负责：

1. 根据资产链配置刷新单链余额；
2. 找到刷新后的同一资产；
3. 拒绝余额查询失败或缺少原生币余额的结果；
4. 校验自定义 EVM Token 的 decimals；
5. 重新估算手续费，或复用确认页冻结的 EVM 交易草稿；
6. 执行资产余额和原生手续费余额校验。

该方法不依赖 Flutter UI，不弹 Toast，只通过返回值或异常表达结果。

### `TransferExecutionService.submit()`

负责：

1. 再次执行转账前检查；
2. 按链从 `WalletRepository` 读取所需密钥材料；
3. 将统一的转账上下文传给 `WalletTransferService`；
4. 返回交易 hash 和最终使用的资产/手续费信息。

Controller 只处理异常到本地化提示的转换。

## 依赖方向

改造后依赖方向为：

```text
TransferController
       ↓
TransferExecutionService
       ↓
WalletRepository / ChainBalanceService / WalletTransferService
       ↓
ChainAdapterRegistry
```

页面层不再直接读取各链私钥，也不再直接编排余额刷新和交易广播。

## 实施步骤

1. 新增 `TransferExecutionService`、预检结果和执行结果模型；
2. 将 Controller 中的 `_refreshTransferPreflight()` 迁移到服务；
3. 将 Controller 中按链读取私钥和调用转账服务的代码迁移到服务；
4. 调整 `prepareTransferReview()` 和 `submit()` 使用新服务；
5. 删除 Controller 中不再使用的 Repository、BalanceService、WalletTransferService 和 CustomAssetService 依赖；
6. 保留本地交易记录、状态轮询和页面状态在 Controller 内；
7. 增加服务层单元测试，覆盖余额失败、手续费不足、缺少链密钥和提交成功场景；
8. 执行格式化、静态分析和转账相关测试。

## 风险控制

- 不修改 `WalletTransferService` 的链上交易构造逻辑；
- 不修改页面公开方法签名；
- 预检仍在确认页和密码提交前各执行一次；
- EVM 确认页冻结的 `evmDraft` 继续原样传递到最终提交；
- 所有 UI 文案继续由 Controller 使用本地化资源展示。

## 后续改造

本次完成后，还可以继续拆分：

- `TransferStatusTracker`：交易状态轮询和本地记录更新；
- `TransferFormState`：输入框、资产选择和付款请求状态；
- `TransferReviewUseCase`：确认页数据和风险检查；
- `ChainTransferAdapter`：让 `WalletTransferService` 不再维护链类型 handler 映射。

## 本轮实施结果（2026-08-24）

已完成：

- `TransferExecutionService`：余额预检、手续费估算、链密钥读取和交易广播；
- `TransferStatusTracker`：本地交易记录、状态刷新、轮询和 Timer 生命周期；
- `TransferFormService`：付款请求解析、资产匹配、输入校验和最大金额计算。
- `TransferReviewUseCase`：确认页预检和收款地址历史加载；
- `TransferPageState`：页面临时状态集中管理。

`TransferController` 已从约 934 行降至约 670 行，页面公开调用接口保持不变。剩余 Controller 代码主要是页面事件协调、输入框同步、Toast 和导航，不再直接编排链上执行、状态轮询或付款请求解析。
