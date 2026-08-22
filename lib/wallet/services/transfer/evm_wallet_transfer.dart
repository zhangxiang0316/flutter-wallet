part of '../wallet_transfer_service.dart';

const int _baseMainnetChainId = 8453;
const int _evmGasLimitSafetyNumerator = 120;
const int _evmGasLimitSafetyDenominator = 100;
const int _evmMaximumGasLimit = 1500000;
const int _evmDefaultPriorityFeeWei = 1000000000;
const String _baseGasPriceOracleAddress =
    '0x420000000000000000000000000000000000000F';
const List<String> _baseEvmRpcFallbacks = [
  'https://base-rpc.publicnode.com',
  'https://rpc.ankr.com/base',
  'https://base.llamarpc.com',
  'https://mainnet.base.org',
];
const List<String> _polygonEvmRpcFallbacks = [
  'https://polygon.drpc.org',
  'https://polygon.publicnode.com',
  'https://tenderly.rpc.polygon.community',
  'https://1rpc.io/matic',
];
const List<String> _avalancheEvmRpcFallbacks = [
  'https://api.avax.network/ext/bc/C/rpc',
  'https://avalanche-c-chain-rpc.publicnode.com',
  'https://avalanche.drpc.org',
  'https://1rpc.io/avax/c',
];
final BigInt _maxEvmUint256 = (BigInt.one << 256) - BigInt.one;
final String _baseGetL1FeeUpperBoundSelector = hex.encode(
  WalletTransferService._keccak(
    Uint8List.fromList(utf8.encode('getL1FeeUpperBound(uint256)')),
  ).sublist(0, 4),
);

