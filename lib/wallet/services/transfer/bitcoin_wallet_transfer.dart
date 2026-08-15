part of '../wallet_transfer_service.dart';

extension _BitcoinWalletTransfer on WalletTransferService {
  static const List<String> _bitcoinApiFallbacks = [
    'https://mempool.space/api',
    'https://blockstream.info/api',
  ];
  static const int _bitcoinDustSats = 546;
  static const int _bitcoinDefaultFeeRate = 10;

  Future<TransferFeeEstimate> _estimateBitcoinFee({
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) async {
    final normalizedTo = WalletTransferService.normalizeBitcoinAddress(
      toAddress,
    );
    WalletTransferService.normalizeBitcoinAddress(asset.address);
    final amountSats = WalletTransferService.amountToRawUnits(
      amount,
      asset.decimals,
    );
    Object? lastError;
    for (final apiUrl in _bitcoinApiUrls(asset.chainRef)) {
      try {
        final feeRateResult = await _loadBitcoinFeeRate(apiUrl);
        final utxos = await _loadBitcoinUtxos(apiUrl, asset.address);
        final plan = _selectBitcoinUtxos(
          utxos: utxos,
          amountSats: amountSats,
          feeRate: feeRateResult.rate,
          destinationProgram: _bitcoinWitnessProgram(normalizedTo),
          changeProgram: _bitcoinWitnessProgram(asset.address),
        );
        return TransferFeeEstimate(
          amount: WalletTransferService.rawUnitsToAmount(plan.fee, 8),
          symbol: 'BTC',
          rawAmount: plan.fee,
          isFallback: feeRateResult.isFallback,
        );
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError('Bitcoin fee estimation failed: $lastError');
  }

  Future<String> _transferBitcoin({
    required String privateKeyHex,
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) async {
    final normalizedSource = WalletTransferService.normalizeBitcoinAddress(
      asset.address,
    );
    final normalizedTo = WalletTransferService.normalizeBitcoinAddress(
      toAddress,
    );
    final amountSats = WalletTransferService.amountToRawUnits(
      amount,
      asset.decimals,
    );
    final sourceProgram = _bitcoinWitnessProgram(normalizedSource);
    final publicKey = _bitcoinCompressedPublicKey(privateKeyHex);
    final publicKeyHash = _bitcoinHash160(publicKey);
    if (!WalletTransferService._bytesEqual(publicKeyHash, sourceProgram)) {
      throw StateError('Bitcoin signing key does not match source address');
    }

    Object? lastError;
    Uint8List? transaction;
    String? broadcastApiUrl;
    for (final apiUrl in _bitcoinApiUrls(asset.chainRef)) {
      try {
        final feeRateResult = await _loadBitcoinFeeRate(apiUrl);
        final utxos = await _loadBitcoinUtxos(apiUrl, normalizedSource);
        final plan = _selectBitcoinUtxos(
          utxos: utxos,
          amountSats: amountSats,
          feeRate: feeRateResult.rate,
          destinationProgram: _bitcoinWitnessProgram(normalizedTo),
          changeProgram: sourceProgram,
        );
        transaction = _serializeSignedBitcoinTransaction(
          privateKeyHex: privateKeyHex,
          publicKey: publicKey,
          publicKeyHash: publicKeyHash,
          plan: plan,
        );
        broadcastApiUrl = apiUrl;
        break;
      } catch (error) {
        lastError = error;
      }
    }
    if (transaction == null || broadcastApiUrl == null) {
      throw StateError('Bitcoin transfer preparation failed: $lastError');
    }

    // 广播请求只发送一次。若节点超时，调用方可按本地 pending 状态继续查询，
    // 避免在不确定首个节点是否已接收交易时切换节点重复广播。
    final response = await _dio.post(
      '$broadcastApiUrl/tx',
      data: hex.encode(transaction),
      options: Options(
        contentType: 'text/plain',
        responseType: ResponseType.plain,
      ),
    );
    final txid = response.data?.toString().trim() ?? '';
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(txid)) {
      throw StateError('Invalid Bitcoin broadcast response');
    }
    return txid.toLowerCase();
  }

  Future<_BitcoinFeeRateResult> _loadBitcoinFeeRate(String apiUrl) async {
    try {
      final response = await _dio.get('$apiUrl/v1/fees/recommended');
      final data = response.data;
      if (data is! Map) throw const FormatException('Invalid fee response');
      final parsed = int.tryParse(data['halfHourFee']?.toString() ?? '');
      if (parsed == null || parsed <= 0) {
        throw const FormatException('Invalid Bitcoin fee rate');
      }
      return _BitcoinFeeRateResult(parsed.clamp(1, 1000), false);
    } catch (_) {
      return const _BitcoinFeeRateResult(_bitcoinDefaultFeeRate, true);
    }
  }

  Future<List<_BitcoinUtxo>> _loadBitcoinUtxos(
    String apiUrl,
    String address,
  ) async {
    final response = await _dio.get('$apiUrl/address/$address/utxo');
    final data = response.data;
    if (data is! List) throw const FormatException('Invalid Bitcoin UTXOs');
    final result = <_BitcoinUtxo>[];
    for (final item in data.whereType<Map>()) {
      final txid = item['txid']?.toString() ?? '';
      final vout = int.tryParse(item['vout']?.toString() ?? '');
      final value = BigInt.tryParse(item['value']?.toString() ?? '');
      final status = item['status'];
      final confirmed = status is! Map || status['confirmed'] != false;
      if (RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(txid) &&
          vout != null &&
          vout >= 0 &&
          value != null &&
          value > BigInt.zero &&
          confirmed) {
        result.add(_BitcoinUtxo(txid.toLowerCase(), vout, value));
      }
    }
    result.sort((a, b) => b.value.compareTo(a.value));
    return result;
  }

  _BitcoinSpendPlan _selectBitcoinUtxos({
    required List<_BitcoinUtxo> utxos,
    required BigInt amountSats,
    required int feeRate,
    required Uint8List destinationProgram,
    required Uint8List changeProgram,
  }) {
    if (amountSats < BigInt.from(_bitcoinDustSats)) {
      throw const FormatException('Bitcoin amount is below dust threshold');
    }
    final selected = <_BitcoinUtxo>[];
    var total = BigInt.zero;
    for (final utxo in utxos) {
      selected.add(utxo);
      total += utxo.value;
      final feeWithChange = BigInt.from(
        _bitcoinEstimatedVirtualBytes(selected.length, 2) * feeRate,
      );
      if (total >= amountSats + feeWithChange) {
        final change = total - amountSats - feeWithChange;
        if (change >= BigInt.from(_bitcoinDustSats)) {
          return _BitcoinSpendPlan(
            inputs: List.unmodifiable(selected),
            outputs: [
              _BitcoinOutput(amountSats, destinationProgram),
              _BitcoinOutput(change, changeProgram),
            ],
            fee: feeWithChange,
          );
        }
        return _BitcoinSpendPlan(
          inputs: List.unmodifiable(selected),
          outputs: [_BitcoinOutput(amountSats, destinationProgram)],
          fee: total - amountSats,
        );
      }
      final minimumFee = BigInt.from(
        _bitcoinEstimatedVirtualBytes(selected.length, 1) * feeRate,
      );
      final remainder = total - amountSats - minimumFee;
      if (remainder >= BigInt.zero &&
          remainder < BigInt.from(_bitcoinDustSats)) {
        return _BitcoinSpendPlan(
          inputs: List.unmodifiable(selected),
          outputs: [_BitcoinOutput(amountSats, destinationProgram)],
          fee: total - amountSats,
        );
      }
    }
    throw StateError('Bitcoin balance is insufficient after network fee');
  }

  int _bitcoinEstimatedVirtualBytes(int inputCount, int outputCount) {
    return 11 + (69 * inputCount) + (31 * outputCount);
  }

  Uint8List _serializeSignedBitcoinTransaction({
    required String privateKeyHex,
    required Uint8List publicKey,
    required Uint8List publicKeyHash,
    required _BitcoinSpendPlan plan,
  }) {
    final version = _bitcoinLittleEndian(BigInt.two, 4);
    final sequence = Uint8List.fromList([0xff, 0xff, 0xff, 0xff]);
    final lockTime = Uint8List(4);
    final outpoints = plan.inputs
        .map(_bitcoinSerializeOutpoint)
        .toList(growable: false);
    final serializedOutputs = plan.outputs
        .map(_bitcoinSerializeOutput)
        .toList(growable: false);
    final hashPrevouts = _bitcoinDoubleSha256(
      Uint8List.fromList(outpoints.expand((value) => value).toList()),
    );
    final hashSequence = _bitcoinDoubleSha256(
      Uint8List.fromList(
        List.generate(
          plan.inputs.length,
          (_) => sequence,
        ).expand((value) => value).toList(),
      ),
    );
    final hashOutputs = _bitcoinDoubleSha256(
      Uint8List.fromList(serializedOutputs.expand((value) => value).toList()),
    );
    final scriptCode = Uint8List.fromList([
      0x76,
      0xa9,
      0x14,
      ...publicKeyHash,
      0x88,
      0xac,
    ]);
    final witnesses = <Uint8List>[];
    for (var index = 0; index < plan.inputs.length; index++) {
      final preimage = Uint8List.fromList([
        ...version,
        ...hashPrevouts,
        ...hashSequence,
        ...outpoints[index],
        ..._bitcoinVarInt(scriptCode.length),
        ...scriptCode,
        ..._bitcoinLittleEndian(plan.inputs[index].value, 8),
        ...sequence,
        ...hashOutputs,
        ...lockTime,
        ..._bitcoinLittleEndian(BigInt.one, 4),
      ]);
      final signature = _signHash(
        privateKeyHex,
        _bitcoinDoubleSha256(preimage),
      );
      final derSignature = Uint8List.fromList([
        ..._bitcoinDerSignature(signature),
        0x01,
      ]);
      witnesses.add(
        Uint8List.fromList([
          0x02,
          ..._bitcoinVarInt(derSignature.length),
          ...derSignature,
          ..._bitcoinVarInt(publicKey.length),
          ...publicKey,
        ]),
      );
    }

    return Uint8List.fromList([
      ...version,
      0x00,
      0x01,
      ..._bitcoinVarInt(plan.inputs.length),
      for (final outpoint in outpoints) ...[...outpoint, 0x00, ...sequence],
      ..._bitcoinVarInt(plan.outputs.length),
      ...serializedOutputs.expand((value) => value),
      ...witnesses.expand((value) => value),
      ...lockTime,
    ]);
  }

  Uint8List _bitcoinSerializeOutpoint(_BitcoinUtxo utxo) {
    return Uint8List.fromList([
      ...hex.decode(utxo.txid).reversed,
      ..._bitcoinLittleEndian(BigInt.from(utxo.vout), 4),
    ]);
  }

  Uint8List _bitcoinSerializeOutput(_BitcoinOutput output) {
    final script = Uint8List.fromList([0x00, 0x14, ...output.witnessProgram]);
    return Uint8List.fromList([
      ..._bitcoinLittleEndian(output.value, 8),
      ..._bitcoinVarInt(script.length),
      ...script,
    ]);
  }

  Uint8List _bitcoinWitnessProgram(String address) {
    final normalized = WalletTransferService.normalizeBitcoinAddress(address);
    final separator = normalized.lastIndexOf('1');
    final data = normalized
        .substring(separator + 1, normalized.length - 6)
        .codeUnits
        .map(
          (value) => CryptoConstants.bech32Alphabet.indexOf(
            String.fromCharCode(value),
          ),
        )
        .toList(growable: false);
    return WalletTransferService._convertBitcoinBits(
      data.sublist(1),
      fromBits: 5,
      toBits: 8,
      pad: false,
    );
  }

  Uint8List _bitcoinCompressedPublicKey(String privateKeyHex) {
    final privateKey = BigInt.parse(
      privateKeyHex.replaceFirst(RegExp('^0x'), ''),
      radix: 16,
    );
    if (privateKey <= BigInt.zero || privateKey >= _domain.n) {
      throw const FormatException('Invalid Bitcoin private key');
    }
    return (_domain.G * privateKey)!.getEncoded(true);
  }

  Uint8List _bitcoinHash160(Uint8List input) {
    final sha = WalletTransferService._sha256(input);
    final digest = RIPEMD160Digest()..update(sha, 0, sha.length);
    final output = Uint8List(digest.digestSize);
    digest.doFinal(output, 0);
    return output;
  }

  Uint8List _bitcoinDoubleSha256(Uint8List input) {
    return WalletTransferService._sha256(WalletTransferService._sha256(input));
  }

  Uint8List _bitcoinLittleEndian(BigInt value, int length) {
    if (value < BigInt.zero) throw const FormatException('Negative integer');
    return Uint8List.fromList(
      WalletTransferService._bigIntToBytes(
        value,
        length: length,
      ).reversed.toList(),
    );
  }

  Uint8List _bitcoinVarInt(int value) {
    if (value < 0xfd) return Uint8List.fromList([value]);
    if (value <= 0xffff) {
      return Uint8List.fromList([
        0xfd,
        ..._bitcoinLittleEndian(BigInt.from(value), 2),
      ]);
    }
    if (value <= 0xffffffff) {
      return Uint8List.fromList([
        0xfe,
        ..._bitcoinLittleEndian(BigInt.from(value), 4),
      ]);
    }
    return Uint8List.fromList([
      0xff,
      ..._bitcoinLittleEndian(BigInt.from(value), 8),
    ]);
  }

  Uint8List _bitcoinDerSignature(ECSignature signature) {
    final r = _bitcoinDerInteger(signature.r);
    final s = _bitcoinDerInteger(signature.s);
    return Uint8List.fromList([0x30, r.length + s.length, ...r, ...s]);
  }

  Uint8List _bitcoinDerInteger(BigInt value) {
    var bytes = WalletTransferService._bigIntToBytes(value).toList();
    if (bytes.isEmpty) bytes = [0];
    if ((bytes.first & 0x80) != 0) bytes.insert(0, 0);
    return Uint8List.fromList([0x02, bytes.length, ...bytes]);
  }

  List<String> _bitcoinApiUrls(WalletChainRef chain) {
    final candidates = chain is WalletChainConfig
        ? [...chain.rpcUrls, ..._bitcoinApiFallbacks]
        : [chain.rpcUrl, ..._bitcoinApiFallbacks];
    final seen = <String>{};
    return candidates
        .map((value) => value.trim().replaceAll(RegExp(r'/+$'), ''))
        .where((value) => value.isNotEmpty && seen.add(value))
        .toList(growable: false);
  }
}

class _BitcoinUtxo {
  const _BitcoinUtxo(this.txid, this.vout, this.value);

  final String txid;
  final int vout;
  final BigInt value;
}

class _BitcoinOutput {
  const _BitcoinOutput(this.value, this.witnessProgram);

  final BigInt value;
  final Uint8List witnessProgram;
}

class _BitcoinSpendPlan {
  const _BitcoinSpendPlan({
    required this.inputs,
    required this.outputs,
    required this.fee,
  });

  final List<_BitcoinUtxo> inputs;
  final List<_BitcoinOutput> outputs;
  final BigInt fee;
}

class _BitcoinFeeRateResult {
  const _BitcoinFeeRateResult(this.rate, this.isFallback);

  final int rate;
  final bool isFallback;
}
