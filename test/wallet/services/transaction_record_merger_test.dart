import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/wallet_transaction_record.dart';
import 'package:omnicast/wallet/services/transaction/transaction_record_merger.dart';

void main() {
  const merger = TransactionRecordMerger();

  test('keeps multiple remote transfer events from the same transaction', () {
    final first = _record(
      id: 'remote:tx:4',
      source: WalletTransactionSource.remote,
      eventIndex: '4',
      amount: '1',
    );
    final second = _record(
      id: 'remote:tx:5',
      source: WalletTransactionSource.remote,
      eventIndex: '5',
      amount: '2',
    );

    final result = merger.merge(const [], [first, second]);

    expect(result, hasLength(2));
    expect(result.map((record) => record.eventIndex), containsAll(['4', '5']));
  });

  test('reconciles one local submission without collapsing remote events', () {
    final local = _record(
      id: 'local:tx',
      source: WalletTransactionSource.local,
      status: WalletTransactionStatus.pending,
    );
    final remote = [
      _record(
        id: 'remote:tx:4',
        source: WalletTransactionSource.remote,
        eventIndex: '4',
      ),
      _record(
        id: 'remote:tx:5',
        source: WalletTransactionSource.remote,
        eventIndex: '5',
      ),
    ];

    final result = merger.merge([local], remote);

    expect(result, hasLength(2));
    expect(
      result,
      everyElement(
        isA<WalletTransactionRecord>().having(
          (record) => record.source,
          'source',
          WalletTransactionSource.remote,
        ),
      ),
    );
  });

  test('does not let a stale response downgrade a terminal status', () {
    final confirmed = _record(
      id: 'local:tx',
      source: WalletTransactionSource.local,
      status: WalletTransactionStatus.success,
    );
    final stalePending = _record(
      id: 'local:tx',
      source: WalletTransactionSource.local,
      status: WalletTransactionStatus.pending,
    );

    final result = merger.merge([confirmed], [stalePending]);

    expect(result.single.status, WalletTransactionStatus.success);
  });
}

WalletTransactionRecord _record({
  required String id,
  required WalletTransactionSource source,
  String? eventIndex,
  String amount = '1',
  WalletTransactionStatus status = WalletTransactionStatus.success,
}) {
  return WalletTransactionRecord(
    id: id,
    walletId: 'wallet',
    chainId: 'bsc',
    chainName: 'BNB Smart Chain',
    symbol: 'USDT',
    assetName: 'Tether USD',
    walletAddress: '0x1111111111111111111111111111111111111111',
    txHash: '0xshared',
    fromAddress: '0x1111111111111111111111111111111111111111',
    toAddress: '0x2222222222222222222222222222222222222222',
    amount: amount,
    decimals: 18,
    direction: WalletTransactionDirection.outgoing,
    status: status,
    source: source,
    eventIndex: eventIndex,
    contractAddress: '0x55d398326f99059fF775485246999027B3197955',
    timestamp: DateTime.utc(2026, 8, 22),
  );
}
