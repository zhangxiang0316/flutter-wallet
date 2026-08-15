import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/models/wallet_transaction_record.dart';
import 'package:omnicast/wallet/services/transaction/wallet_transaction_status_service.dart';

import '../test_support/fallback_rpc_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WalletTransactionStatusService Bitcoin', () {
    test('returns success for a confirmed transaction', () async {
      final dio = Dio()..httpClientAdapter = FallbackRpcAdapter();
      final service = WalletTransactionStatusService(dio: dio);

      final status = await service.loadStatus(
        chain: WalletChain.bitcoin,
        txHash: List.filled(64, 'a').join(),
      );

      expect(status, WalletTransactionStatus.success);
    });

    test('returns pending for an unconfirmed transaction', () async {
      final dio = Dio()
        ..httpClientAdapter = FallbackRpcAdapter(bitcoinStatusConfirmed: false);
      final service = WalletTransactionStatusService(dio: dio);

      final status = await service.loadStatus(
        chain: WalletChain.bitcoin,
        txHash: List.filled(64, 'b').join(),
      );

      expect(status, WalletTransactionStatus.pending);
    });
  });
}
