import 'dart:async';

import '../../../wallet/models/chain_balance.dart';
import '../../../wallet/models/wallet_transaction_record.dart';
import '../../../wallet/services/transaction/transaction_history_cache.dart';
import '../../../wallet/services/transaction/wallet_transaction_status_service.dart';

/// 一次已提交交易的本地记录上下文。
class TransferSubmissionContext {
  const TransferSubmissionContext({
    required this.walletId,
    required this.asset,
    required this.txHash,
    required this.recipientAddress,
    required this.amount,
    required this.feeAmount,
    required this.feeSymbol,
  });

  final String walletId;
  final ChainBalance asset;
  final String txHash;
  final String recipientAddress;
  final String amount;
  final String? feeAmount;
  final String? feeSymbol;
}

/// 负责已提交交易的本地记录和链上状态轮询。
///
/// 该服务不依赖 Flutter 或 GetX。Controller 只需要接收状态变化并刷新页面，
/// 不再管理 Timer、轮询次数和本地记录拼装。
class TransferStatusTracker {
  TransferStatusTracker({
    TransactionHistoryCache? transactionCache,
    WalletTransactionStatusService? statusService,
  }) : _transactionCache = transactionCache ?? TransactionHistoryCache(),
       _statusService = statusService ?? WalletTransactionStatusService();

  final TransactionHistoryCache _transactionCache;
  final WalletTransactionStatusService _statusService;

  Timer? _timer;
  int _pollCount = 0;
  String? _trackedHash;

  Future<void> saveSubmittedTransaction(
    TransferSubmissionContext context, {
    WalletTransactionStatus status = WalletTransactionStatus.pending,
  }) {
    return _transactionCache.upsertLocalRecord(
      _toLocalRecord(context, status: status),
    );
  }

  Future<WalletTransactionStatus> refreshStatus(
    TransferSubmissionContext context,
  ) async {
    final status = await _statusService.loadStatus(
      chain: context.asset.chainRef,
      txHash: context.txHash,
    );
    await saveSubmittedTransaction(context, status: status);
    return status;
  }

  /// 开始轮询交易状态。状态变化通过 [onStatusChanged] 通知页面层。
  void start(
    TransferSubmissionContext context, {
    required FutureOr<void> Function(WalletTransactionStatus status)
    onStatusChanged,
  }) {
    stop();
    _trackedHash = context.txHash;
    _pollCount = 0;
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      _poll(context, onStatusChanged);
    });
    _poll(context, onStatusChanged);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _trackedHash = null;
  }

  void dispose() => stop();

  Future<void> _poll(
    TransferSubmissionContext context,
    FutureOr<void> Function(WalletTransactionStatus status) onStatusChanged,
  ) async {
    if (_trackedHash != context.txHash) return;
    _pollCount++;
    try {
      final status = await refreshStatus(context);
      if (_trackedHash != context.txHash) return;
      await onStatusChanged(status);
      if (status != WalletTransactionStatus.pending) stop();
    } catch (_) {
      if (_pollCount >= 8) stop();
    }
  }

  WalletTransactionRecord _toLocalRecord(
    TransferSubmissionContext context, {
    required WalletTransactionStatus status,
  }) {
    return WalletTransactionRecord(
      id: _localRecordId(context.walletId, context.asset, context.txHash),
      walletId: context.walletId,
      chainId: context.asset.chainId,
      chainName: context.asset.chainRef.name,
      symbol: context.asset.symbol,
      assetName: context.asset.name,
      walletAddress: context.asset.address,
      txHash: context.txHash,
      fromAddress: context.asset.address,
      toAddress: context.recipientAddress,
      amount: context.amount,
      decimals: context.asset.decimals,
      direction: WalletTransactionDirection.outgoing,
      status: status,
      source: WalletTransactionSource.local,
      contractAddress: context.asset.contractAddress,
      feeAmount: context.feeAmount,
      feeSymbol: context.feeSymbol,
      timestamp: DateTime.now(),
    );
  }

  String _localRecordId(String walletId, ChainBalance asset, String txHash) {
    return [
      'local',
      walletId,
      asset.chainId,
      asset.contractAddress ?? 'native',
      txHash.toLowerCase(),
    ].join(':');
  }
}
