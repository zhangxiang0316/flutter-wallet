# 项目优化清单

## 背景

当前项目已经完成多链钱包、资产余额、转账、交易历史、网络健康检测、自定义 Token、主题/语言设置、README 整理等功能。后续优化重点应放在安全配置、工程卫生、交易历史稳定性、服务拆分和测试覆盖上。

本清单基于当前代码结构整理，优先级从 P0 到 P3 递减。

## P0 近期优先

- [ ] 移除源码里的默认 API Key
  - 文件：`lib/wallet/services/wallet_history_api_config.dart`
  - 当前 `ETHERSCAN_API_KEY` 仍有 `defaultValue`。
  - 建议所有第三方 API Key 只通过 `--dart-define` 或 `.env.local` 注入，不再写入源码默认值。
  - 目的：避免真实 key 被打进包体或误提交。

- [ ] 清理 iOS 构建缓存进入工作区的问题
  - 当前 `scripts/build/ios/XCBuildData/PIFCache/` 下有大量未跟踪文件。
  - 建议在 `.gitignore` 中忽略 `scripts/build/ios/XCBuildData/`。
  - 目的：避免后续提交时误带入本地构建缓存。

- [x] 收敛交易历史旧实现
  - 当前主入口是 `lib/wallet/services/wallet_transaction_history_service.dart`。
  - 已删除旧实现：`lib/wallet/services/transaction_history/transaction_history_service_new.dart` 和 `transaction_history/providers/*_transaction_provider.dart`。
  - 已同步删除旧实现专用接口与缓存文件，避免维护两套交易历史逻辑。

- [x] 日志脱敏和生产关闭
  - 文件：`lib/common/net/dio_interceptor.dart`
  - 已移除 `debugPrint`、`dart:developer.log`、`print` 直接输出。
  - 已统一走 `LogUtil`，并通过 `isDebug` 限制生产环境关闭。
  - 已对 headers、query、body、错误信息中的 token、API key、password、secret、signature、地址、JWT 等敏感内容做脱敏。

## P1 结构优化

- [ ] 继续拆分大文件
  - `lib/wallet/services/transaction_history/evm_transaction_history_provider.dart` 约 1020 行。
  - `lib/wallet/services/asset_valuation_service.dart` 约 882 行。
  - `lib/page/home/controller/home_controller.dart` 约 745 行。
  - `lib/wallet/services/wallet_transfer_service.dart` 约 766 行。
  - `lib/page/home/view/widgets/chain_section.dart` 约 623 行。

- [ ] 资产估值服务拆 Provider
  - 当前 `asset_valuation_service.dart` 包含多个价格源 fallback。
  - 建议按 Binance、OKX、CoinGecko、DeFiLlama、CoinPaprika、CryptoCompare 等拆成独立 provider。
  - 再增加统一调度器、缓存策略和错误类型。

- [ ] 交易历史 Provider 标准化
  - 当前 EVM / Moralis / TRON / Solana 已拆分，但错误类型仍可继续细化。
  - 建议统一返回：
    - `noRecords`
    - `rateLimited`
    - `apiKeyMissing`
    - `apiKeyInvalid`
    - `timeout`
    - `providerFailed`
  - 目的：让 UI 能区分“确实没有记录”和“接口失败”。

- [ ] 统一 RPC fallback 工具
  - 项目已有 `lib/wallet/utils/rpc_retry_helper.dart`。
  - 余额、交易历史、自定义资产、RPC 健康检测中仍存在各自 fallback 逻辑。
  - 建议逐步复用统一 helper，减少重复错误处理和日志格式。

## P2 稳定性与体验

- [ ] 历史记录页增加数据源状态提示
  - 展示当前使用的数据源，例如 Moralis、Helius、TronGrid、Etherscan、Blockscout。
  - 请求失败时提示失败原因，例如 API key 缺失、限流、超时、接口失败。
  - 用户刷新时可以看到正在切换 fallback，而不是只看到“加载失败”。

- [ ] Pending 交易自动恢复
  - 当前本地 pending 记录已能保存和刷新。
  - 建议 App 启动、回到首页或进入交易历史页时自动扫描 pending 记录。
  - 后台刷新 pending、confirmed、failed 状态。

- [ ] 首页余额缓存优先展示
  - 首页进入后先展示 `ChainBalanceCache` 中的旧余额。
  - 后台再刷新链上余额和估值。
  - 目的：降低首页打开时的等待感和失败感。

- [ ] Android Studio 运行配置优化
  - 直接 Run 不会自动读取 `.env.local`。
  - 建议补充 `.run/` 模板或说明，统一注入：
    - `ETHERSCAN_API_KEY`
    - `TRONGRID_API_KEY`
    - `HELIUS_API_KEY`
    - `MORALIS_API_KEY`

- [ ] 国际化审计
  - 检查新增页面和旧页面是否仍有硬编码中文/英文。
  - 新增 key 后统一跑 `flutter pub run intl_utils:generate`。

## P3 工程质量

- [ ] 补充交易历史测试
  - BSC / Arbitrum Moralis 分页测试。
  - Solana Helius 失败 fallback 测试。
  - TronGrid API key/header 测试。
  - 交易历史空记录、限流、接口失败的 UI 文案测试。

- [ ] 补充转账状态测试
  - pending 本地记录生成。
  - confirmed / failed 状态刷新。
  - 失败后重新刷新和区块浏览器入口。

- [ ] 拆分超大测试文件
  - 建议把钱包、转账、余额、交易历史、估值相关测试拆成独立文件。
  - 保持单个测试文件职责清晰，降低维护成本。

- [ ] 增加提交前检查脚本
  - 建议新增 `scripts/check.sh`：
    - `dart format --set-exit-if-changed lib test`
    - `flutter analyze`
    - 关键测试分组
  - 目的：避免格式化变更、缓存文件、生成文件和 lint 问题混进提交。

- [ ] 标准化服务层错误类型
  - 当前部分服务仍直接抛 `StateError` 或普通 `Exception`。
  - 建议定义钱包域错误类型，例如：
    - `WalletRpcException`
    - `WalletTransferException`
    - `WalletHistoryException`
    - `WalletConfigException`
  - 目的：方便 UI 映射友好文案，也方便测试覆盖。

## 建议执行顺序

1. 移除源码默认 API Key。
2. 忽略并清理 iOS PIFCache 构建缓存。
3. 删除或隔离旧交易历史实现。
4. 收敛日志输出并做敏感信息脱敏。
5. 拆分 `asset_valuation_service.dart` 和 `evm_transaction_history_provider.dart`。
6. 补交易历史和转账状态测试。
7. 增加提交前检查脚本。
