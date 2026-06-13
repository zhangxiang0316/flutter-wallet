import 'package:dio/dio.dart';

import '../models/chain_balance.dart';
import '../models/wallet_transaction_record.dart';
import 'transaction_history/chain_transaction_provider.dart';
import 'transaction_history/providers/evm_transaction_provider.dart';
import 'transaction_history/providers/solana_transaction_provider.dart';
import 'transaction_history/providers/tron_transaction_provider.dart';

/// 钱包交易历史服务。
///
/// 使用 Provider 模式，根据不同链类型委托给相应的 Provider 处理。
/// 这个类作为统一入口，不包含具体的链逻辑。
class TransactionHistoryService {
  TransactionHistoryService({
    Dio? dio,
    EvmTransactionProvider? evmProvider,
    TronTransactionProvider? tronProvider,
    SolanaTransactionProvider? solanaProvider,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 6),
                receiveTimeout: const Duration(seconds: 6),
                sendTimeout: const Duration(seconds: 6),
              ),
            ),
        _evmProvider = evmProvider ?? EvmTransactionProvider(dio: dio),
        _tronProvider = tronProvider ?? TronTransactionProvider(dio: dio),
        _solanaProvider =
            solanaProvider ?? SolanaTransactionProvider(dio: dio);

  final Dio _dio;
  final EvmTransactionProvider _evmProvider;
  final TronTransactionProvider _tronProvider;
  final SolanaTransactionProvider _solanaProvider;

  /// 加载指定资产的交易记录。
  ///
  /// 根据资产所属的链类型，委托给相应的 Provider 处理。
  Future<List<WalletTransactionRecord>> loadAssetRecords({
    required String walletId,
    required ChainBalance asset,
  }) async {
    final chain = asset.chainRef;

    if (chain.isEvm) {
      return _evmProvider.loadRecords(walletId: walletId, asset: asset);
    }

    if (chain.id == 'tron') {
      return _tronProvider.loadRecords(walletId: walletId, asset: asset);
    }

    if (chain.id == 'solana') {
      return _solanaProvider.loadRecords(walletId: walletId, asset: asset);
    }

    // 未知链返回空列表
    return const [];
  }

  /// 清理资源
  void dispose() {
    // 如果需要的话，可以在这里清理 provider 资源
  }
}
