import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/chain_balance.dart';
import 'package:omnicast/wallet/models/evm_transaction_draft.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/services/crypto/wallet_crypto_service.dart';
import 'package:omnicast/wallet/services/wallet_transfer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const privateKey =
      '0000000000000000000000000000000000000000000000000000000000000001';
  const otherPrivateKey =
      '0000000000000000000000000000000000000000000000000000000000000002';
  final sender = WalletCryptoService().evmAddressFromPrivateKey(privateKey);
  const recipient = '0x2222222222222222222222222222222222222222';

  ChainBalance nativeAsset() => ChainBalance(
    chain: WalletChain.ethereum,
    symbol: 'ETH',
    name: 'Ethereum',
    amount: '10',
    address: sender,
    decimals: 18,
  );

  ChainBalance tokenAsset() => ChainBalance(
    chain: WalletChain.ethereum,
    symbol: 'USDC',
    name: 'USD Coin',
    amount: '10',
    address: sender,
    contractAddress: '0x3333333333333333333333333333333333333333',
    decimals: 6,
  );

  group('EVM transaction draft consistency', () {
    test('legacy draft reuses pending nonce and buffered token gas', () async {
      final adapter = _EvmRpcAdapter(
        gasEstimate: BigInt.from(123456),
        nonce: BigInt.from(7),
      );
      final service = WalletTransferService(
        dio: Dio()..httpClientAdapter = adapter,
      );
      final asset = tokenAsset();

      final estimate = await service.estimateFee(
        asset: asset,
        toAddress: recipient,
        amount: '1',
      );
      final draft = estimate.evmDraft!;

      expect(draft.feeType, EvmFeeType.legacy);
      expect(draft.nonce, BigInt.from(7));
      expect(draft.gasLimit, BigInt.from(148148));
      expect(draft.gasPrice, BigInt.from(1000000000));
      expect(draft.usedFallbackGasLimit, isFalse);
      expect(adapter.transactionCountBlockTag, 'pending');

      final hash = await service.transfer(
        privateKeyHex: privateKey,
        asset: asset,
        toAddress: recipient,
        amount: '1',
        evmDraft: draft,
      );

      expect(hash, '0xsubmitted');
      expect(adapter.methodCount('eth_getTransactionCount'), 1);
      expect(adapter.methodCount('eth_estimateGas'), 1);
      expect(adapter.methodCount('eth_gasPrice'), 1);
      final fields = _decodeTransactionFields(adapter.rawTransaction!);
      expect(_asBigInt(fields[0]), draft.nonce);
      expect(_asBigInt(fields[1]), draft.gasPrice);
      expect(_asBigInt(fields[2]), draft.gasLimit);
    });

    test(
      'EIP-1559 draft signs a type-2 transaction with the same fees',
      () async {
        final adapter = _EvmRpcAdapter(
          supportsEip1559: true,
          baseFeePerGas: BigInt.from(10000000000),
          priorityFeePerGas: BigInt.from(2000000000),
          gasEstimate: BigInt.from(21000),
          nonce: BigInt.from(9),
        );
        final service = WalletTransferService(
          dio: Dio()..httpClientAdapter = adapter,
        );
        final asset = nativeAsset();

        final estimate = await service.estimateFee(
          asset: asset,
          toAddress: recipient,
          amount: '0.1',
        );
        final draft = estimate.evmDraft!;

        expect(draft.feeType, EvmFeeType.eip1559);
        expect(draft.maxPriorityFeePerGas, BigInt.from(2000000000));
        expect(draft.maxFeePerGas, BigInt.from(22000000000));
        expect(draft.gasLimit, BigInt.from(25200));
        expect(estimate.rawAmount, BigInt.from(554400000000000));

        await service.transfer(
          privateKeyHex: privateKey,
          asset: asset,
          toAddress: recipient,
          amount: '0.1',
          evmDraft: draft,
        );

        expect(adapter.rawTransaction, startsWith('0x02'));
        final fields = _decodeTransactionFields(adapter.rawTransaction!);
        expect(_asBigInt(fields[0]), BigInt.from(1));
        expect(_asBigInt(fields[1]), draft.nonce);
        expect(_asBigInt(fields[2]), draft.maxPriorityFeePerGas);
        expect(_asBigInt(fields[3]), draft.maxFeePerGas);
        expect(_asBigInt(fields[4]), draft.gasLimit);
        expect(adapter.simulatedCall?['maxFeePerGas'], '0x51f4d5c00');
        expect(adapter.simulationBlockTag, 'pending');
      },
    );

    test(
      'rejects a private key that does not match the draft sender',
      () async {
        final adapter = _EvmRpcAdapter();
        final service = WalletTransferService(
          dio: Dio()..httpClientAdapter = adapter,
        );
        final asset = nativeAsset();
        final estimate = await service.estimateFee(
          asset: asset,
          toAddress: recipient,
          amount: '0.1',
        );

        await expectLater(
          service.transfer(
            privateKeyHex: otherPrivateKey,
            asset: asset,
            toAddress: recipient,
            amount: '0.1',
            evmDraft: estimate.evmDraft,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('signer'),
            ),
          ),
        );
        expect(adapter.methodCount('eth_call'), 0);
        expect(adapter.methodCount('eth_sendRawTransaction'), 0);
      },
    );

    test(
      'rejects an estimated gas limit above the explicit safety cap',
      () async {
        final adapter = _EvmRpcAdapter(gasEstimate: BigInt.from(1500000));
        final service = WalletTransferService(
          dio: Dio()..httpClientAdapter = adapter,
        );

        await expectLater(
          service.estimateFee(
            asset: tokenAsset(),
            toAddress: recipient,
            amount: '1',
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('safety limit'),
            ),
          ),
        );
      },
    );
  });
}

