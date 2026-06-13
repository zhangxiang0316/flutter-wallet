# 交易历史服务重构指南

## 概述

本文档说明如何将 `wallet_transaction_history_service.dart`（1581行）拆分为模块化的 Provider 架构。

---

## 当前问题

- **文件过大**: 1581 行，包含 EVM/TRON/Solana 三条链的逻辑
- **难以维护**: 所有链的代码混在一起
- **难以测试**: 无法独立测试各链逻辑
- **难以扩展**: 添加新链需要修改核心文件

---

## 新架构设计

### 目录结构

```
lib/wallet/services/
├── transaction_history/                    # 新目录
│   ├── chain_transaction_provider.dart    # 抽象接口 (20 行)
│   ├── transaction_history_service_new.dart # 新主服务 (80 行)
│   ├── providers/                         # Provider 实现
│   │   ├── evm_transaction_provider.dart  # EVM 链 (~500 行)
│   │   ├── tron_transaction_provider.dart # TRON 链 (~200 行)
│   │   └── solana_transaction_provider.dart # Solana 链 (~300 行)
│   └── utils/                             # 工具类
│       ├── rpc_helper.dart                # RPC 请求封装
│       └── transaction_formatter.dart     # 格式化工具
└── wallet_transaction_history_service.dart # 旧文件（待替换）
```

### 架构图

```
TransactionHistoryService (主服务，统一入口)
         │
         ├──> ChainTransactionProvider (抽象接口)
         │         │
         │         ├──> EvmTransactionProvider (EVM 实现)
         │         ├──> TronTransactionProvider (TRON 实现)
         │         └──> SolanaTransactionProvider (Solana 实现)
         │
         └──> 根据链类型路由到对应 Provider
```

---

## 已完成工作

✅ **阶段 1: 架构准备**

1. 创建目录结构
   ```bash
   lib/wallet/services/transaction_history/
   ├── providers/
   └── utils/
   ```

2. 创建抽象接口
   ```dart
   // chain_transaction_provider.dart
   abstract class ChainTransactionProvider {
     Future<List<WalletTransactionRecord>> loadRecords({
       required String walletId,
       required ChainBalance asset,
     });
   }
   ```

3. 创建新主服务框架
   ```dart
   // transaction_history_service_new.dart
   class TransactionHistoryService {
     final EvmTransactionProvider _evmProvider;
     final TronTransactionProvider _tronProvider;
     final SolanaTransactionProvider _solanaProvider;
     
     Future<List<WalletTransactionRecord>> loadAssetRecords(...) {
       if (chain.isEvm) return _evmProvider.loadRecords(...);
       if (chain.id == 'tron') return _tronProvider.loadRecords(...);
       if (chain.id == 'solana') return _solanaProvider.loadRecords(...);
     }
   }
   ```

4. 创建 Provider 占位符
   - `evm_transaction_provider.dart` - EVM 链实现（框架）
   - `tron_transaction_provider.dart` - TRON 链实现（框架）
   - `solana_transaction_provider.dart` - Solana 链实现（框架）

---

## 待完成工作

### 阶段 2: 迁移 EVM Provider

**目标**: 将 EVM 相关代码（lines 133-645, ~513 行）移动到 `evm_transaction_provider.dart`

**需要移动的方法**:
```dart
// 从 wallet_transaction_history_service.dart 移动到 evm_transaction_provider.dart

1. _loadEvmRecords() - 主入口
2. _loadEvmExplorerRecords() - Etherscan API
3. _loadBlockscoutRecords() - Blockscout API
4. _loadEvmTokenLogs() - RPC logs 查询
5. _evmTokenRecordFromLog() - 日志解析
6. _evmRpc() - RPC 请求封装
7. _evmRpcBigInt() - BigInt RPC
8. _evmRpcMap() - Map RPC
9. _evmGetLogs() - 获取日志
10. _evmNativeRecord() - 原生币记录
11. _evmTokenRecord() - Token 记录

相关常量:
- _evmExplorerApiUrls
- _evmBlockscoutBaseUrls
- _evmRpcFallbacks
- _evmTransferEventTopic
```

