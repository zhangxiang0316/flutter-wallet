import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/digests/keccak.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/signers/ecdsa_signer.dart';

import '../models/chain_balance.dart';
import '../models/wallet_chain.dart';

class WalletTransferService {
  WalletTransferService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: _requestTimeout,
              receiveTimeout: _requestTimeout,
              sendTimeout: _requestTimeout,
            ),
          ),
      _domain = ECCurve_secp256k1();

  final Dio _dio;
  final ECDomainParameters _domain;

  static const Duration _requestTimeout = Duration(seconds: 20);
  static const int _evmNativeGasLimit = 21000;
  static const int _evmTokenGasLimit = 100000;
  static const int _tronTokenFeeLimit = 30 * 1000 * 1000;
  static const String _base58Alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  static final BigInt _secp256k1P = BigInt.parse(
    'fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f',
    radix: 16,
  );

  Future<String> transfer({
    required String privateKeyHex,
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) {
    switch (asset.chain) {
      case WalletChain.bsc:
      case WalletChain.ethereum:
      case WalletChain.xLayer:
        return _transferEvm(
          privateKeyHex: privateKeyHex,
          asset: asset,
          toAddress: toAddress,
          amount: amount,
        );
      case WalletChain.tron:
        return _transferTron(
          privateKeyHex: privateKeyHex,
          asset: asset,
          toAddress: toAddress,
          amount: amount,
        );
    }
  }

  Future<TransferFeeEstimate> estimateFee({
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) {
    switch (asset.chain) {
      case WalletChain.bsc:
      case WalletChain.ethereum:
      case WalletChain.xLayer:
        return _estimateEvmFee(
          asset: asset,
          toAddress: toAddress,
          amount: amount,
        );
      case WalletChain.tron:
        return _estimateTronFee(
          asset: asset,
          toAddress: toAddress,
          amount: amount,
        );
    }
  }

  Future<TransferFeeEstimate> _estimateEvmFee({
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) async {
    final normalizedTo = normalizeEvmAddress(toAddress);
    final value = amountToRawUnits(amount, asset.decimals);
    final isNative = asset.isNative;
    final txTo = isNative ? normalizedTo : asset.contractAddress!;
    final txValue = isNative ? value : BigInt.zero;
    final data = isNative ? '0x' : erc20TransferData(normalizedTo, value);
    final gasPrice = await _evmRpcBigInt(asset.chain, 'eth_gasPrice', const []);
    BigInt gasLimit;
    try {
      gasLimit = await _evmRpcBigInt(asset.chain, 'eth_estimateGas', [
        {
          'from': asset.address,
          'to': txTo,
          'value': _hexQuantity(txValue),
          if (!isNative) 'data': data,
        },
      ]);
    } catch (_) {
      gasLimit = BigInt.from(isNative ? _evmNativeGasLimit : _evmTokenGasLimit);
    }

    final feeWei = gasLimit * gasPrice;
    return TransferFeeEstimate(
      amount: rawUnitsToAmount(feeWei, 18),
      symbol: asset.chain.symbol,
      rawAmount: feeWei,
      isFallback: false,
    );
  }

  Future<TransferFeeEstimate> _estimateTronFee({
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) async {
    final value = amountToRawUnits(amount, asset.decimals);
    final chainParameters = await _loadTronChainParameters();
    final transactionFee = chainParameters['getTransactionFee'] ?? BigInt.one;
    final energyFee = chainParameters['getEnergyFee'] ?? BigInt.from(420);

    if (asset.isNative) {
      final transaction = await _createTronNativeTransaction(
        fromAddress: asset.address,
        toAddress: toAddress,
        amount: value,
      );
      final rawDataHex = transaction['raw_data_hex']?.toString() ?? '';
      final bandwidthBytes = BigInt.from(rawDataHex.length ~/ 2);
      final feeSun = bandwidthBytes * transactionFee;
      return TransferFeeEstimate(
        amount: rawUnitsToAmount(feeSun, 6),
        symbol: WalletChain.tron.symbol,
        rawAmount: feeSun,
        isFallback: false,
      );
    }

    final energy = await _estimateTronEnergy(
      fromAddress: asset.address,
      toAddress: toAddress,
      contractAddress: asset.contractAddress!,
      amount: value,
    );
    if (energy != null) {
      final transaction = await _createTronTokenTransaction(
        fromAddress: asset.address,
        toAddress: toAddress,
        contractAddress: asset.contractAddress!,
        amount: value,
      );
      final rawDataHex = transaction['raw_data_hex']?.toString() ?? '';
      final bandwidthFee = BigInt.from(rawDataHex.length ~/ 2) * transactionFee;
      final feeSun = energy * energyFee + bandwidthFee;
      return TransferFeeEstimate(
        amount: rawUnitsToAmount(feeSun, 6),
        symbol: WalletChain.tron.symbol,
        rawAmount: feeSun,
        isFallback: false,
      );
    }

    final fallbackFee = BigInt.from(_tronTokenFeeLimit);
    return TransferFeeEstimate(
      amount: rawUnitsToAmount(fallbackFee, 6),
      symbol: WalletChain.tron.symbol,
      rawAmount: fallbackFee,
      isFallback: true,
    );
  }

  Future<String> _transferEvm({
    required String privateKeyHex,
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) async {
    final chainId = asset.chain.evmChainId;
    if (chainId == null) {
      throw StateError('${asset.chain.name} is not an EVM chain');
    }

    final normalizedTo = normalizeEvmAddress(toAddress);
    final value = amountToRawUnits(amount, asset.decimals);
    final gasPrice = await _evmRpcBigInt(asset.chain, 'eth_gasPrice', const []);
    final nonce = await _evmRpcBigInt(asset.chain, 'eth_getTransactionCount', [
      asset.address,
      'latest',
    ]);

    final isNative = asset.isNative;
    final txTo = isNative ? normalizedTo : asset.contractAddress!;
    final txValue = isNative ? value : BigInt.zero;
    final data = isNative
        ? Uint8List(0)
        : hexToBytes(erc20TransferData(normalizedTo, value));
    final gasLimit = isNative ? _evmNativeGasLimit : _evmTokenGasLimit;
    final rawTx = _signEvmTransaction(
      privateKeyHex: privateKeyHex,
      nonce: nonce,
      gasPrice: gasPrice,
      gasLimit: BigInt.from(gasLimit),
      toAddress: txTo,
      value: txValue,
      data: data,
      chainId: chainId,
    );
    final response = await _evmRpc(asset.chain, 'eth_sendRawTransaction', [
      '0x$rawTx',
    ]);
    if (response is String && response.isNotEmpty) {
      return response;
    }
    throw StateError('${asset.chain.name} transfer failed');
  }

  Future<String> _transferTron({
    required String privateKeyHex,
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) async {
    final value = amountToRawUnits(amount, asset.decimals);
    final transaction = asset.isNative
        ? await _createTronNativeTransaction(
            fromAddress: asset.address,
            toAddress: toAddress,
            amount: value,
          )
        : await _createTronTokenTransaction(
            fromAddress: asset.address,
            toAddress: toAddress,
            contractAddress: asset.contractAddress!,
            amount: value,
          );

    final signedTransaction = _signTronTransaction(
      privateKeyHex: privateKeyHex,
      transaction: transaction,
    );
    final response = await _dio.post(
      '${WalletChain.tron.rpcUrl}/wallet/broadcasttransaction',
      data: signedTransaction,
      options: Options(headers: {'content-type': 'application/json'}),
    );
    final data = response.data;
    if (data is Map && data['result'] == true) {
      return data['txid']?.toString() ??
          signedTransaction['txID']?.toString() ??
          '';
    }
    throw StateError(data is Map ? data.toString() : 'TRON transfer failed');
  }

  Future<Map<String, dynamic>> _createTronNativeTransaction({
    required String fromAddress,
    required String toAddress,
    required BigInt amount,
  }) async {
    final response = await _dio.post(
      '${WalletChain.tron.rpcUrl}/wallet/createtransaction',
      data: {
        'owner_address': fromAddress,
        'to_address': toAddress,
        'amount': amount.toInt(),
        'visible': true,
      },
      options: Options(headers: {'content-type': 'application/json'}),
    );
    final data = response.data;
    if (data is Map && data['raw_data_hex'] is String) {
      return Map<String, dynamic>.from(data);
    }
    throw StateError('Invalid TRON transaction response');
  }

  Future<Map<String, dynamic>> _createTronTokenTransaction({
    required String fromAddress,
    required String toAddress,
    required String contractAddress,
    required BigInt amount,
  }) async {
    final response = await _dio.post(
      '${WalletChain.tron.rpcUrl}/wallet/triggersmartcontract',
      data: {
        'owner_address': fromAddress,
        'contract_address': contractAddress,
        'function_selector': 'transfer(address,uint256)',
        'parameter': trc20TransferParameter(toAddress, amount),
        'fee_limit': _tronTokenFeeLimit,
        'call_value': 0,
        'visible': true,
      },
      options: Options(headers: {'content-type': 'application/json'}),
    );
    final data = response.data;
    if (data is Map && data['transaction'] is Map) {
      return Map<String, dynamic>.from(data['transaction'] as Map);
    }
    throw StateError('Invalid TRC20 transaction response');
  }

  Future<dynamic> _evmRpc(
    WalletChain chain,
    String method,
    List<dynamic> params,
  ) async {
    final response = await _dio.post(
      chain.rpcUrl,
      data: {'jsonrpc': '2.0', 'method': method, 'params': params, 'id': 1},
      options: Options(headers: {'content-type': 'application/json'}),
    );
    final data = response.data;
    if (data is Map && data['result'] != null) {
      return data['result'];
    }
    throw StateError(
      data is Map ? data.toString() : 'Invalid ${chain.name} response',
    );
  }

  Future<BigInt> _evmRpcBigInt(
    WalletChain chain,
    String method,
    List<dynamic> params,
  ) async {
    final result = await _evmRpc(chain, method, params);
    if (result is! String) {
      throw StateError('Invalid ${chain.name} number response');
    }
    return BigInt.parse(result.replaceFirst('0x', ''), radix: 16);
  }

  Future<Map<String, BigInt>> _loadTronChainParameters() async {
    try {
      final response = await _dio.get(
        '${WalletChain.tron.rpcUrl}/wallet/getchainparameters',
        options: Options(headers: {'content-type': 'application/json'}),
      );
      final data = response.data;
      if (data is! Map || data['chainParameter'] is! List) {
        return {};
      }
      final values = <String, BigInt>{};
      for (final item in data['chainParameter'] as List) {
        if (item is! Map) continue;
        final key = item['key']?.toString();
        final value = BigInt.tryParse(item['value']?.toString() ?? '');
        if (key != null && value != null) {
          values[key] = value;
        }
      }
      return values;
    } catch (_) {
      return {};
    }
  }

  Future<BigInt?> _estimateTronEnergy({
    required String fromAddress,
    required String toAddress,
    required String contractAddress,
    required BigInt amount,
  }) async {
    try {
      final response = await _dio.post(
        '${WalletChain.tron.rpcUrl}/wallet/estimateenergy',
        data: {
          'owner_address': fromAddress,
          'contract_address': contractAddress,
          'function_selector': 'transfer(address,uint256)',
          'parameter': trc20TransferParameter(toAddress, amount),
          'visible': true,
        },
        options: Options(headers: {'content-type': 'application/json'}),
      );
      final data = response.data;
      if (data is! Map) return null;
      final value = data['energy_required'] ?? data['energy_used'];
      return BigInt.tryParse(value?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  String _signEvmTransaction({
    required String privateKeyHex,
    required BigInt nonce,
    required BigInt gasPrice,
    required BigInt gasLimit,
    required String toAddress,
    required BigInt value,
    required Uint8List data,
    required int chainId,
  }) {
    final toBytes = hexToBytes(normalizeBscAddress(toAddress));
    final signingPayload = _rlpEncode([
      nonce,
      gasPrice,
      gasLimit,
      toBytes,
      value,
      data,
      BigInt.from(chainId),
      BigInt.zero,
      BigInt.zero,
    ]);
    final hash = _keccak(signingPayload);
    final signature = _signHash(privateKeyHex, hash);
    final recoveryId = _findRecoveryId(privateKeyHex, hash, signature);
    final v = BigInt.from(recoveryId + 35 + chainId * 2);
    final rawPayload = _rlpEncode([
      nonce,
      gasPrice,
      gasLimit,
      toBytes,
      value,
      data,
      v,
      signature.r,
      signature.s,
    ]);
    return hex.encode(rawPayload);
  }

  Map<String, dynamic> _signTronTransaction({
    required String privateKeyHex,
    required Map<String, dynamic> transaction,
  }) {
    final rawDataHex = transaction['raw_data_hex']?.toString();
    if (rawDataHex == null || rawDataHex.isEmpty) {
      throw StateError('Missing TRON raw data');
    }
    final hash = _sha256(hexToBytes(rawDataHex));
    final signature = _signHash(privateKeyHex, hash);
    final recoveryId = _findRecoveryId(privateKeyHex, hash, signature);
    final signatureBytes = Uint8List.fromList([
      ..._bigIntToBytes(signature.r, length: 32),
      ..._bigIntToBytes(signature.s, length: 32),
      recoveryId,
    ]);

    final signed = Map<String, dynamic>.from(transaction);
    signed['signature'] = [hex.encode(signatureBytes)];
    return signed;
  }

  ECSignature _signHash(String privateKeyHex, Uint8List hash) {
    final privateKey = BigInt.parse(
      privateKeyHex.replaceFirst(RegExp('^0x'), ''),
      radix: 16,
    );
    final signer = ECDSASigner(null, HMac(SHA256Digest(), 64));
    signer.init(
      true,
      PrivateKeyParameter<ECPrivateKey>(ECPrivateKey(privateKey, _domain)),
    );
    return (signer.generateSignature(hash) as ECSignature).normalize(_domain);
  }

  int _findRecoveryId(
    String privateKeyHex,
    Uint8List hash,
    ECSignature signature,
  ) {
    final privateKey = BigInt.parse(
      privateKeyHex.replaceFirst(RegExp('^0x'), ''),
      radix: 16,
    );
    final publicKey = (_domain.G * privateKey)!;
    final publicKeyBytes = publicKey.getEncoded(false);
    for (var i = 0; i < 4; i++) {
      final recovered = _recoverPublicKey(i, signature, hash);
      if (recovered != null &&
          _bytesEqual(recovered.getEncoded(false), publicKeyBytes)) {
        return i;
      }
    }
    throw StateError('Failed to recover signature id');
  }

  ECPoint? _recoverPublicKey(
    int recoveryId,
    ECSignature signature,
    Uint8List hash,
  ) {
    final n = _domain.n;
    final i = BigInt.from(recoveryId ~/ 2);
    final x = signature.r + i * n;
    if (x >= _secp256k1P) return null;

    final r = _domain.curve.decompressPoint(recoveryId & 1, x);
    if (!(r * n)!.isInfinity) return null;

    final e = _bytesToBigInt(hash);
    final eInv = (BigInt.zero - e) % n;
    final rInv = signature.r.modInverse(n);
    final srInv = (signature.s * rInv) % n;
    final eInvRInv = (eInv * rInv) % n;
    return (_domain.G * eInvRInv)! + (r * srInv);
  }

  static BigInt amountToRawUnits(String amount, int decimals) {
    final normalized = amount.trim();
    final value = Decimal.tryParse(normalized);
    if (value == null || value <= Decimal.zero) {
      throw const FormatException('Invalid transfer amount');
    }
    final shifted = value.shift(decimals);
    if (!shifted.isInteger) {
      throw const FormatException('Too many decimal places');
    }
    return shifted.toBigInt();
  }

  static String rawUnitsToAmount(BigInt value, int decimals) {
    final base = BigInt.from(10).pow(decimals);
    final whole = value ~/ base;
    final fraction = value.remainder(base).toString().padLeft(decimals, '0');
    final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
    if (trimmed.isEmpty) {
      return whole.toString();
    }
    final displayFraction = trimmed.length > 8
        ? trimmed.substring(0, 8)
        : trimmed;
    return '$whole.$displayFraction';
  }

  static String _hexQuantity(BigInt value) {
    return '0x${value.toRadixString(16)}';
  }

  static String erc20TransferData(String toAddress, BigInt amount) {
    final address = normalizeEvmAddress(toAddress);
    return '0xa9059cbb'
        '000000000000000000000000${address.replaceFirst('0x', '')}'
        '${amount.toRadixString(16).padLeft(64, '0')}';
  }

  static String trc20TransferParameter(String toAddress, BigInt amount) {
    final tronHex = tronAddressToHex(toAddress);
    return '000000000000000000000000${tronHex.substring(2)}'
        '${amount.toRadixString(16).padLeft(64, '0')}';
  }

  static String normalizeBscAddress(String input) {
    return normalizeEvmAddress(input);
  }

  static String normalizeEvmAddress(String input) {
    final address = input.trim();
    if (!RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(address)) {
      throw const FormatException('Invalid EVM address');
    }
    return '0x${address.substring(2).toLowerCase()}';
  }

  static String tronAddressToHex(String address) {
    final payload = _base58CheckDecode(address.trim());
    if (payload.length != 21 || payload.first != 0x41) {
      throw const FormatException('Invalid TRON address');
    }
    return hex.encode(payload);
  }

  static Uint8List hexToBytes(String value) {
    return Uint8List.fromList(hex.decode(value.replaceFirst('0x', '')));
  }

  static Uint8List _rlpEncode(dynamic value) {
    if (value is BigInt) {
      if (value == BigInt.zero) {
        return _rlpEncodeBytes(Uint8List(0));
      }
      return _rlpEncodeBytes(_bigIntToBytes(value));
    }
    if (value is int) {
      return _rlpEncode(BigInt.from(value));
    }
    if (value is Uint8List) {
      return _rlpEncodeBytes(value);
    }
    if (value is List<int>) {
      return _rlpEncodeBytes(Uint8List.fromList(value));
    }
    if (value is List) {
      final payload = Uint8List.fromList(value.expand(_rlpEncode).toList());
      if (payload.length < 56) {
        return Uint8List.fromList([0xc0 + payload.length, ...payload]);
      }
      final lengthBytes = _bigIntToBytes(BigInt.from(payload.length));
      return Uint8List.fromList([
        0xf7 + lengthBytes.length,
        ...lengthBytes,
        ...payload,
      ]);
    }
    throw ArgumentError('Unsupported RLP value');
  }

  static Uint8List _rlpEncodeBytes(Uint8List bytes) {
    if (bytes.length == 1 && bytes.first < 0x80) {
      return bytes;
    }
    if (bytes.length < 56) {
      return Uint8List.fromList([0x80 + bytes.length, ...bytes]);
    }
    final lengthBytes = _bigIntToBytes(BigInt.from(bytes.length));
    return Uint8List.fromList([
      0xb7 + lengthBytes.length,
      ...lengthBytes,
      ...bytes,
    ]);
  }

  static Uint8List _keccak(Uint8List input) {
    final digest = KeccakDigest(256)..update(input, 0, input.length);
    final output = Uint8List(32);
    digest.doFinal(output, 0);
    return output;
  }

  static Uint8List _sha256(Uint8List input) {
    final digest = SHA256Digest()..update(input, 0, input.length);
    final output = Uint8List(32);
    digest.doFinal(output, 0);
    return output;
  }

  static Uint8List _base58CheckDecode(String input) {
    var value = BigInt.zero;
    for (final codeUnit in input.codeUnits) {
      final digit = _base58Alphabet.indexOf(String.fromCharCode(codeUnit));
      if (digit < 0) {
        throw const FormatException('Invalid Base58 character');
      }
      value = value * BigInt.from(58) + BigInt.from(digit);
    }

    final bytes = _bigIntToBytes(value).toList();
    var leadingZeros = 0;
    for (final codeUnit in input.codeUnits) {
      if (String.fromCharCode(codeUnit) == _base58Alphabet[0]) {
        leadingZeros++;
      } else {
        break;
      }
    }
    final decoded = Uint8List.fromList([
      ...List<int>.filled(leadingZeros, 0),
      ...bytes,
    ]);
    if (decoded.length < 5) {
      throw const FormatException('Invalid Base58Check payload');
    }
    final payload = decoded.sublist(0, decoded.length - 4);
    final checksum = decoded.sublist(decoded.length - 4);
    final expected = _sha256(_sha256(payload)).sublist(0, 4);
    if (!_bytesEqual(checksum, expected)) {
      throw const FormatException('Invalid Base58Check checksum');
    }
    return payload;
  }

  static Uint8List _bigIntToBytes(BigInt value, {int? length}) {
    if (value == BigInt.zero) {
      return Uint8List(length ?? 0);
    }
    final bytes = <int>[];
    var current = value;
    while (current > BigInt.zero) {
      bytes.add((current & BigInt.from(0xff)).toInt());
      current >>= 8;
    }
    final result = bytes.reversed.toList();
    if (length != null) {
      if (result.length > length) {
        throw ArgumentError('BigInt does not fit in $length bytes');
      }
      return Uint8List.fromList([
        ...List<int>.filled(length - result.length, 0),
        ...result,
      ]);
    }
    return Uint8List.fromList(result);
  }

  static BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

class TransferFeeEstimate {
  const TransferFeeEstimate({
    required this.amount,
    required this.symbol,
    required this.rawAmount,
    this.isFallback = false,
  });

  final String amount;
  final String symbol;
  final BigInt rawAmount;
  final bool isFallback;

  String get displayText => '$amount $symbol';
}
