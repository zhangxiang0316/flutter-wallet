# 项目优化清单

## P0 近期优先

- [x] 移除源码里的默认 API Key
  - 文件：`lib/wallet/services/wallet_history_api_config.dart`
  - 已移除 `ETHERSCAN_API_KEY` 的源码 `defaultValue`。
  - 所有第三方 API Key 只通过 `--dart-define` 或 `.env.local` 注入。
  - 目的：避免真实 key 被打进包体或误提交。

- [ ] 统一关闭/收敛敏感日志
  - 重点文件：
    - `lib/utils/biometric_auth.dart`
    - `lib/utils/password_cache_service.dart`
    - `lib/page/home/controller/home_controller.dart`
    - `lib/wallet/services/asset_valuation_service.dart`
    - `lib/wallet/services/transaction_history/*`
  - 建议统一走 `LogUtil`，并只在 debug 模式输出。
  - 日志中避免输出地址、API Key、私钥、助记词、签名、交易参数等敏感内容。

## P1 结构优化

- [ ] 继续拆分大文件
  - 第一阶段已完成：
    - `lib/page/transfer/view/widgets/transfer_form_panel.dart` 已拆出交易审查流程和密码弹窗，主文件从约 601 行降到约 136 行。
    - `lib/page/transfer/controller/transfer_controller.dart` 已拆出资产 key/去重、扫码地址解析、输入校验，主文件从约 623 行降到约 524 行。
  - `lib/wallet/services/transaction_history/evm_transaction_history_provider.dart` 约 1045 行。
  - `lib/wallet/services/transaction_history/solana_transaction_history_provider.dart` 约 847 行。
  - `lib/page/home/controller/home_controller.dart` 约 745 行。
  - `lib/wallet/services/config/wallet_custom_asset_service.dart` 约 632 行。
  - 后续建议继续拆 `evm_transaction_history_provider.dart` 和 `solana_transaction_history_provider.dart`。

- [ ] 转账服务错误类型标准化
  - 当前 EVM / TRON / Solana 转账逻辑仍有较多 `StateError`。
  - 建议新增 `WalletTransferException`，区分：
    - `insufficientBalance`
    - `invalidAddress`
    - `rpcFailed`
    - `broadcastFailed`
    - `signatureFailed`
    - `unsupportedChain`
  - 目的：让 UI 能展示更准确的失败原因。

- [ ] 历史记录页展示数据源状态
  - 当前交易历史错误类型已经标准化，但 UI 仍缺少数据源状态展示。
  - 建议展示当前使用的数据源：
    - Moralis
    - Helius
    - TronGrid
    - Etherscan
    - Blockscout
    - RPC Logs
  - 请求失败时展示原因：无记录、限流、API Key 缺失、API Key 无效、超时、数据源失败。

## P2 稳定性与体验

- [ ] 首页余额缓存优先展示
  - 项目已有 `ChainBalanceCache`。
  - 建议首页进入后先展示缓存余额，再后台刷新链上余额和估值。
  - 目的：降低首页打开等待感，减少 RPC 失败带来的空白体验。

- [ ] Pending 交易自动恢复
  - 当前本地 pending 记录已有保存和刷新能力。
  - 建议在以下时机自动扫描 pending 记录：
    - App 启动
    - 回到首页
    - 进入交易历史页
  - 自动刷新 pending、confirmed、failed 状态。

- [ ] Android Studio 运行配置优化
  - 直接 Run 不会自动读取 `.env.local`。
  - 建议补充 `.run/` 模板或文档，统一注入：
    - `ETHERSCAN_API_KEY`
    - `TRONGRID_API_KEY`
    - `HELIUS_API_KEY`
    - `MORALIS_API_KEY`

## P3 工程质量

- [ ] 拆分测试文件
  - 当前 `test/wallet_crypto_service_test.dart` 覆盖范围过大。
  - 建议拆成：
    - `test/wallet_crypto_service_test.dart`
    - `test/wallet_transaction_history_service_test.dart`
    - `test/chain_balance_service_test.dart`
    - `test/asset_valuation_service_test.dart`
    - `test/wallet_transfer_service_test.dart`

- [ ] 增加提交前检查脚本
  - 建议新增 `scripts/check.sh`：
    - `dart format --set-exit-if-changed lib test`
    - `flutter analyze`
    - 关键测试分组
  - 目的：避免格式化变更、缓存文件、生成文件和 lint 问题混进提交。

- [ ] 标准化服务层错误类型
  - 当前部分服务仍直接抛 `StateError` 或普通 `Exception`。
  - 建议逐步定义钱包域错误类型：
    - `WalletRpcException`
    - `WalletTransferException`
    - `WalletHistoryException`
    - `WalletConfigException`
  - 目的：方便 UI 映射友好文案，也方便测试覆盖。

## 建议执行顺序

1. 移除源码默认 API Key。
2. 统一关闭/收敛敏感日志。
3. 标准化转账服务错误类型。
4. 历史记录页展示数据源状态。
5. 首页余额缓存优先展示。
6. Pending 交易自动恢复。
7. 拆分转账和首页相关大文件。
8. 拆分测试文件并补提交前检查脚本。
