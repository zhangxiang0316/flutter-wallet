import 'package:dio/dio.dart';

import '../../models/chain_balance.dart';
import '../../models/wallet_transaction_record.dart';
import '../chain_transaction_provider.dart';

/// Solana 链交易记录提供者。
///
/// 负责查询 Solana 链的交易历史，包括：
/// - 原生 SOL 转账
/// - SPL Token 转账
class SolanaTransactionProvider implements ChainTransactionProvider {
  SolanaTransactionProvider({Dio? dio})
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
    // TODO: 实现 Solana 链交易记录查询逻辑
    // 这里应该包含原来 _loadSolanaRecords 的逻辑

    // 暂时返回空列表，等待完整迁移
    return const [];
  }

  // TODO: 添加以下私有方法（从原文件迁移）
  // - _loadSolanaNativeRecords
  // - _loadSolanaTokenRecords
  // - _solanaSignaturesForAddress
  // - _solanaParsedTransaction
  // - _solanaTokenAccountsForMint
  // - Solana RPC 相关方法
}
