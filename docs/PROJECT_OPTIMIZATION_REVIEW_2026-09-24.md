# 项目优化建议（2026-09-24）

## 审查概况

项目近期持续拆分钱包领域职责，并为转账、余额、资产、缓存和密钥存储补充了不少定向测试，整体基础良好。本文合并了现有优化建议与本次代码核对结果，重点关注刷新体验、缓存准确性、RPC 稳定性、转账安全和后续维护成本。

本次运行 `flutter analyze` 未发现分析错误，共报告 16 项提示：包括文件命名和弃用 API 提示，以及新增测试文件中的 2 项未使用可选参数警告。未运行测试。

## 建议清单

### P0：价格缓存按币种记录更新时间

- **位置**：`lib/wallet/services/asset_valuation_service.dart:87-100, 139-151`
- **状态**：已在当前工作区实施。
- **改动**：缓存现已按币种分别记录写入时间；每次只请求过期或缺失的币种，并只刷新本次成功返回的币种时间，避免新币种价格延长其它旧价格的有效期。
- **后续**：补充“部分币种成功、其它币种仍过期”的回归测试。

### P0：提交 EVM 交易前复核 pending nonce

- **位置**：`lib/wallet/services/transfer/evm_wallet_transfer.dart:93-98, 174-195`；`lib/page/transfer/controller/transfer_execution_service.dart:154-183`
- **现状**：确认页生成的交易草稿包含 pending nonce，并在解锁后直接复用。
- **影响**：用户确认期间若同一地址的另一笔交易先进入 pending，草稿 nonce 可能过期，导致本次交易被拒绝或发生 nonce 冲突。
- **建议**：签名前重新读取 pending nonce。若草稿已落后，停止签名并要求用户重新确认；不要在用户确认后静默更改 nonce 或费用参数。

### P1：行情源减少串行等待

- **位置**：`lib/wallet/services/asset_valuation/price_provider_dispatcher.dart:29-50`
- **状态**：已在当前工作区实施；调度器定向测试 5 项通过。
- **改动**：主行情源现在每批最多并发 2 个，按配置顺序合并并优先保留高优先级来源的价格；只有前一批仍有缺失币种时才启动下一批。fallback 逻辑保持并发。
- **验证范围**：覆盖批次缺失币种补齐、配置顺序优先级，以及结果齐全后跳过后续批次；真实网络延迟尚未做基准测量。

### P1：限制多链余额查询并发

- **位置**：`lib/wallet/services/chain_balance_service.dart:227-253`
- **状态**：已在当前工作区实施。
- **改动**：多链刷新使用 worker 队列，同时最多执行 4 条链；任一任务完成后立即启动队列中的下一条链，并保留逐链增量回调。
- **验证**：新增并发上限和 worker 补位测试；`chain_balance_service_test.dart` 11 项全部通过。

### P1：明确行情与余额的刷新边界

- **位置**：`lib/page/home/controller/home_controller_balance.dart:197-227`；`lib/wallet/services/asset_valuation_service.dart:77-100`
- **现状**：余额落地后继续等待价格加载；价格缓存有效期为 1 分钟，首页自动刷新也为 60 秒。
- **建议**：先展示链上余额及最近价格，再异步更新估值；将价格刷新与余额刷新解耦，并结合来源限流情况确定 TTL。总资产区域应能表达“部分资产暂未计价”，避免价格缺失造成总额突然下降而没有提示。

### P1：转账金额、草稿与手续费继续保持一致性校验

- **涉及位置**：`lib/page/transfer/controller/transfer_controller.dart`；`lib/page/transfer/controller/transfer_execution_service.dart`；`lib/wallet/services/transfer/evm_wallet_transfer.dart`
- **现状**：转账确认流程会复用已确认的 EVM 草稿，这避免了确认后费用参数被静默替换；提交阶段也会刷新余额并校验资产。
- **建议**：在保留该行为的前提下，把 nonce 复核、草稿有效期和重新确认路径纳入测试。资金相关改动应继续覆盖地址、链 ID、代币合约、金额、手续费和余额边界。

### P2：限制交易历史缓存规模

