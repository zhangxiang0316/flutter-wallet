import 'dart:convert';
import 'dart:typed_data';

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

  group('WalletTransactionStatusService Aptos', () {
    test('returns the on-chain Aptos execution status', () async {
      final dio = Dio()..httpClientAdapter = _AptosStatusAdapter();
      final service = WalletTransactionStatusService(dio: dio);

      final status = await service.loadStatus(
        chain: WalletChain.aptos,
        txHash: '0xaptostx',
      );

      expect(status, WalletTransactionStatus.success);
    });
  });
}

class _AptosStatusAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({'type': 'user_transaction', 'success': true}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
