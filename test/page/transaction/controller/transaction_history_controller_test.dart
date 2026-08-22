import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/page/transaction/controller/transaction_history_controller.dart';
import 'package:omnicast/wallet/models/chain_balance.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/models/wallet_transaction_record.dart';
import 'package:omnicast/wallet/services/transaction/transaction_history_cache.dart';
import 'package:omnicast/wallet/services/transaction/wallet_transaction_status_service.dart';
import 'package:omnicast/wallet/services/wallet_transaction_history_service.dart';

void main() {
  test(
    'shows cache before pending refresh and limits status concurrency',
    () async {
      final local = List.generate(
        5,
        (index) => _record(
          id: 'local-$index',
          hash: '0xlocal$index',
          source: WalletTransactionSource.local,
          status: WalletTransactionStatus.pending,
        ),
      );
      final cached = _record(
        id: 'remote-cache',
        hash: '0xcached',
        source: WalletTransactionSource.remote,
        status: WalletTransactionStatus.success,
        eventIndex: '1',
      );
      final cache = _FakeHistoryCache(local: local, remote: [cached]);
      final statusService = _ControlledStatusService();
      final historyService = _ControlledHistoryService();
      final controller =
          TransactionHistoryController(
              cache: cache,
              transactionStatusService: statusService,
              historyService: historyService,
            )
            ..arguments = const TransactionHistoryPageArguments(
              walletId: 'wallet',
              asset: _asset,
            );

      final load = controller.loadRecords();
      await _flushEvents();

      expect(controller.records, hasLength(6));
      expect(
        controller.records.any((record) => record.id == cached.id),
        isTrue,
      );
      expect(statusService.callCount, 3);
      expect(statusService.maxActive, 3);
      expect(historyService.requested, isTrue);

      statusService.completeFirst(3, WalletTransactionStatus.success);
      await _flushEvents();

      expect(statusService.callCount, 5);
      expect(statusService.maxActive, 3);

      statusService.completeRemaining(WalletTransactionStatus.success);
      historyService.complete();
      await load;
      await _flushEvents();

      expect(cache.savedLocal, hasLength(5));
      expect(
        cache.savedLocal,
        everyElement(
          isA<WalletTransactionRecord>().having(
            (record) => record.status,
            'status',
            WalletTransactionStatus.success,
          ),
        ),
      );
    },
  );
}

const _asset = ChainBalance(
  chain: WalletChain.bsc,
  symbol: 'USDT',
  name: 'Tether USD',
  amount: '10',
  address: '0x1111111111111111111111111111111111111111',
  contractAddress: '0x55d398326f99059fF775485246999027B3197955',
  decimals: 18,
);

Future<void> _flushEvents() async {
  for (var index = 0; index < 5; index++) {
    await Future<void>.delayed(Duration.zero);
  }
}

WalletTransactionRecord _record({
  required String id,
  required String hash,
  required WalletTransactionSource source,
  required WalletTransactionStatus status,
  String? eventIndex,
}) {
  return WalletTransactionRecord(
    id: id,
    walletId: 'wallet',
    chainId: 'bsc',
    chainName: 'BNB Smart Chain',
    symbol: 'USDT',
    assetName: 'Tether USD',
    walletAddress: _asset.address,
    txHash: hash,
    fromAddress: _asset.address,
    toAddress: '0x2222222222222222222222222222222222222222',
    amount: '1',
    decimals: 18,
    direction: WalletTransactionDirection.outgoing,
    status: status,
    source: source,
    eventIndex: eventIndex,
    contractAddress: _asset.contractAddress,
    timestamp: DateTime.utc(2026, 8, 22),
  );
}

class _FakeHistoryCache extends TransactionHistoryCache {
  _FakeHistoryCache({required this.local, required this.remote});

  final List<WalletTransactionRecord> local;
  final List<WalletTransactionRecord> remote;
  List<WalletTransactionRecord> savedLocal = const [];

  @override
  Future<List<WalletTransactionRecord>?> load(
    String walletId,
    String chainId,
    String symbol, {
    String? contractAddress,
  }) async => remote;

  @override
  Future<List<WalletTransactionRecord>> loadLocalRecords(
    String walletId,
    String chainId,
    String symbol, {
    String? contractAddress,
  }) async => local;

  @override
  Future<void> save(
    String walletId,
    String chainId,
    String symbol,
    List<WalletTransactionRecord> records, {
    String? contractAddress,
  }) async {}

  @override
  Future<void> saveLocalRecords(
    String walletId,
    String chainId,
    String symbol,
    List<WalletTransactionRecord> records, {
    String? contractAddress,
  }) async {
    savedLocal = records;
  }
}

class _ControlledHistoryService extends WalletTransactionHistoryService {
  final Completer<TransactionHistoryPageResult> _completer = Completer();
  bool requested = false;

  @override
  Future<TransactionHistoryPageResult> loadAssetRecordPage({
    required String walletId,
    required ChainBalance asset,
    TransactionHistoryCursor? cursor,
  }) {
    requested = true;
    return _completer.future;
  }

  void complete() {
    _completer.complete(
      const TransactionHistoryPageResult(records: [], nextCursor: null),
    );
  }
}

class _ControlledStatusService extends WalletTransactionStatusService {
  final List<Completer<WalletTransactionStatus>> _requests = [];
  int active = 0;
  int maxActive = 0;

  int get callCount => _requests.length;

  @override
  Future<WalletTransactionStatus> loadStatus({
    required WalletChainRef chain,
    required String txHash,
  }) {
    final completer = Completer<WalletTransactionStatus>();
    _requests.add(completer);
    active += 1;
    if (active > maxActive) maxActive = active;
    return completer.future.whenComplete(() => active -= 1);
  }

  void completeFirst(int count, WalletTransactionStatus status) {
    for (final request in _requests.take(count)) {
      if (!request.isCompleted) request.complete(status);
    }
  }

  void completeRemaining(WalletTransactionStatus status) {
    for (final request in _requests) {
      if (!request.isCompleted) request.complete(status);
    }
  }
}
