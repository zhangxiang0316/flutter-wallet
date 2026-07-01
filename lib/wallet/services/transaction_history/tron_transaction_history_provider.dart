part of '../wallet_transaction_history_service.dart';

class _TronTransactionHistoryProvider with _TransactionHistoryProviderHelpers {
  _TronTransactionHistoryProvider({required this.dio, required this.apiConfig});

  @override
  final Dio dio;

  @override
  final WalletHistoryApiConfig apiConfig;

  static const int _historyLimit = _transactionHistoryPageSize;

  static const List<String> _tronApiFallbacks = [
    'https://api.trongrid.io',
    'https://tron-rpc.publicnode.com',
  ];

  Future<TransactionHistoryPageResult> loadRecordPage({
    required String walletId,
    required ChainBalance asset,
    TransactionHistoryCursor? cursor,
  }) async {
    Object? lastError;
    for (final apiUrl in _tronApiUrls(asset.chainRef)) {
      try {
        final response = await dio.get(
          asset.isNative
              ? '$apiUrl/v1/accounts/${asset.address}/transactions'
              : '$apiUrl/v1/accounts/${asset.address}/transactions/trc20',
          options: _tronGridOptions(apiUrl),
          queryParameters: {
            'limit': _historyLimit,
            'only_confirmed': true,
            'order_by': 'block_timestamp,desc',
            if (cursor?.tronFingerprint?.isNotEmpty ?? false)
              'fingerprint': cursor!.tronFingerprint,
            if (!asset.isNative) 'contract_address': asset.contractAddress,
          },
        );
        final data = response.data;
        final values = data is Map ? data['data'] : null;
        if (values is! List) {
          throw StateError('Invalid TRON history response');
        }
        final records = values
            .whereType<Map>()
            .map(
              (item) => asset.isNative
                  ? _tronNativeRecord(
                      walletId: walletId,
                      asset: asset,
                      item: item,
                    )
                  : _tronTokenRecord(
                      walletId: walletId,
                      asset: asset,
                      item: item,
                    ),
            )
            .whereType<WalletTransactionRecord>()
            .take(_historyLimit)
            .toList(growable: false);
        records.sort(_compareRecordTimeDesc);
        final meta = data is Map ? data['meta'] : null;
        final nextFingerprint = meta is Map
            ? meta['fingerprint']?.toString()
            : null;
        return TransactionHistoryPageResult(
          records: records,
          nextCursor:
              nextFingerprint != null &&
                  nextFingerprint.isNotEmpty &&
                  records.length >= _historyLimit
              ? TransactionHistoryCursor.tronFingerprint(nextFingerprint)
              : null,
        );
      } catch (error) {
        lastError = error;
        developer.log(
          'TRON history request failed at $apiUrl: $error',
          name: 'WalletTransactionHistoryService',
        );
      }
    }
    throw StateError('TRON history failed: ${lastError ?? 'unknown error'}');
  }

  Options? _tronGridOptions(String apiUrl) {
    if (!apiConfig.hasTronGridApiKey) return null;
    final uri = Uri.tryParse(apiUrl);
    if (uri == null || !uri.host.toLowerCase().contains('trongrid')) {
      return null;
    }
    return Options(
      headers: {'TRON-PRO-API-KEY': apiConfig.tronGridApiKey.trim()},
    );
  }

  WalletTransactionRecord? _tronNativeRecord({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> item,
  }) {
    final txHash = item['txID']?.toString() ?? item['tx_id']?.toString() ?? '';
    if (txHash.isEmpty) return null;

    final contract = _firstTronContractValue(item);
    final from = _normalizeTronDisplayAddress(
      contract['owner_address']?.toString() ??
          item['owner_address']?.toString() ??
          item['from']?.toString() ??
          '',
    );
    final to = _normalizeTronDisplayAddress(
      contract['to_address']?.toString() ??
          item['to_address']?.toString() ??
          item['to']?.toString() ??
          '',
    );
    final rawValue =
        BigInt.tryParse(
          contract['amount']?.toString() ?? item['amount']?.toString() ?? '',
        ) ??
        BigInt.zero;
    final feeSun =
        BigInt.tryParse(item['fee']?.toString() ?? '') ??
        BigInt.tryParse(_nestedValue(item, ['cost', 'net_fee']) ?? '') ??
        BigInt.zero;

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
        normalize: _normalizeTronCompareAddress,
      ),
      status: _tronStatus(item),
      source: WalletTransactionSource.remote,
      feeAmount: feeSun > BigInt.zero
          ? WalletTransferService.rawUnitsToAmount(feeSun, 6)
          : null,
      feeSymbol: asset.chainRef.symbol,
      blockNumber: int.tryParse(item['blockNumber']?.toString() ?? ''),
      timestamp: _dateTimeFromMilliseconds(item['block_timestamp']),
    );
  }

  WalletTransactionRecord? _tronTokenRecord({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> item,
  }) {
    final txHash =
        item['transaction_id']?.toString() ?? item['txID']?.toString() ?? '';
    if (txHash.isEmpty) return null;

    final tokenInfo = item['token_info'];
    final decimals = tokenInfo is Map
        ? int.tryParse(tokenInfo['decimals']?.toString() ?? '') ??
              asset.decimals
        : asset.decimals;
    final rawValue =
        BigInt.tryParse(item['value']?.toString() ?? '') ?? BigInt.zero;
    final from = _normalizeTronDisplayAddress(item['from']?.toString() ?? '');
    final to = _normalizeTronDisplayAddress(item['to']?.toString() ?? '');

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
      amount: WalletTransferService.rawUnitsToAmount(rawValue, decimals),
      decimals: decimals,
      direction: _directionForAddress(
        walletAddress: asset.address,
        fromAddress: from,
        toAddress: to,
        normalize: _normalizeTronCompareAddress,
      ),
      status: WalletTransactionStatus.success,
      source: WalletTransactionSource.remote,
      contractAddress: asset.contractAddress,
      timestamp: _dateTimeFromMilliseconds(item['block_timestamp']),
    );
  }

  WalletTransactionStatus _tronStatus(Map<dynamic, dynamic> item) {
    final ret = item['ret'];
    if (ret is List && ret.isNotEmpty && ret.first is Map) {
      final contractRet = (ret.first as Map)['contractRet']?.toString();
      if (contractRet == 'SUCCESS') return WalletTransactionStatus.success;
      if (contractRet != null && contractRet.isNotEmpty) {
        return WalletTransactionStatus.failed;
      }
    }
    return WalletTransactionStatus.success;
  }

  List<String> _tronApiUrls(WalletChainRef chain) {
    if (chain is WalletChainConfig) {
      return _mergeUrls(chain.rpcUrls, _tronApiFallbacks);
    }
    return _mergeUrls([chain.rpcUrl], _tronApiFallbacks);
  }
}
