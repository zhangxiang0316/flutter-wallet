part of '../wallet_transfer_service.dart';

extension _TronWalletTransfer on WalletTransferService {
  Future<TransferFeeEstimate> _estimateTronFee({
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) async {
    final value = WalletTransferService.amountToRawUnits(
      amount,
      asset.decimals,
    );
    final chainParameters = await _loadTronChainParameters(asset.chainRef);
    final transactionFee = chainParameters['getTransactionFee'] ?? BigInt.one;
    final energyFee = chainParameters['getEnergyFee'] ?? BigInt.from(420);

    if (asset.isNative) {
      final transaction = await _createTronNativeTransaction(
        chain: asset.chainRef,
        fromAddress: asset.address,
        toAddress: toAddress,
        amount: value,
      );
      final rawDataHex = transaction['raw_data_hex']?.toString() ?? '';
      final bandwidthBytes = BigInt.from(rawDataHex.length ~/ 2);
      final feeSun = bandwidthBytes * transactionFee;
      return TransferFeeEstimate(
        amount: WalletTransferService.rawUnitsToAmount(feeSun, 6),
        symbol: asset.chainRef.symbol,
        rawAmount: feeSun,
        isFallback: false,
      );
    }

    final energy = await _estimateTronEnergy(
      chain: asset.chainRef,
      fromAddress: asset.address,
      toAddress: toAddress,
      contractAddress: asset.contractAddress!,
      amount: value,
    );
    if (energy != null) {
      final transaction = await _createTronTokenTransaction(
        chain: asset.chainRef,
        fromAddress: asset.address,
        toAddress: toAddress,
        contractAddress: asset.contractAddress!,
        amount: value,
      );
      final rawDataHex = transaction['raw_data_hex']?.toString() ?? '';
      final bandwidthFee = BigInt.from(rawDataHex.length ~/ 2) * transactionFee;
      final feeSun = energy * energyFee + bandwidthFee;
      return TransferFeeEstimate(
        amount: WalletTransferService.rawUnitsToAmount(feeSun, 6),
        symbol: asset.chainRef.symbol,
        rawAmount: feeSun,
        isFallback: false,
      );
    }

    final fallbackFee = BigInt.from(WalletTransferService._tronTokenFeeLimit);
    return TransferFeeEstimate(
      amount: WalletTransferService.rawUnitsToAmount(fallbackFee, 6),
      symbol: asset.chainRef.symbol,
      rawAmount: fallbackFee,
      isFallback: true,
    );
  }

  /// 估算 Solana 转账手续费。
  ///
  /// 当前使用单签名固定费用估算。SPL Token 实际交易会额外包含创建 ATA 的指令，
  /// 这里先返回基础 fallback 费用，避免 UI 阻塞在复杂模拟请求上。
  Future<String> _transferTron({
    required String privateKeyHex,
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) async {
    final value = WalletTransferService.amountToRawUnits(
      amount,
      asset.decimals,
    );
    final transaction = asset.isNative
        ? await _createTronNativeTransaction(
            chain: asset.chainRef,
            fromAddress: asset.address,
            toAddress: toAddress,
            amount: value,
          )
        : await _createTronTokenTransaction(
            chain: asset.chainRef,
            fromAddress: asset.address,
            toAddress: toAddress,
            contractAddress: asset.contractAddress!,
            amount: value,
          );

    _validateTronTransactionForSigning(
      privateKeyHex: privateKeyHex,
      transaction: transaction,
      asset: asset,
      toAddress: toAddress,
      amount: value,
    );
    final signedTransaction = _signTronTransaction(
      privateKeyHex: privateKeyHex,
      transaction: transaction,
    );
    final response = await _dio.post(
      '${asset.chainRef.rpcUrl}/wallet/broadcasttransaction',
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

  /// 发送 Solana 交易。
  ///
  /// 先根据私钥恢复 signer，并校验 signer 地址必须等于资产发送方地址，防止拿错钱包
  /// 私钥后签出错误交易。原生 SOL 和 SPL Token 使用不同 message 构造逻辑。
  Future<Map<String, dynamic>> _createTronNativeTransaction({
    required WalletChainRef chain,
    required String fromAddress,
    required String toAddress,
    required BigInt amount,
  }) async {
    final response = await _dio.post(
      '${chain.rpcUrl}/wallet/createtransaction',
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

  /// 创建 TRC20 转账交易。
  ///
  /// 使用 `triggersmartcontract` 调用 `transfer(address,uint256)`，参数由
  /// [WalletTransferService.trc20TransferParameter] 按 ABI 格式编码。
  Future<Map<String, dynamic>> _createTronTokenTransaction({
    required WalletChainRef chain,
    required String fromAddress,
    required String toAddress,
    required String contractAddress,
    required BigInt amount,
  }) async {
    final response = await _dio.post(
      '${chain.rpcUrl}/wallet/triggersmartcontract',
      data: {
        'owner_address': fromAddress,
        'contract_address': contractAddress,
        'function_selector': 'transfer(address,uint256)',
        'parameter': WalletTransferService.trc20TransferParameter(
          toAddress,
          amount,
        ),
        'fee_limit': WalletTransferService._tronTokenFeeLimit,
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

  /// 发送 EVM JSON-RPC 请求并返回 result。
  Future<Map<String, BigInt>> _loadTronChainParameters(
    WalletChainRef chain,
  ) async {
    try {
      final response = await _dio.get(
        '${chain.rpcUrl}/wallet/getchainparameters',
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

  /// 估算 TRC20 转账所需能量。
  ///
  /// 公共节点可能不支持该接口，所以失败时返回 null，并由调用方使用 fee_limit 兜底。
  Future<BigInt?> _estimateTronEnergy({
    required WalletChainRef chain,
    required String fromAddress,
    required String toAddress,
    required String contractAddress,
    required BigInt amount,
  }) async {
    try {
      final response = await _dio.post(
        '${chain.rpcUrl}/wallet/estimateenergy',
        data: {
          'owner_address': fromAddress,
          'contract_address': contractAddress,
          'function_selector': 'transfer(address,uint256)',
          'parameter': WalletTransferService.trc20TransferParameter(
            toAddress,
            amount,
          ),
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

  /// 签名 TRON transaction。
  ///
  /// 对节点返回的 `raw_data_hex` 做 SHA-256 和 ECDSA 签名，并把签名追加到
  /// transaction 后交给广播接口。
  Map<String, dynamic> _signTronTransaction({
    required String privateKeyHex,
    required Map<String, dynamic> transaction,
  }) {
    final rawDataHex = transaction['raw_data_hex']?.toString();
    if (rawDataHex == null || rawDataHex.isEmpty) {
      throw StateError('Missing TRON raw data');
    }
    final hash = WalletTransferService._sha256(
      WalletTransferService.hexToBytes(rawDataHex),
    );
    final signature = _signHash(privateKeyHex, hash);
    final recoveryId = _findRecoveryId(privateKeyHex, hash, signature);
    final signatureBytes = Uint8List.fromList([
      ...WalletTransferService._bigIntToBytes(signature.r, length: 32),
      ...WalletTransferService._bigIntToBytes(signature.s, length: 32),
      recoveryId,
    ]);

    final signed = Map<String, dynamic>.from(transaction);
    signed['signature'] = [hex.encode(signatureBytes)];
    return signed;
  }

  /// 构造 SOL 原生转账 message。
}
