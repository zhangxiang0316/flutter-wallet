import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/page/transfer/controller/transfer_scan_address_parser.dart';
import 'package:omnicast/wallet/models/payment_request.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';

void main() {
  group('payment request properties', () {
    test('round-trips randomized requests on every built-in chain', () {
      final random = Random(20260823);
      for (final chain in WalletChain.values) {
        final address = _addressFor(chain);
        for (var index = 0; index < 25; index++) {
          final amount = _positiveAmount(random);
          final memo = 'invoice ${random.nextInt(100000)} & ${chain.id}';
          final request = PaymentRequest(
            scheme: 'omnicast',
            chainId: chain.id,
            address: address,
            symbol: chain.symbol,
            amount: amount,
            memo: memo,
          );

          final parsed = TransferScanAddressParser.parse(
            request.toUri().toString(),
            WalletChain.ethereum.config,
          );

          expect(parsed, isNotNull, reason: chain.id);
          expect(parsed!.chainId, chain.id, reason: chain.id);
          expect(parsed.address, address, reason: chain.id);
          expect(parsed.symbol, chain.symbol, reason: chain.id);
          expect(parsed.amount, amount, reason: chain.id);
          expect(parsed.memo, memo, reason: chain.id);
        }
      }
    });

    test('accepts randomized exact EVM addresses without widening input', () {
      final random = Random(42);
      for (var index = 0; index < 250; index++) {
        final address = '0x${_randomHex(random, 40)}';

        final parsed = TransferScanAddressParser.parse(
          address,
          WalletChain.base.config,
        );

        expect(parsed?.address, address, reason: address);
        expect(parsed?.chainId, WalletChain.base.id, reason: address);
        expect(parsed?.isPlainAddress, isTrue, reason: address);
        expect(
          TransferScanAddressParser.parse(
            'prefix$address',
            WalletChain.base.config,
          ),
          isNull,
          reason: address,
        );
      }
    });

    test('rejects deterministic fuzz input and invalid amounts', () {
      final random = Random(7);
      const alphabet =
          'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789:/?&=%_-';
      for (var index = 0; index < 500; index++) {
        final length = random.nextInt(79) + 1;
        final input = List.generate(
          length,
          (_) => alphabet[random.nextInt(alphabet.length)],
        ).join();

        expect(
          TransferScanAddressParser.parse(input, WalletChain.ethereum.config),
          isNull,
          reason: input,
        );
      }

      const address = '0x2222222222222222222222222222222222222222';
      for (final amount in ['0', '-1', 'NaN', '1e3', '1.2.3']) {
        final uri = Uri(
          scheme: 'omnicast',
          host: 'receive',
          queryParameters: {
            'chain': WalletChain.ethereum.id,
            'address': address,
            'amount': amount,
          },
        );
        expect(
          TransferScanAddressParser.parse(
            uri.toString(),
            WalletChain.ethereum.config,
          ),
          isNull,
          reason: amount,
        );
      }
    });
  });
}

String _positiveAmount(Random random) {
  final whole = random.nextInt(100000) + 1;
  final fraction = random.nextInt(1000000).toString().padLeft(6, '0');
  return '$whole.$fraction';
}

String _randomHex(Random random, int length) {
  const hex = '0123456789abcdef';
  return List.generate(length, (_) => hex[random.nextInt(hex.length)]).join();
}

String _addressFor(WalletChain chain) {
  switch (chain.config.type) {
    case WalletChainType.evm:
      return '0x2222222222222222222222222222222222222222';
    case WalletChainType.tron:
      return 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC';
    case WalletChainType.solana:
      return 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8';
    case WalletChainType.bitcoin:
      return 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu';
    case WalletChainType.sui:
    case WalletChainType.aptos:
      return '0x936accb491f0facaac668baaedcf4d0cfc6da1120b66f77fa6a43af718669973';
  }
}