extension _EvmWalletTransfer on WalletTransferService {
  Future<TransferFeeEstimate> _estimateEvmFee({
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) async {
    final draft = await _prepareEvmTransaction(
      asset: asset,
      toAddress: toAddress,
      amount: amount,
    );
    return TransferFeeEstimate(
      amount: WalletTransferService.rawUnitsToAmount(draft.maximumFee, 18),
      symbol: asset.chainRef.symbol,
      rawAmount: draft.maximumFee,
      isFallback: draft.usedFallbackGasLimit,
      evmDraft: draft,
    );
  }

  Future<EvmTransactionDraft> _prepareEvmTransaction({
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) async {
    final chainId = asset.chainRef.evmChainId;
    if (chainId == null) {
      throw StateError('${asset.chainRef.name} is not an EVM chain');
    }

    final normalizedFrom = WalletTransferService.normalizeEvmAddress(
      asset.address,
    );
    final normalizedRecipient = WalletTransferService.normalizeEvmAddress(
      toAddress,
    );
    final transferValue = WalletTransferService.amountToRawUnits(
      amount,
      asset.decimals,
    );
    final isNative = asset.isNative;
    final txTo = isNative
        ? normalizedRecipient
        : WalletTransferService.normalizeEvmAddress(asset.contractAddress!);
    final txValue = isNative ? transferValue : BigInt.zero;
    final data = isNative
        ? '0x'
        : WalletTransferService.erc20TransferData(
            normalizedRecipient,
            transferValue,
          );
    final rpcCall = <String, dynamic>{
      'from': normalizedFrom,
      'to': txTo,
      'value': WalletTransferService._hexQuantity(txValue),
      if (!isNative) 'data': data,
    };

    final feeParameters = await _loadEvmFeeParameters(asset.chainRef);
    final nonce = await _evmRpcBigInt(
      asset.chainRef,
      'eth_getTransactionCount',
      [normalizedFrom, 'pending'],
    );

    BigInt? estimatedGasLimit;
    try {
      estimatedGasLimit = await _evmRpcBigInt(
        asset.chainRef,
        'eth_estimateGas',
        [rpcCall],
      );
    } catch (_) {
      estimatedGasLimit = null;
    }
    final usedFallbackGasLimit = estimatedGasLimit == null;
    final gasLimit = estimatedGasLimit == null
        ? BigInt.from(
            isNative
                ? WalletTransferService._evmNativeGasLimit
                : WalletTransferService._evmTokenGasLimit,
          )
        : _applyEvmGasSafetyLimit(estimatedGasLimit);

    var l1DataFee = BigInt.zero;
    if (_isBaseMainnet(asset.chainRef)) {
      l1DataFee = await _estimateBaseL1FeeUpperBound(
        chain: asset.chainRef,
        gasPrice: feeParameters.feePerGas,
        gasLimit: gasLimit,
        toAddress: txTo,
        value: txValue,
        data: data,
      );
    }
    return EvmTransactionDraft(
      chainId: chainId,
      from: normalizedFrom,
      to: txTo,
      value: txValue,
      data: data,
      nonce: nonce,
      gasLimit: gasLimit,
      feeType: feeParameters.feeType,
      gasPrice: feeParameters.gasPrice,
      maxFeePerGas: feeParameters.maxFeePerGas,
      maxPriorityFeePerGas: feeParameters.maxPriorityFeePerGas,
      l1DataFee: l1DataFee,
      usedFallbackGasLimit: usedFallbackGasLimit,
    );
  }

  /// 估算 TRON 转账手续费。
  ///
  /// TRX 原生转账主要消耗带宽，TRC20 转账还需要能量。这里会读取链参数里的
  /// `getTransactionFee` 和 `getEnergyFee`，再按交易字节数和能量估算 sun。
  Future<String> _transferEvm({
    required String privateKeyHex,
    required ChainBalance asset,
    required String toAddress,
    required String amount,
    EvmTransactionDraft? draft,
  }) async {
    final chainId = asset.chainRef.evmChainId;
    if (chainId == null) {
      throw StateError('${asset.chainRef.name} is not an EVM chain');
    }

    final signerAddress = WalletCryptoService().evmAddressFromPrivateKey(
      privateKeyHex,
    );
    final expectedFrom = WalletTransferService.normalizeEvmAddress(
      asset.address,
    );
    if (WalletTransferService.normalizeEvmAddress(signerAddress) !=
        expectedFrom) {
      throw StateError('EVM signer does not match transfer sender');
    }

    final transactionDraft =
        draft ??
        await _prepareEvmTransaction(
          asset: asset,
          toAddress: toAddress,
          amount: amount,
        );
    _validateEvmDraft(
      draft: transactionDraft,
      asset: asset,
      toAddress: toAddress,
      amount: amount,
    );
    if (simulateEvmTransactions) {
      await _simulateEvmTransaction(asset.chainRef, transactionDraft);
    }
    final rawTx = _signEvmTransaction(
      privateKeyHex: privateKeyHex,
      draft: transactionDraft,
    );
    final response = await _evmRpc(asset.chainRef, 'eth_sendRawTransaction', [
      '0x$rawTx',
    ]);
    if (response is String && response.isNotEmpty) {
      return response;
    }
    throw StateError('${asset.chainRef.name} transfer failed');
  }

  Future<_EvmFeeParameters> _loadEvmFeeParameters(WalletChainRef chain) async {
    try {
      final latestBlock = await _evmRpc(chain, 'eth_getBlockByNumber', [
        'latest',
        false,
      ]);
      if (latestBlock is Map && latestBlock['baseFeePerGas'] is String) {
        final baseFee = _parseEvmQuantity(
          latestBlock['baseFeePerGas'] as String,
        );
        if (baseFee > BigInt.zero) {
          BigInt priorityFee;
          try {
            priorityFee = await _evmRpcBigInt(
              chain,
              'eth_maxPriorityFeePerGas',
              const [],
            );
          } catch (_) {
            final suggestedGasPrice = await _evmRpcBigInt(
              chain,
              'eth_gasPrice',
              const [],
            );
            priorityFee = suggestedGasPrice > baseFee
                ? suggestedGasPrice - baseFee
                : BigInt.from(_evmDefaultPriorityFeeWei);
          }
          if (priorityFee <= BigInt.zero) {
            priorityFee = BigInt.from(_evmDefaultPriorityFeeWei);
          }
          return _EvmFeeParameters.eip1559(
            maxPriorityFeePerGas: priorityFee,
            maxFeePerGas: baseFee * BigInt.two + priorityFee,
          );
        }
      }
    } catch (_) {
      // 不支持 EIP-1559 的节点或网络继续走 legacy gasPrice。
    }
    return _EvmFeeParameters.legacy(
      await _evmRpcBigInt(chain, 'eth_gasPrice', const []),
    );
  }

  BigInt _applyEvmGasSafetyLimit(BigInt estimatedGasLimit) {
    if (estimatedGasLimit <= BigInt.zero) {
      throw StateError('Invalid EVM gas estimate');
    }
    final numerator = BigInt.from(_evmGasLimitSafetyNumerator);
    final denominator = BigInt.from(_evmGasLimitSafetyDenominator);
    final buffered =
        (estimatedGasLimit * numerator + denominator - BigInt.one) ~/
        denominator;
    if (buffered > BigInt.from(_evmMaximumGasLimit)) {
      throw StateError('EVM gas estimate exceeds safety limit');
    }
    return buffered;
  }

  void _validateEvmDraft({
    required EvmTransactionDraft draft,
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) {
    final chainId = asset.chainRef.evmChainId;
    final recipient = WalletTransferService.normalizeEvmAddress(toAddress);
    final rawAmount = WalletTransferService.amountToRawUnits(
      amount,
      asset.decimals,
    );
    final expectedTo = asset.isNative
        ? recipient
        : WalletTransferService.normalizeEvmAddress(asset.contractAddress!);
    final expectedValue = asset.isNative ? rawAmount : BigInt.zero;
    final expectedData = asset.isNative
        ? '0x'
        : WalletTransferService.erc20TransferData(recipient, rawAmount);
    if (draft.chainId != chainId ||
        draft.from !=
            WalletTransferService.normalizeEvmAddress(asset.address) ||
        draft.to != expectedTo ||
        draft.value != expectedValue ||
        draft.data.toLowerCase() != expectedData.toLowerCase()) {
      throw StateError('EVM transaction draft does not match transfer');
    }
    if (draft.nonce < BigInt.zero ||
        draft.gasLimit <= BigInt.zero ||
        draft.gasLimit > BigInt.from(_evmMaximumGasLimit) ||
        draft.feePerGas <= BigInt.zero ||
        draft.l1DataFee < BigInt.zero) {
      throw StateError('Invalid EVM transaction draft parameters');
    }
  }

  Future<void> _simulateEvmTransaction(
    WalletChainRef chain,
    EvmTransactionDraft draft,
  ) async {
    await _evmRpc(chain, 'eth_call', [
      {
        'from': draft.from,
        'to': draft.to,
        'value': WalletTransferService._hexQuantity(draft.value),
        if (draft.data != '0x') 'data': draft.data,
        'gas': WalletTransferService._hexQuantity(draft.gasLimit),
        if (draft.feeType == EvmFeeType.legacy)
          'gasPrice': WalletTransferService._hexQuantity(draft.gasPrice!),
        if (draft.feeType == EvmFeeType.eip1559) ...{
          'maxFeePerGas': WalletTransferService._hexQuantity(
            draft.maxFeePerGas!,
          ),
          'maxPriorityFeePerGas': WalletTransferService._hexQuantity(
            draft.maxPriorityFeePerGas!,
          ),
        },
      },
      'pending',
    ]);
  }

  /// 发送 TRON 链交易。
  ///
  /// 先通过节点创建未签名交易，再对 `raw_data_hex` 做 SHA-256 后 secp256k1 签名，
  /// 最后调用 `broadcasttransaction` 广播。
  Future<dynamic> _evmRpc(
    WalletChainRef chain,
    String method,
    List<dynamic> params,
  ) async {
    final data = await RpcRetryHelper.execute<Map<dynamic, dynamic>>(
      rpcUrls: _evmRpcUrls(chain),
      chainName: chain.name,
      operation: method,
      logName: 'WalletTransferService',
      request: (rpcUrl) async {
        final response = await _dio.post(
          rpcUrl,
          data: {'jsonrpc': '2.0', 'method': method, 'params': params, 'id': 1},
          options: Options(headers: {'content-type': 'application/json'}),
        );
        final responseData = response.data;
        if (responseData is Map) {
          return responseData;
        }
        throw StateError('Invalid ${chain.name} RPC response');
      },
      validator: (responseData) => responseData['result'] != null,
      invalidResponseError: (_, responseData) {
        if (responseData['error'] != null) {
          return StateError(
            '${chain.name} RPC error: ${responseData['error']}',
          );
        }
        return StateError('Invalid ${chain.name} RPC response');
      },
    );
    if (data['result'] != null) {
      return data['result'];
    }
    throw StateError(data.toString());
  }

  List<String> _evmRpcUrls(WalletChainRef chain) {
    final configuredUrls = chain is WalletChainConfig
        ? chain.rpcUrls
        : [chain.rpcUrl];
    if (_isBaseMainnet(chain)) {
      return RpcRetryHelper.mergeRpcUrls(configuredUrls, _baseEvmRpcFallbacks);
    }
    if (chain.evmChainId == WalletChain.polygon.evmChainId) {
      return RpcRetryHelper.mergeRpcUrls(
        configuredUrls,
        _polygonEvmRpcFallbacks,
      );
    }
    if (chain.evmChainId == WalletChain.avalanche.evmChainId) {
      return RpcRetryHelper.mergeRpcUrls(
        configuredUrls,
        _avalancheEvmRpcFallbacks,
      );
    }
    return configuredUrls;
  }

  bool _isBaseMainnet(WalletChainRef chain) {
    return chain.evmChainId == _baseMainnetChainId;
  }

  Future<BigInt> _estimateBaseL1FeeUpperBound({
    required WalletChainRef chain,
    required BigInt gasPrice,
    required BigInt gasLimit,
    required String toAddress,
    required BigInt value,
    required String data,
  }) {
    final chainId = chain.evmChainId;
    if (chainId == null) {
      throw StateError('${chain.name} is not an EVM chain');
    }
    final transactionUpperBound = WalletTransferService._rlpEncode([
      _maxEvmUint256,
      gasPrice,
      gasLimit,
      WalletTransferService.hexToBytes(
        WalletTransferService.normalizeBscAddress(toAddress),
      ),
      value,
      WalletTransferService.hexToBytes(data),
      BigInt.from(38 + chainId * 2),
      _maxEvmUint256,
      _maxEvmUint256,
    ]);
    final encodedSize = transactionUpperBound.length
        .toRadixString(16)
        .padLeft(64, '0');
    return _evmRpcBigInt(chain, 'eth_call', [
      {
        'to': _baseGasPriceOracleAddress,
        'data': '0x$_baseGetL1FeeUpperBoundSelector$encodedSize',
      },
      'latest',
    ]);
  }

  /// 发送 EVM JSON-RPC 请求并把十六进制数量解析成 [BigInt]。
  Future<BigInt> _evmRpcBigInt(
    WalletChainRef chain,
    String method,
    List<dynamic> params,
  ) async {
    final result = await _evmRpc(chain, method, params);
    if (result is! String) {
      throw StateError('Invalid ${chain.name} number response');
    }
    return _parseEvmQuantity(result);
  }

  BigInt _parseEvmQuantity(String value) {
    final normalized = value.toLowerCase().replaceFirst('0x', '');
    if (normalized.isEmpty) {
      throw const FormatException('Empty EVM quantity');
    }
    return BigInt.parse(normalized, radix: 16);
  }

  /// 使用交易草稿中的原始费用类型签名 EVM 交易。
  String _signEvmTransaction({
    required String privateKeyHex,
    required EvmTransactionDraft draft,
  }) {
    final toBytes = WalletTransferService.hexToBytes(
      WalletTransferService.normalizeBscAddress(draft.to),
    );
    final data = WalletTransferService.hexToBytes(draft.data);
    if (draft.feeType == EvmFeeType.eip1559) {
      return _signEip1559Transaction(
        privateKeyHex: privateKeyHex,
        draft: draft,
        toBytes: toBytes,
        data: data,
      );
    }
    final signingPayload = WalletTransferService._rlpEncode([
      draft.nonce,
      draft.gasPrice!,
      draft.gasLimit,
      toBytes,
      draft.value,
      data,
      BigInt.from(draft.chainId),
      BigInt.zero,
      BigInt.zero,
    ]);
    final hash = WalletTransferService._keccak(signingPayload);
    final signature = _signHash(privateKeyHex, hash);
    final recoveryId = _findRecoveryId(privateKeyHex, hash, signature);
    final v = BigInt.from(recoveryId + 35 + draft.chainId * 2);
    final rawPayload = WalletTransferService._rlpEncode([
      draft.nonce,
      draft.gasPrice!,
      draft.gasLimit,
      toBytes,
      draft.value,
      data,
      v,
      signature.r,
      signature.s,
    ]);
    return hex.encode(rawPayload);
  }

  String _signEip1559Transaction({
    required String privateKeyHex,
    required EvmTransactionDraft draft,
    required Uint8List toBytes,
    required Uint8List data,
  }) {
    final unsignedFields = [
      BigInt.from(draft.chainId),
      draft.nonce,
      draft.maxPriorityFeePerGas!,
      draft.maxFeePerGas!,
      draft.gasLimit,
      toBytes,
      draft.value,
      data,
      const <Object>[],
    ];
    final encodedUnsigned = WalletTransferService._rlpEncode(unsignedFields);
    final signingPayload = Uint8List.fromList([0x02, ...encodedUnsigned]);
    final hash = WalletTransferService._keccak(signingPayload);
    final signature = _signHash(privateKeyHex, hash);
    final recoveryId = _findRecoveryId(privateKeyHex, hash, signature);
    if (recoveryId > 1) {
      throw StateError('Unsupported EIP-1559 recovery id');
    }
    final signedFields = [
      ...unsignedFields,
      BigInt.from(recoveryId),
      signature.r,
      signature.s,
    ];
    final encodedSigned = WalletTransferService._rlpEncode(signedFields);
    return hex.encode([0x02, ...encodedSigned]);
  }

  /// 签名 TRON 未签名交易。
  ///
  /// TRON 使用 `sha256(raw_data_hex)` 作为签名哈希，签名结果需要拼接 recoveryId，
  /// 并放入 transaction 的 `signature` 数组。
}

class _EvmFeeParameters {
  const _EvmFeeParameters._({
    required this.feeType,
    this.gasPrice,
    this.maxFeePerGas,
    this.maxPriorityFeePerGas,
  });

  factory _EvmFeeParameters.legacy(BigInt gasPrice) =>
      _EvmFeeParameters._(feeType: EvmFeeType.legacy, gasPrice: gasPrice);

  factory _EvmFeeParameters.eip1559({
    required BigInt maxFeePerGas,
    required BigInt maxPriorityFeePerGas,
  }) => _EvmFeeParameters._(
    feeType: EvmFeeType.eip1559,
    maxFeePerGas: maxFeePerGas,
    maxPriorityFeePerGas: maxPriorityFeePerGas,
  );

  final EvmFeeType feeType;
  final BigInt? gasPrice;
  final BigInt? maxFeePerGas;
  final BigInt? maxPriorityFeePerGas;

  BigInt get feePerGas => switch (feeType) {
    EvmFeeType.legacy => gasPrice!,
    EvmFeeType.eip1559 => maxFeePerGas!,
  };
}