class _EvmRpcAdapter implements HttpClientAdapter {
  _EvmRpcAdapter({
    this.supportsEip1559 = false,
    BigInt? baseFeePerGas,
    BigInt? priorityFeePerGas,
    BigInt? gasPrice,
    BigInt? gasEstimate,
    BigInt? nonce,
  }) : baseFeePerGas = baseFeePerGas ?? BigInt.from(10000000000),
       priorityFeePerGas = priorityFeePerGas ?? BigInt.from(2000000000),
       gasPrice = gasPrice ?? BigInt.from(1000000000),
       gasEstimate = gasEstimate ?? BigInt.from(21000),
       nonce = nonce ?? BigInt.zero;

  final bool supportsEip1559;
  final BigInt baseFeePerGas;
  final BigInt priorityFeePerGas;
  final BigInt gasPrice;
  final BigInt gasEstimate;
  final BigInt nonce;
  final List<String> methods = [];
  String? transactionCountBlockTag;
  String? rawTransaction;
  Map<dynamic, dynamic>? simulatedCall;
  String? simulationBlockTag;

  int methodCount(String method) =>
      methods.where((item) => item == method).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final request = options.data as Map;
    final method = request['method'] as String;
    final params = request['params'] as List;
    methods.add(method);
    final Object result;
    switch (method) {
      case 'eth_getBlockByNumber':
        result = supportsEip1559
            ? {'baseFeePerGas': _quantity(baseFeePerGas)}
            : <String, dynamic>{'number': '0x1'};
      case 'eth_maxPriorityFeePerGas':
        result = _quantity(priorityFeePerGas);
      case 'eth_gasPrice':
        result = _quantity(gasPrice);
      case 'eth_getTransactionCount':
        transactionCountBlockTag = params[1] as String;
        result = _quantity(nonce);
      case 'eth_estimateGas':
        result = _quantity(gasEstimate);
      case 'eth_call':
        simulatedCall = params.first as Map;
        simulationBlockTag = params[1] as String;
        result = '0x';
      case 'eth_sendRawTransaction':
        rawTransaction = params.first as String;
        result = '0xsubmitted';
      default:
        return _response({
          'jsonrpc': '2.0',
          'id': 1,
          'error': {'code': -32601, 'message': 'method not found'},
        });
    }
    return _response({'jsonrpc': '2.0', 'id': 1, 'result': result});
  }

  String _quantity(BigInt value) => '0x${value.toRadixString(16)}';

  ResponseBody _response(Object value) => ResponseBody.fromString(
    jsonEncode(value),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}

List<Object> _decodeTransactionFields(String rawTransaction) {
  final bytes = Uint8List.fromList(
    List<int>.generate(
      (rawTransaction.length - 2) ~/ 2,
      (index) => int.parse(
        rawTransaction.substring(2 + index * 2, 4 + index * 2),
        radix: 16,
      ),
    ),
  );
  final start = bytes.first == 0x02 ? 1 : 0;
  final decoded = _decodeRlp(bytes, start).value;
  return decoded as List<Object>;
}

({Object value, int nextOffset}) _decodeRlp(Uint8List bytes, int offset) {
  final prefix = bytes[offset];
  if (prefix <= 0x7f) {
    return (value: Uint8List.fromList([prefix]), nextOffset: offset + 1);
  }
  if (prefix <= 0xb7) {
    final length = prefix - 0x80;
    final start = offset + 1;
    return (
      value: Uint8List.sublistView(bytes, start, start + length),
      nextOffset: start + length,
    );
  }
  if (prefix <= 0xbf) {
    final lengthOfLength = prefix - 0xb7;
    final payloadLength = _readLength(bytes, offset + 1, lengthOfLength);
    final start = offset + 1 + lengthOfLength;
    return (
      value: Uint8List.sublistView(bytes, start, start + payloadLength),
      nextOffset: start + payloadLength,
    );
  }
  final lengthOfLength = prefix <= 0xf7 ? 0 : prefix - 0xf7;
  final payloadLength = lengthOfLength == 0
      ? prefix - 0xc0
      : _readLength(bytes, offset + 1, lengthOfLength);
  var cursor = offset + 1 + lengthOfLength;
  final end = cursor + payloadLength;
  final values = <Object>[];
  while (cursor < end) {
    final decoded = _decodeRlp(bytes, cursor);
    values.add(decoded.value);
    cursor = decoded.nextOffset;
  }
  return (value: values, nextOffset: end);
}

int _readLength(Uint8List bytes, int offset, int length) {
  var value = 0;
  for (var index = 0; index < length; index++) {
    value = value * 256 + bytes[offset + index];
  }
  return value;
}

BigInt _asBigInt(Object value) {
  final bytes = value as Uint8List;
  var result = BigInt.zero;
  for (final byte in bytes) {
    result = (result << 8) | BigInt.from(byte);
  }
  return result;
}
