# 项目优化清单

## 背景

当前项目已经完成了交易历史、转账、余额服务和首页钱包概览的大文件拆分，但仍有一些结构、稳定性、测试和工程卫生问题需要继续处理。以下清单按优先级整理，优先处理会影响运行稳定性、提交质量和后续维护成本的事项。

## P0 近期优先

- [ ] 清理 iOS 构建缓存进入工作区的问题
  - 当前 `scripts/build/ios/XCBuildData/PIFCache/` 下有大量未跟踪文件。
  - 建议确认这些文件是否应加入 `.gitignore`，避免后续误提交。

- [ ] 修复 SPL Token 转账测试
  - `flutter test test/wallet_crypto_service_test.dart` 目前仍有旧用例失败：
    `WalletTransferService submits SPL token transfer through RPC`。
  - 失败点是 Solana token account balance mock 数据结构无法被 `_findSolanaTokenAccount` 正确解析。
  - 建议补齐 mock 中 `account.data.parsed.info.tokenAmount.amount` 结构。

- [ ] 移除或收敛旧交易历史实现
  - 现在存在新拆分后的 `transaction_history/*_transaction_history_provider.dart`。
  - 同时还存在旧目录：`transaction_history/providers/*_transaction_provider.dart` 和 `transaction_history_service_new.dart`。
  - 建议确认旧实现是否仍被引用；未引用则删除，避免后续维护两套历史记录逻辑。

- [ ] 控制调试日志输出
  - `dio_interceptor.dart`、`asset_valuation_service.dart` 等处有大量日志。
  - 建议统一走 `LogUtil` 或按 `kDebugMode` 限制，避免生产环境输出地址、交易、签名、请求参数等敏感信息。

## P1 结构优化

- [ ] 继续拆分大控制器和大页面
  - `network_management_page.dart` 约 1000 行，建议拆成 controller、RPC list、chain form、health card 等组件。
  - `home_controller.dart` 约 745 行，建议拆分资产加载、钱包管理、估值刷新、可见性过滤等职责。
  - `address_book_page.dart` 约 723 行，建议拆出列表、表单弹窗、联系人选择逻辑。
  - `transfer_controller.dart` 约 623 行，建议拆出手续费估算、交易提交状态、地址簿/风险检测适配。

- [ ] 收敛资产估值服务
  - `asset_valuation_service.dart` 仍接近 900 行。
  - 建议按数据源拆分：Binance、OKX、CoinGecko、DeFiLlama、CoinPaprika、CryptoCompare。
  - 增加统一 price provider 接口和缓存策略，减少单文件 fallback 分支。

- [ ] 拆分 UI 大组件
  - `chain_section.dart`、`transfer_form_panel.dart`、`add_custom_asset_sheet.dart` 仍偏大。
  - 建议按 header、list item、empty/error state、form section、action bar 拆分。

- [ ] 统一 RPC fallback 工具
  - 项目已有 `wallet/utils/rpc_retry_helper.dart`，但余额、交易历史、自定义资产、RPC 健康检测里仍有各自 fallback 循环。
  - 建议逐步复用一个统一请求 helper，减少错误处理和日志格式重复。

## P2 稳定性与体验

- [ ] Android Studio 运行配置优化
  - 直接 Run 不会读取 `.env.local`。
  - 建议增加说明文档或生成 `.run/` 配置模板，统一注入 `ETHERSCAN_API_KEY`、`TRONGRID_API_KEY`、`HELIUS_API_KEY`。

- [ ] 历史记录错误状态继续细化
  - 当前已区分 provider failure 和 rate limit。
  - 建议进一步区分 API key 缺失、API key 无效、网络超时、地址无交易、链不支持。

- [ ] Pending 交易恢复机制
  - 当前本地 pending 记录已能保存和刷新。
  - 建议 App 启动或进入首页时自动扫描 pending 记录，并后台刷新状态。

- [ ] 余额缓存和刷新策略统一
  - 当前余额刷新依赖链上请求，部分链超时时体验仍重。
  - 建议引入 `ChainBalanceCache` 到首页读取流程：先显示缓存，后台刷新。

- [ ] 国际化审计
  - 检查新增页面和旧页面是否仍有硬编码中文/英文。
  - 每次新增 key 后继续统一跑 `flutter pub run intl_utils:generate`。

## P3 工程质量

- [ ] 拆分 `test/wallet_crypto_service_test.dart`
  - 当前测试文件约 1800 行。
  - 建议拆成：
    - `wallet_crypto_service_test.dart`
    - `wallet_transfer_service_test.dart`
    - `chain_balance_service_test.dart`
    - `wallet_transaction_history_service_test.dart`
    - `asset_valuation_service_test.dart`

- [ ] 增加提交前检查脚本
  - 建议新增 `scripts/check.sh`：
    - `dart format --set-exit-if-changed lib test`
    - `flutter analyze`
    - 关键测试分组
  - 避免生成文件、缓存文件、格式化变更混进提交。

- [ ] 补充 `.gitignore`
  - 确认忽略：
    - `scripts/build/ios/XCBuildData/`
    - `*.bak`
    - 本地报告或临时分析输出
  - 如 `OPTIMIZATION_REPORT.md` 是临时文件，也建议忽略或移到 docs 并纳入管理。

- [ ] 错误类型标准化
  - 当前服务层大量直接抛 `StateError` 或 `Exception`。
  - 建议定义钱包域错误类型，例如 `WalletRpcException`、`WalletTransferException`、`WalletHistoryException`，方便 UI 转换友好文案。

- [ ] 生产安全审计
  - 检查日志中是否会输出地址、签名、tx data、私钥相关信息。
  - 检查截图保护、密码缓存、私钥展示页面是否符合预期。
  - 检查 API Key 是否只通过 `--dart-define` 注入，避免写入源码。

## 建议执行顺序

1. 清理工作区缓存和 `.gitignore`。
2. 修复 SPL Token 转账测试。
3. 删除或隔离旧交易历史实现。
4. 拆分 `network_management_page.dart` 和 `home_controller.dart`。
5. 拆分 `asset_valuation_service.dart`。
6. 补 `scripts/check.sh` 和拆分测试文件。
