import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/chain_balance.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/services/crypto/wallet_crypto_service.dart';
import 'package:omnicast/wallet/services/wallet_transfer_service.dart';
import 'package:pointycastle/digests/sha256.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const privateKey =
      '0000000000000000000000000000000000000000000000000000000000000001';
  const otherPrivateKey =
      '0000000000000000000000000000000000000000000000000000000000000002';
  final cryptoService = WalletCryptoService();
  final sender = cryptoService.importPrivateKey(privateKey).tronAddress;
  final recipient = cryptoService.importPrivateKey(otherPrivateKey).tronAddress;
  final tokenContract = cryptoService
      .importPrivateKey(
        '0000000000000000000000000000000000000000000000000000000000000003',
      )
      .tronAddress;
  final attacker = cryptoService
      .importPrivateKey(
        '0000000000000000000000000000000000000000000000000000000000000004',
      )
      .tronAddress;
  final adapters = <_TronTransferAdapter>[];

  ChainBalance nativeAsset() => ChainBalance(
    chain: WalletChain.tron,
    symbol: 'TRX',
    name: 'TRON',
    amount: '10',
    address: sender,
    decimals: 6,
  );

  ChainBalance tokenAsset() => ChainBalance(
    chain: WalletChain.tron,
    symbol: 'USDT',
    name: 'Tether USD',
    amount: '10',
    address: sender,
    contractAddress: tokenContract,
    decimals: 6,
  );

  Future<String> transfer({
    required ChainBalance asset,
    _TronMutation mutation = _TronMutation.none,
    String signingKey = privateKey,
  }) async {
    final adapter = _TronTransferAdapter(
      mutation: mutation,
      attackerAddress: attacker,
    );
    adapters.add(adapter);
    final dio = Dio()..httpClientAdapter = adapter;
    final service = WalletTransferService(dio: dio);
    final hash = await service.transfer(
      privateKeyHex: signingKey,
      asset: asset,
      toAddress: recipient,
      amount: '1',
    );
    expect(adapter.broadcastCount, 1);
    return hash;
  }

  group('TRON transaction signing validation', () {
    test(
      'signs a native transfer only after validating raw_data_hex',
      () async {
        expect(await transfer(asset: nativeAsset()), hasLength(64));
      },
    );

    test('signs a TRC20 transfer only after validating raw_data_hex', () async {
      expect(await transfer(asset: tokenAsset()), hasLength(64));
    });

    test('rejects a private key that does not match the sender', () async {
      await expectLater(
        transfer(asset: nativeAsset(), signingKey: otherPrivateKey),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('signer'),
          ),
        ),
      );
      expect(adapters.last.broadcastCount, 0);
    });

    for (final testCase
        in <({String name, _TronMutation mutation, bool token})>[
          (
            name: 'rejects a node-modified sender',
            mutation: _TronMutation.owner,
            token: false,
          ),
          (
            name: 'rejects a node-modified recipient',
            mutation: _TronMutation.recipient,
            token: false,
          ),
          (
            name: 'rejects a node-modified native amount',
            mutation: _TronMutation.amount,
            token: false,
          ),
          (
            name: 'rejects a node-modified contract type',
            mutation: _TronMutation.contractType,
            token: false,
          ),
          (
            name: 'rejects a transaction containing multiple contracts',
            mutation: _TronMutation.extraContract,
            token: false,
          ),
          (
            name: 'rejects a node-modified token contract',
            mutation: _TronMutation.tokenContract,
            token: true,
          ),
          (
            name: 'rejects modified TRC20 method parameters',
            mutation: _TronMutation.tokenData,
            token: true,
          ),
          (
            name: 'rejects a TRC20 transaction carrying native value',
            mutation: _TronMutation.callValue,
            token: true,
          ),
          (
            name: 'rejects a node-modified fee limit',
            mutation: _TronMutation.feeLimit,
            token: true,
          ),
          (
            name: 'rejects an expired transaction',
            mutation: _TronMutation.expired,
            token: false,
          ),
          (
            name: 'rejects a mismatched transaction ID',
            mutation: _TronMutation.transactionId,
            token: false,
          ),
          (
            name: 'rejects JSON intent that differs from signed bytes',
            mutation: _TronMutation.jsonAmount,
            token: false,
          ),
        ]) {
      test(testCase.name, () async {
        await expectLater(
          transfer(
            asset: testCase.token ? tokenAsset() : nativeAsset(),
            mutation: testCase.mutation,
          ),
          throwsA(isA<StateError>()),
        );
        expect(adapters.last.broadcastCount, 0);
      });
    }
  });
}