- **位置**：`lib/wallet/services/transaction/transaction_history_cache.dart:121-143, 198-227`
- **现状**：缓存写入会将整组记录转换成 JSON 字符串，没有明显的记录条数上限。
- **影响**：历史数据增长后，JSON 编解码和偏好存储读写会产生额外开销。
- **建议**：为展示缓存和本地待索引交易分别设置保留策略；若历史量长期较大，再迁移到适合分页查询的本地数据库。迁移前保留现有版本兼容和交易状态合并逻辑。

### P2：应用后台时暂停或放慢自动刷新

- **位置**：`lib/page/home/controller/home_controller.dart`、`lib/page/home/controller/home_controller_balance.dart:279-290`
- **状态**：已在当前工作区实施。
- **改动**：首页控制器在应用进入 inactive、hidden、paused 或 detached 状态时停止定时刷新；应用恢复后，仅当首页仍可见且已有钱包时重启定时器并立即刷新。
- **验证**：新增控制器生命周期测试；`home_controller_balance_test.dart` 7 项全部通过。

### P2：集中维护 RPC fallback 配置

- **涉及位置**：`lib/wallet/services/chain_balance_service.dart`、`lib/wallet/services/transfer/evm_wallet_transfer.dart`、`lib/wallet/services/transfer/bitcoin_wallet_transfer.dart`
- **现状**：部分链的余额查询和转账服务分别维护备用 RPC 列表。
- **建议**：将备用节点集中到链配置或统一注册表，避免余额和转账使用不同节点集合。自定义网络应继续使用用户配置，避免回退到不匹配的公共节点。

### P2：继续拆分转账执行器和编码工具

- **位置**：`lib/wallet/services/wallet_transfer_service.dart`、`lib/wallet/services/transfer/`
- **现状**：多条链的转账入口仍聚合在一个服务中，部分底层编码和签名逻辑也与转账流程耦合。
- **建议**：按链逐步提取执行器，并将 RLP、哈希、签名和地址编码等纯逻辑独立成模块。先增加或补齐纯逻辑测试，再逐链迁移，降低资金路径的大范围变更风险。

### P2：复用有状态服务和网络客户端

- **涉及位置**：`lib/page/home/controller/home_controller.dart`、`lib/page/transfer/controller/transfer_execution_service.dart` 及相关服务构造函数
- **现状**：一些服务在控制器或其它服务中直接创建，包含独立 Dio 客户端及内存缓存的服务可能无法跨页面复用。
- **建议**：先区分无状态服务和有状态服务；对价格缓存、余额缓存、交易历史等确有复用价值的对象使用统一依赖注入，并明确 Dio 生命周期和拦截器配置。

### P3：清理静态分析提示并完善日志分级

- **位置**：`lib/Initializer.dart`、`lib/page/transfer/view/widgets/transfer_selector_row.dart`、`lib/utils/log_util.dart`、`lib/widget/transaction_review_sheet.dart`，以及 `test/wallet/services/asset_valuation_dispatcher_test.dart`
- **现状**：分析器提示文件命名不符合 Dart 风格、多个弃用 API、可补充的 `const`，以及新增测试中的未使用可选参数。
- **建议**：按提示逐步修复并保持分析输出干净。弃用 API 的替换应结合项目当前 Flutter SDK 验证。另可为常规状态日志增加 debug/info 级别，避免正常流程占用 error 日志。

## 推荐实施顺序

| 顺序 | 工作项 | 主要收益 |
| --- | --- | --- |
| 1 | 按币种记录价格缓存时间 | 避免使用过期价格计算资产估值 |
| 2 | 提交前复核 EVM nonce | 降低确认期间发生交易冲突的风险 |
| 3 | 行情源小批次并发、余额请求限流 | 改善加载时间并减少 RPC 限流 |
| 4 | 前后台刷新策略与价格刷新解耦 | 减少后台请求并改善首页响应 |
| 5 | 缓存条数上限、RPC 配置集中化 | 控制长期运行成本并降低配置漂移 |
| 6 | 转账执行器拆分、依赖注入整理 | 提升测试性和长期维护效率 |
| 7 | 清理分析提示、日志分级 | 降低日常维护噪声 |

## 实施注意

- 每次优先完成一个资金安全或数据一致性改动，并为边界条件补充针对性测试。
- 行情源并发和 RPC 并发上限应通过请求耗时、错误率和限流反馈调整。
- 迁移缓存格式时保留旧数据读取和失败回退路径，避免升级后丢失本地待索引交易。
- 仓库当前已有未提交变更；实施前应先确认它们的归属和相互影响。