**步骤**:
1. 复制相关方法到新文件
2. 调整方法可见性（private → public/protected）
3. 更新导入
4. 测试 EVM 链交易记录加载

---

### 阶段 3: 迁移 TRON Provider

**目标**: 将 TRON 相关代码（lines 646-805, ~160 行）移动到 `tron_transaction_provider.dart`

**需要移动的方法**:
```dart
// 从 wallet_transaction_history_service.dart 移动到 tron_transaction_provider.dart

1. _loadTronRecords() - 主入口
2. _tronNativeRecord() - TRX 记录
3. _tronTokenRecord() - TRC20 记录
4. _tronApiUrls() - API URLs

相关常量:
- _tronApiFallbacks
```

---

### 阶段 4: 迁移 Solana Provider

**目标**: 将 Solana 相关代码（lines 806-1089, ~284 行）移动到 `solana_transaction_provider.dart`

**需要移动的方法**:
```dart
// 从 wallet_transaction_history_service.dart 移动到 solana_transaction_provider.dart

1. _loadSolanaRecords() - 主入口
2. _loadSolanaNativeRecords() - SOL 记录
3. _loadSolanaTokenRecords() - SPL Token 记录
4. _solanaSignaturesForAddress() - 获取签名
5. _solanaParsedTransaction() - 解析交易
6. _solanaTokenAccountsForMint() - Token 账户
7. _solanaNativeRecordsFromTransaction() - Native 记录解析
8. _solanaTokenRecordsFromTransaction() - Token 记录解析
9. _solanaRpc() - RPC 请求
10. _solanaInstructions() - 指令解析
11. _solanaRpcUrls() - RPC URLs

相关常量:
- _solanaRpcFallbacks
```

---

### 阶段 5: 提取工具类

**目标**: 提取通用工具方法

**创建 `rpc_helper.dart`**:
```dart
class RpcHelper {
  static Future<T> withRetry<T>(Future<T> Function() fn) { ... }
  static Future<dynamic> evmRpc(...) { ... }
  static Future<dynamic> solanaRpc(...) { ... }
}
```

**创建 `transaction_formatter.dart`**:
```dart
class TransactionFormatter {
  static DateTime fromSeconds(String seconds) { ... }
  static DateTime fromMilliseconds(int ms) { ... }
  static int compareRecordTimeDesc(...) { ... }
}
```

---

### 阶段 6: 更新引用

**目标**: 将所有使用旧服务的地方改为使用新服务

**需要更新的文件**:
```
lib/page/transaction/controller/transaction_history_controller.dart
lib/page/home/controller/home_controller.dart
其他引用 WalletTransactionHistoryService 的地方
```

**更新方法**:
```dart
// 旧代码
import '../wallet/services/wallet_transaction_history_service.dart';
final service = WalletTransactionHistoryService();

// 新代码
import '../wallet/services/transaction_history/transaction_history_service_new.dart';
final service = TransactionHistoryService();
```

---

### 阶段 7: 测试验证

**测试清单**:
- [ ] BSC 链交易记录加载
- [ ] Ethereum 链交易记录加载
- [ ] Arbitrum 链交易记录加载
- [ ] X Layer 链交易记录加载
- [ ] TRON 链交易记录加载
- [ ] Solana 链交易记录加载
- [ ] 原生币交易记录
- [ ] Token 交易记录
- [ ] 空记录处理
- [ ] 错误处理

---

### 阶段 8: 清理

**目标**: 删除旧文件，完成迁移

1. 确认所有引用已更新
2. 删除 `wallet_transaction_history_service.dart`
3. 重命名 `transaction_history_service_new.dart` → `transaction_history_service.dart`
4. 更新导入路径
5. 运行完整测试

---

## 迁移代码示例

### EVM Provider 完整示例