enum _TronMutation {
  none,
  owner,
  recipient,
  amount,
  contractType,
  extraContract,
  tokenContract,
  tokenData,
  callValue,
  feeLimit,
  expired,
  transactionId,
  jsonAmount,
}

class _TronTransferAdapter implements HttpClientAdapter {
  _TronTransferAdapter({required this.mutation, required this.attackerAddress});

  final _TronMutation mutation;
  final String attackerAddress;
  int broadcastCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    final request = Map<String, dynamic>.from(options.data as Map);
    if (path.endsWith('/wallet/createtransaction')) {
      return _jsonResponse(_nativeTransaction(request));
    }
    if (path.endsWith('/wallet/triggersmartcontract')) {
      return _jsonResponse({'transaction': _tokenTransaction(request)});
    }
    if (path.endsWith('/wallet/broadcasttransaction')) {
      broadcastCount++;
      final transaction = Map<String, dynamic>.from(options.data as Map);
      return _jsonResponse({'result': true, 'txid': transaction['txID']});
    }
    return _jsonResponse({'message': 'not found'}, statusCode: 404);
  }

  Map<String, dynamic> _nativeTransaction(Map<String, dynamic> request) {
    final originalOwner = request['owner_address']!.toString();
    final originalRecipient = request['to_address']!.toString();
    final originalAmount = BigInt.parse(request['amount']!.toString());
    final owner = mutation == _TronMutation.owner
        ? attackerAddress
        : originalOwner;
    final recipient = mutation == _TronMutation.recipient
        ? attackerAddress
        : originalRecipient;
    final amount = mutation == _TronMutation.amount
        ? originalAmount + BigInt.one
        : originalAmount;
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiration = mutation == _TronMutation.expired
        ? now - 1000
        : now + 60000;
    final payload = _message([
      _bytesField(1, _addressBytes(owner)),
      _bytesField(2, _addressBytes(recipient)),
      _varintField(3, amount),
    ]);
    final contract = _contract(
      type: mutation == _TronMutation.contractType ? 31 : 1,
      typeUrl: mutation == _TronMutation.contractType
          ? 'type.googleapis.com/protocol.TriggerSmartContract'
          : 'type.googleapis.com/protocol.TransferContract',
      payload: payload,
    );
    final rawData = _rawData(
      timestamp: now,
      expiration: expiration,
      contracts: [
        contract,
        if (mutation == _TronMutation.extraContract) contract,
      ],
    );
    final transaction = _transactionEnvelope(
      rawData: rawData,
      rawDataJson: {
        'contract': [
          {
            'parameter': {
              'value': {
                'owner_address': originalOwner,
                'to_address': originalRecipient,
                'amount': mutation == _TronMutation.jsonAmount
                    ? originalAmount.toInt() + 1
                    : originalAmount.toInt(),
              },
              'type_url': 'type.googleapis.com/protocol.TransferContract',
            },
            'type': 'TransferContract',
          },
        ],
        'timestamp': now,
        'expiration': expiration,
      },
    );
    if (mutation == _TronMutation.transactionId) {
      transaction['txID'] = List.filled(64, '0').join();
    }
    return transaction;
  }

  Map<String, dynamic> _tokenTransaction(Map<String, dynamic> request) {
    final originalOwner = request['owner_address']!.toString();
    final originalContract = request['contract_address']!.toString();
    final owner = mutation == _TronMutation.owner
        ? attackerAddress
        : originalOwner;
    final contractAddress = mutation == _TronMutation.tokenContract
        ? attackerAddress
        : originalContract;
    final originalData = Uint8List.fromList([
      ...hex.decode('a9059cbb'),
      ...hex.decode(request['parameter']!.toString()),
    ]);
    final callData = Uint8List.fromList(originalData);
    if (mutation == _TronMutation.tokenData) {
      callData[callData.length - 1] ^= 1;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiration = mutation == _TronMutation.expired
        ? now - 1000
        : now + 60000;
    final feeLimit = mutation == _TronMutation.feeLimit
        ? BigInt.from(30000001)
        : BigInt.from(30000000);
    final payload = _message([
      _bytesField(1, _addressBytes(owner)),
      _bytesField(2, _addressBytes(contractAddress)),
      if (mutation == _TronMutation.callValue) _varintField(3, BigInt.one),
      _bytesField(4, callData),
    ]);
    final contract = _contract(
      type: 31,
      typeUrl: 'type.googleapis.com/protocol.TriggerSmartContract',
      payload: payload,
    );
    final rawData = _rawData(
      timestamp: now,
      expiration: expiration,
      contracts: [contract],
      feeLimit: feeLimit,
    );
    return _transactionEnvelope(
      rawData: rawData,
      rawDataJson: {
        'contract': [
          {
            'parameter': {
              'value': {
                'owner_address': originalOwner,
                'contract_address': originalContract,
                'call_value': 0,
                'data': hex.encode(originalData),
              },
              'type_url': 'type.googleapis.com/protocol.TriggerSmartContract',
            },
            'type': 'TriggerSmartContract',
          },
        ],
        'timestamp': now,
        'expiration': expiration,
        'fee_limit': 30000000,
      },
    );
  }

  Map<String, dynamic> _transactionEnvelope({
    required Uint8List rawData,
    required Map<String, dynamic> rawDataJson,
  }) {
    final txId = hex.encode(SHA256Digest().process(rawData));
    return {
      'txID': txId,
      'raw_data': rawDataJson,
      'raw_data_hex': hex.encode(rawData),
      'visible': true,
    };
  }

  Uint8List _rawData({
    required int timestamp,
    required int expiration,
    required List<Uint8List> contracts,
    BigInt? feeLimit,
  }) {
    return _message([
      _bytesField(1, Uint8List.fromList([0, 1])),
      _bytesField(4, Uint8List(8)),
      _varintField(8, BigInt.from(expiration)),
      for (final contract in contracts) _bytesField(11, contract),
      _varintField(14, BigInt.from(timestamp)),
      if (feeLimit != null) _varintField(18, feeLimit),
    ]);
  }

  Uint8List _contract({
    required int type,
    required String typeUrl,
    required Uint8List payload,
  }) {
    final any = _message([
      _bytesField(1, Uint8List.fromList(utf8.encode(typeUrl))),
      _bytesField(2, payload),
    ]);
    return _message([_varintField(1, BigInt.from(type)), _bytesField(2, any)]);
  }

  Uint8List _addressBytes(String address) {
    return Uint8List.fromList(
      hex.decode(WalletTransferService.tronAddressToHex(address)),
    );
  }

  Uint8List _message(List<Uint8List> fields) {
    return Uint8List.fromList(fields.expand((field) => field).toList());
  }

  Uint8List _varintField(int fieldNumber, BigInt value) {
    return Uint8List.fromList([
      ..._varint(BigInt.from(fieldNumber << 3)),
      ..._varint(value),
    ]);
  }

  Uint8List _bytesField(int fieldNumber, Uint8List value) {
    return Uint8List.fromList([
      ..._varint(BigInt.from((fieldNumber << 3) | 2)),
      ..._varint(BigInt.from(value.length)),
      ...value,
    ]);
  }

  List<int> _varint(BigInt input) {
    if (input < BigInt.zero) throw ArgumentError.value(input);
    final result = <int>[];
    var value = input;
    do {
      var byte = (value & BigInt.from(0x7f)).toInt();
      value >>= 7;
      if (value > BigInt.zero) byte |= 0x80;
      result.add(byte);
    } while (value > BigInt.zero);
    return result;
  }

  ResponseBody _jsonResponse(Object data, {int statusCode = 200}) {
    return ResponseBody.fromString(
      jsonEncode(data),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
