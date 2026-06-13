import 'package:dio/dio.dart';

import '../../../models/chain_balance.dart';
import '../../../models/wallet_transaction_record.dart';
import '../chain_transaction_provider.dart';

/// EVM 链交易记录提供者。
///
/// 负责查询 EVM 兼容链（BSC、Ethereum、Arbitrum、X Layer）的交易历史。
/// 支持多种数据源：
/// 1. Etherscan 兼容的区块浏览器 API
/// 2. Blockscout API
/// 3. RPC logs 查询（兜底方案）
class EvmTransactionProvider implements ChainTransactionProvider {
  EvmTransactionProvider({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 6),
                receiveTimeout: const Duration(seconds: 6),
              ),
            );

  final Dio _dio;

  @override
  Future<List<WalletTransactionRecord>> loadRecords({
    required String walletId,
    required ChainBalance asset,
  }) async {
    // TODO: 实现 EVM 链交易记录查询逻辑
    // 这里应该包含原来 _loadEvmRecords 的逻辑

    // 暂时返回空列表，等待完整迁移
    return const [];
  }

  // TODO: 添加以下私有方法（从原文件迁移）
  // - _loadEvmExplorerRecords
  // - _loadBlockscoutRecords
  // - _loadEvmTokenLogs
  // - _evmTokenRecordFromLog
  // - _evmRpc 相关方法
}
