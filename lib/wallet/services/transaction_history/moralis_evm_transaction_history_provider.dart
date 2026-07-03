part of '../wallet_transaction_history_service.dart';

class _MoralisEvmTransactionHistoryProvider
    with _TransactionHistoryProviderHelpers {
  _MoralisEvmTransactionHistoryProvider({
    required this.dio,
    required this.apiConfig,
  });

  @override
  final Dio dio;

  @override
  final WalletHistoryApiConfig apiConfig;

  static const int _historyLimit = _transactionHistoryPageSize;
  static const Map<String, String> _supportedChains = {
    'bsc': 'bsc',
    'arbitrum': 'arbitrum',
  };

  bool supportsChain(WalletChainRef chain) {
    return _supportedChains.containsKey(chain.id);
  }

  Future<TransactionHistoryPageResult> loadRecordPage({
    required String walletId,
    required ChainBalance asset,
    TransactionHistoryCursor? cursor,
  }) async {
    final moralisChain = _supportedChains[asset.chainRef.id];
    if (moralisChain == null) {
      throw _historyLoadException(
        '${asset.chainRef.name} is not supported by Moralis',
        null,
      );
    }
    if (!apiConfig.hasMoralisApiKey) {
      throw const TransactionHistoryLoadException(
        TransactionHistoryFailureKind.apiKeyMissing,
        'Moralis API key is missing',
      );
    }
    final moralisCursor = cursor?.moralisCursor;
    final baseUrl = apiConfig.moralisBaseUrl.trim().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    final path = asset.isNative
        ? Uri.encodeComponent(asset.address)
        : '${Uri.encodeComponent(asset.address)}/erc20/transfers';
    final queryParameters = <String, dynamic>{
      'chain': moralisChain,
      'limit': _historyLimit,
      'order': 'DESC',
      if (moralisCursor != null && moralisCursor.isNotEmpty)
        'cursor': moralisCursor,
      if (!asset.isNative &&
          (asset.contractAddress?.trim().isNotEmpty ?? false))
        'contract_addresses': [asset.contractAddress!.trim()],
    };

    final Response<dynamic> response;
    try {
      response = await dio.get(
        '$baseUrl/$path',
        queryParameters: queryParameters,
        options: Options(
          headers: {'X-API-Key': apiConfig.moralisApiKey.trim()},
        ),
      );
    } catch (error) {
      throw _historyLoadException('Moralis EVM history request failed', error);
    }
    final data = response.data;
    if (data is! Map) {
      throw _historyLoadException('Invalid Moralis EVM history response', data);
    }

    final result = data['result'];
    if (result is! List) {
      final message =
          data['message']?.toString() ??
          data['error']?.toString() ??
          'Invalid Moralis EVM history result';
      throw _historyLoadException(message, message);
    }

    final records = <WalletTransactionRecord>[];
    final seenIds = <String>{};
    for (final item in result.whereType<Map>()) {
      final record = asset.isNative
          ? _nativeRecordFromMoralis(
              walletId: walletId,
              asset: asset,
              item: item,
            )
          : _tokenRecordFromMoralis(
              walletId: walletId,
              asset: asset,
              item: item,
            );
      if (record != null && seenIds.add(record.id)) {
        records.add(record);
      }
    }
    records.sort(_compareRecordTimeDesc);

    final nextCursor = data['cursor']?.toString() ?? '';
    return TransactionHistoryPageResult(
      records: records.take(_historyLimit).toList(growable: false),
      nextCursor: nextCursor.isNotEmpty
          ? TransactionHistoryCursor.moralisCursor(nextCursor)
          : null,
      emptyReason: records.isEmpty
          ? TransactionHistoryFailureKind.noRecords
          : null,
    );
  }

  WalletTransactionRecord? _nativeRecordFromMoralis({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> item,
  }) {
    final txHash = item['hash']?.toString() ?? '';
    if (txHash.isEmpty) return null;

    final from = _normalizeEvmDisplayAddress(
      item['from_address']?.toString() ?? '',
    );
    final to = _normalizeEvmDisplayAddress(
      item['to_address']?.toString() ?? '',
    );
    final rawValue = _bigIntFromObject(item['value']);
    final gasUsed = _bigIntFromObject(item['receipt_gas_used']);
    final gasPrice = _bigIntFromObject(item['gas_price']);
    final transactionFee = _normalizeDecimalString(
      item['transaction_fee']?.toString() ?? '',
    );

    return WalletTransactionRecord(
      id: _recordId(walletId, asset, txHash),
      walletId: walletId,
      chainId: asset.chainId,
      chainName: asset.chainRef.name,
      symbol: asset.symbol,
      assetName: asset.name,
      walletAddress: asset.address,
      txHash: txHash,
      fromAddress: from,
      toAddress: to,
      amount: WalletTransferService.rawUnitsToAmount(rawValue, asset.decimals),
      decimals: asset.decimals,
      direction: _directionForAddress(
        walletAddress: asset.address,
        fromAddress: from,
        toAddress: to,
        normalize: _normalizeEvmCompareAddress,
      ),
      status: _statusFromMoralis(item['receipt_status']),
      source: WalletTransactionSource.remote,
      feeAmount: transactionFee != '0' && transactionFee.isNotEmpty
          ? transactionFee
          : gasUsed > BigInt.zero && gasPrice > BigInt.zero
          ? WalletTransferService.rawUnitsToAmount(gasUsed * gasPrice, 18)
          : null,
      feeSymbol: asset.chainRef.symbol,
      blockNumber: _intFromObject(item['block_number']),
      timestamp: _dateTimeFromIso(item['block_timestamp']),
    );
  }

  WalletTransactionRecord? _tokenRecordFromMoralis({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> item,
  }) {
    final txHash = item['transaction_hash']?.toString() ?? '';
    if (txHash.isEmpty) return null;
    final contractAddress = item['address']?.toString() ?? '';
    if (!_sameEvmAddress(contractAddress, asset.contractAddress ?? '')) {
      return null;
    }

    final decimals =
        int.tryParse(item['token_decimals']?.toString() ?? '') ??
        asset.decimals;
    final rawValue = _bigIntFromObject(item['value']);
    final from = _normalizeEvmDisplayAddress(
      item['from_address']?.toString() ?? '',
    );
    final to = _normalizeEvmDisplayAddress(
      item['to_address']?.toString() ?? '',
    );
    final blockNumber = _intFromObject(item['block_number']);
    final logIndex = item['log_index']?.toString() ?? '';

    return WalletTransactionRecord(
      id: _recordId(walletId, asset, '$txHash:$blockNumber:$logIndex'),
      walletId: walletId,
      chainId: asset.chainId,
      chainName: asset.chainRef.name,
      symbol: asset.symbol,
      assetName: asset.name,
      walletAddress: asset.address,
      txHash: txHash,
      fromAddress: from,
      toAddress: to,
      amount: WalletTransferService.rawUnitsToAmount(rawValue, decimals),
      decimals: decimals,
      direction: _directionForAddress(
        walletAddress: asset.address,
        fromAddress: from,
        toAddress: to,
        normalize: _normalizeEvmCompareAddress,
      ),
      status: WalletTransactionStatus.success,
      source: WalletTransactionSource.remote,
      contractAddress: asset.contractAddress,
      feeSymbol: asset.chainRef.symbol,
      blockNumber: blockNumber,
      timestamp: _dateTimeFromIso(item['block_timestamp']),
    );
  }

  WalletTransactionStatus _statusFromMoralis(Object? value) {
    final text = value?.toString().toLowerCase() ?? '';
    if (text == '1' || text == 'success' || text == 'true') {
      return WalletTransactionStatus.success;
    }
    if (text == '0' || text == 'failed' || text == 'false') {
      return WalletTransactionStatus.failed;
    }
    return WalletTransactionStatus.unknown;
  }

  bool _sameEvmAddress(String left, String right) {
    final normalizedLeft = _normalizeEvmCompareAddress(left);
    final normalizedRight = _normalizeEvmCompareAddress(right);
    return normalizedLeft.isNotEmpty && normalizedLeft == normalizedRight;
  }

  BigInt _bigIntFromObject(Object? value) {
    if (value == null) return BigInt.zero;
    if (value is BigInt) return value;
    if (value is int) return BigInt.from(value);
    final text = value.toString();
    if (text.contains('.')) {
      return BigInt.tryParse(text.split('.').first) ?? BigInt.zero;
    }
    return BigInt.tryParse(text) ?? BigInt.zero;
  }
}
