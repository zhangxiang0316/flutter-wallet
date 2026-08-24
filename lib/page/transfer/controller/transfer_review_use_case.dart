import '../../../wallet/models/chain_balance.dart';
import '../../../wallet/services/transaction/transaction_history_cache.dart';
import 'transfer_execution_service.dart';

class TransferReviewPreparation {
  const TransferReviewPreparation({
    required this.preflight,
    required this.recipientHistoryAddresses,
  });

  final TransferPreflightResult preflight;
  final List<String> recipientHistoryAddresses;
}

/// 确认页打开前的业务用例。
class TransferReviewUseCase {
  TransferReviewUseCase({
    TransferExecutionService? executionService,
    TransactionHistoryCache? transactionCache,
  }) : _executionService = executionService ?? TransferExecutionService(),
       _transactionCache = transactionCache ?? TransactionHistoryCache();

  final TransferExecutionService _executionService;
  final TransactionHistoryCache _transactionCache;

  Future<TransferReviewPreparation> prepare({
    required String walletId,
    required ChainBalance asset,
    required List<ChainBalance> availableAssets,
    required String recipientAddress,
    required String amount,
  }) async {
    final preflight = await _executionService.refreshPreflight(
      asset: asset,
      recipientAddress: recipientAddress,
      amount: amount,
    );
    final addresses = await _transactionCache.loadChainRecipientAddresses(
      walletId: walletId,
      chainId: preflight.asset.chainId,
      assets: availableAssets
          .where((item) => item.chainId == preflight.asset.chainId)
          .toList(growable: false),
    );
    return TransferReviewPreparation(
      preflight: preflight,
      recipientHistoryAddresses: addresses,
    );
  }
}