```dart
// lib/wallet/services/transaction_history/providers/evm_transaction_provider.dart

import 'package:dio/dio.dart';
import 'package:convert/convert.dart';

import '../../../models/chain_balance.dart';
import '../../../models/wallet_transaction_record.dart';
import '../../../constants/crypto_constants.dart';
import '../chain_transaction_provider.dart';

class EvmTransactionProvider implements ChainTransactionProvider {
  EvmTransactionProvider({Dio? dio}) : _dio = dio ?? Dio();
  
  final Dio _dio;
  
  static const String _transferEventTopic = 
    CryptoConstants.evmTransferEventTopic;
  
  static const Map<String, String> _explorerApiUrls = {
    'bsc': 'https://api.bscscan.com/api',
    'ethereum': 'https://api.etherscan.io/api',
  };
  
  @override
  Future<List<WalletTransactionRecord>> loadRecords({
    required String walletId,
    required ChainBalance asset,
  }) async {
    // 原来的 _loadEvmRecords 逻辑
    // ...
  }
  
  Future<List<WalletTransactionRecord>> _loadExplorerRecords(...) {
    // 原来的 _loadEvmExplorerRecords 逻辑
    // ...
  }
  
  // ... 其他方法
}
```

---

## 优势

### 重构后的优势

1. **模块化** ✅
   - 每个 Provider < 500 行
   - 职责清晰，易于理解

2. **可测试性** ✅
   - 可以独立测试各链逻辑
   - 易于 mock 和单元测试

3. **可扩展性** ✅
   - 添加新链只需实现接口
   - 不影响现有代码

4. **可维护性** ✅
   - 修改一条链不影响其他链
   - 代码组织清晰

5. **依赖注入** ✅
   - 支持 DI，便于测试
   - 可以替换实现

---

## 风险评估

### 低风险 ✅

- **仅重构结构，不改逻辑**
- **保持向后兼容**
- **可以渐进式迁移**
- **每步都可测试**

### 缓解措施

1. **保留旧文件** - 直到完全迁移完成
2. **逐步测试** - 每迁移一个 Provider 就测试
3. **回滚计划** - 出问题可以快速回滚
4. **完整测试** - 最后进行完整回归测试

---

## 时间估算

| 阶段 | 工作量 | 说明 |
|------|-------|------|
| 阶段 1: 架构准备 | ✅ 完成 | 已完成 |
| 阶段 2: 迁移 EVM | 2-3 小时 | 最大模块 |
| 阶段 3: 迁移 TRON | 1 小时 | 相对简单 |
| 阶段 4: 迁移 Solana | 1.5 小时 | 中等复杂 |
| 阶段 5: 提取工具类 | 0.5 小时 | 简单 |
| 阶段 6: 更新引用 | 0.5 小时 | 查找替换 |
| 阶段 7: 测试验证 | 1 小时 | 全面测试 |
| 阶段 8: 清理 | 0.5 小时 | 删除旧代码 |
| **总计** | **7-8 小时** | 一个工作日 |

---

## 下一步行动

### 立即可做

1. ✅ 提交当前的架构准备工作
2. ✅ 创建 GitHub Issue 跟踪完整迁移
3. ⏳ 安排专门时间完成迁移（建议连续进行）

### 推荐执行方式

**选项 1: 一次性完成（推荐）**
- 分配 1 个完整工作日
- 连续完成所有阶段
- 减少上下文切换

**选项 2: 分批完成**
- 第一批: 迁移 EVM Provider + 测试
- 第二批: 迁移 TRON/Solana + 测试  
- 第三批: 工具类 + 清理

---

## 参考资料

- 原文件: `lib/wallet/services/wallet_transaction_history_service.dart`
- 新架构: `lib/wallet/services/transaction_history/`
- 优化建议: `docs/OPTIMIZATION_RECOMMENDATIONS.md`

---

**文档创建时间**: 2026-06-13  
**状态**: 架构准备完成，待执行完整迁移
