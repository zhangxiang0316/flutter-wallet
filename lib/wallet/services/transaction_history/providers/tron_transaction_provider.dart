import 'package:dio/dio.dart';

import '../../models/chain_balance.dart';
import '../../models/wallet_transaction_record.dart';
import '../chain_transaction_provider.dart';

/// TRON 链交易记录提供者。
///
/// 负责查询 TRON 链的交易历史，包括：
/// - 原生 TRX 转账
/// - TRC20 代币转账
class TronTransactionProvider implements ChainTransactionProvider {
  TronTransactionProvider({Dio? dio})
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
    // TODO: 实现 TRON 链交易记录查询逻辑
    // 这里应该包含原来 _loadTronRecords 的逻辑

    // 暂时返回空列表，等待完整迁移
    return const [];
  }

  // TODO: 添加以下私有方法（从原文件迁移）
  // - _tronNativeRecord
  // - _tronTokenRecord
  // - TRON API 相关方法
}
