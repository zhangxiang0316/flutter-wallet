import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:dio/dio.dart';
import 'package:pointycastle/digests/sha256.dart';

import '../constants/crypto_constants.dart';
import '../models/chain_balance.dart';
import '../models/wallet_chain.dart';
import '../models/wallet_transaction_record.dart';
import 'wallet_history_api_config.dart';
import 'wallet_transfer_service.dart';

/// 交易历史分页游标。
class TransactionHistoryCursor {
  const TransactionHistoryCursor._(this.source, this.value);

  const TransactionHistoryCursor.evmExplorerPage(int page)
    : this._('evmExplorerPage', page);

  const TransactionHistoryCursor.blockscoutPage(String value)
    : this._('blockscoutPage', value);

  const TransactionHistoryCursor.tronFingerprint(String value)
    : this._('tronFingerprint', value);

  const TransactionHistoryCursor.solanaBefore(String value)
    : this._('solanaBefore', value);

  /// 游标来源。
  final String source;

  /// 来源特定的下一页参数。
  final Object value;

  int? get evmPage => source == 'evmExplorerPage' ? value as int : null;

  String? get blockscoutParams =>
      source == 'blockscoutPage' ? value as String : null;

  String? get tronFingerprint =>
      source == 'tronFingerprint' ? value as String : null;

  String? get solanaBefore => source == 'solanaBefore' ? value as String : null;
}

/// 交易历史分页结果。
class TransactionHistoryPageResult {
  const TransactionHistoryPageResult({
    required this.records,
    required this.nextCursor,
  });

  /// 当前页交易记录。
  final List<WalletTransactionRecord> records;

  /// 下一页游标；为 null 表示当前数据源没有更多可取记录。
  final TransactionHistoryCursor? nextCursor;

  bool get hasMore => nextCursor != null;
}

/// 钱包链上交易记录服务。
///
/// 交易记录不再写入或读取本地缓存。页面每次进入或刷新时，都会根据当前资产类型
/// 直接请求链上 RPC 或区块浏览器 API，并把不同链的返回格式归一化成
/// [WalletTransactionRecord]。
class WalletTransactionHistoryService {
  WalletTransactionHistoryService({Dio? dio, WalletHistoryApiConfig? apiConfig})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: _requestTimeout,
              receiveTimeout: _requestTimeout,
              sendTimeout: _requestTimeout,
            ),
          ),
      _apiConfig = apiConfig ?? const WalletHistoryApiConfig();

  /// HTTP/RPC 请求客户端。
  final Dio _dio;

  final WalletHistoryApiConfig _apiConfig;

  static const Duration _requestTimeout = Duration(seconds: 6);
  static const int _historyLimit = 30;
  static const int _evmLogChunkSize = 50000;
  static const int _evmLogScanBlockWindow = 5000000;
  static const int _arbitrumLogScanBlockWindow = 200000;
  static const int _blockscoutMaxPages = 4;
  static const Duration _limitedLogFallbackTimeout = Duration(seconds: 4);

  /// 使用共享的 EVM Transfer 事件 topic
  static const String _evmTransferEventTopic =
      CryptoConstants.evmTransferEventTopic;

  /// 内置 EVM 链的 Etherscan 兼容接口。
  ///
  /// 自定义 EVM 链暂没有浏览器 API 配置入口；非原生 token 会再尝试 RPC logs 兜底。
  ///
  /// Arbitrum 已移除：Arbiscan V1 已弃用，V2 需要 API Key，Blockscout 太慢（>10秒）。
  /// Token 交易会直接使用 RPC logs 查询（更快），原生 ETH 返回空（大部分用户不用）。
  static const Map<String, String> _evmExplorerApiUrls = {
    'bsc': 'https://api.bscscan.com/api',
    'ethereum': 'https://api.etherscan.io/api',
    // Arbitrum: 浏览器 API 太慢或需要 Key，直接使用 RPC logs
  };

  /// Etherscan V2 统一多链接口。
  static const String _etherscanV2ApiUrl = 'https://api.etherscan.io/v2/api';

  /// 无需 API Key 的 Blockscout v2 地址交易接口。
  ///
  /// Etherscan 系列接口已逐步切到 v2 且很多链需要 API Key。这里把已验证可用的
  /// Blockscout 作为内置兜底，避免默认配置下 ETH 一直返回空记录。
  ///
  /// Arbitrum 已移除：两个节点都超时（>6秒），用户体验差。
  static const Map<String, List<String>> _evmBlockscoutBaseUrls = {
    'ethereum': ['https://eth.blockscout.com'],
    // Arbitrum: Blockscout 节点响应太慢，直接使用 RPC logs
  };

  /// EVM 链 RPC 备用节点，用于 token logs 兜底。
  static const Map<String, List<String>> _evmRpcFallbacks = {
    'bsc': [
      'https://bsc-dataseed.bnbchain.org',
      'https://bsc-rpc.publicnode.com',
    ],
    'ethereum': [
      'https://ethereum-rpc.publicnode.com',
      'https://eth.llamarpc.com',
    ],
    'x-layer': ['https://rpc.xlayer.tech', 'https://xlayerrpc.okx.com'],
    'arbitrum': [
      'https://arb1.arbitrum.io/rpc',
      'https://arbitrum-one-rpc.publicnode.com',
    ],
  };

  static const List<String> _tronApiFallbacks = [
    'https://api.trongrid.io',
    'https://tron-rpc.publicnode.com',
  ];

  static const List<String> _solanaRpcFallbacks = [
    'https://api.mainnet-beta.solana.com',
    'https://solana-rpc.publicnode.com',
  ];

  /// 读取某个钱包、某条链、某个币种的链上交易记录。
  ///
  /// [walletId] 仅用于生成页面内稳定的记录 ID，不再用于本地存储隔离。
  Future<List<WalletTransactionRecord>> loadAssetRecords({
    required String walletId,
    required ChainBalance asset,
  }) async {
    final result = await loadAssetRecordPage(walletId: walletId, asset: asset);
    return result.records;
  }

  /// 分页读取某个资产的链上交易记录。
  Future<TransactionHistoryPageResult> loadAssetRecordPage({
    required String walletId,
    required ChainBalance asset,
    TransactionHistoryCursor? cursor,
  }) async {
    final chain = asset.chainRef;
    if (chain.isEvm) {
      return _loadEvmRecordPage(
        walletId: walletId,
        asset: asset,
        cursor: cursor,
      );
    }
    if (_isTronChain(chain)) {
      return _loadTronRecordPage(
        walletId: walletId,
        asset: asset,
        cursor: cursor,
      );
    }
    if (_isSolanaChain(chain)) {
      return _loadSolanaRecordPage(
        walletId: walletId,
        asset: asset,
        cursor: cursor,
      );
    }
    return const TransactionHistoryPageResult(records: [], nextCursor: null);
  }

  Future<TransactionHistoryPageResult> _loadEvmRecordPage({
    required String walletId,
    required ChainBalance asset,
    TransactionHistoryCursor? cursor,
  }) async {
    Object? lastExplorerError;
    var hasSuccessfulExplorer = false;
    final isLoadMore = cursor != null;

    for (final provider in _evmHistoryProviders(asset.chainRef)) {
      if (cursor?.evmPage != null &&
          provider.type != _EvmHistoryProviderType.etherscanCompatible) {
        continue;
      }
      if (cursor?.blockscoutParams != null &&
          provider.type != _EvmHistoryProviderType.blockscoutV2) {
        continue;
      }
      try {
        final result = switch (provider.type) {
          _EvmHistoryProviderType.etherscanCompatible =>
            await _loadEvmExplorerRecordPage(
              apiUrl: provider.url,
              apiKey: provider.apiKey,
              walletId: walletId,
              asset: asset,
              page: cursor?.evmPage ?? 1,
            ),
          _EvmHistoryProviderType.blockscoutV2 =>
            await _loadBlockscoutRecordPage(
              baseUrl: provider.url,
              walletId: walletId,
              asset: asset,
              cursor: cursor?.blockscoutParams,
            ),
        };
        hasSuccessfulExplorer = true;
        if (result.records.isNotEmpty) {
          return result;
        }
        if (asset.isNative) return result;
      } catch (error) {
        lastExplorerError = error;
        developer.log(
          '${asset.chainRef.name} explorer history failed at '
          '${provider.url}: $error',
          name: 'WalletTransactionHistoryService',
        );
      }
    }

    if (asset.isNative) {
      if (isLoadMore) {
        return const TransactionHistoryPageResult(
          records: [],
          nextCursor: null,
        );
      }
      throw StateError(
        '${asset.chainRef.name} native history failed: '
        '${lastExplorerError ?? 'no explorer provider'}',
      );
    }

    try {
      if (isLoadMore) {
        return const TransactionHistoryPageResult(
          records: [],
          nextCursor: null,
        );
      }
      final records = await _loadEvmTokenLogs(walletId: walletId, asset: asset)
          .timeout(
            _limitedLogFallbackTimeout,
            onTimeout: () {
              developer.log(
                '${asset.chainRef.name} token log fallback timed out',
                name: 'WalletTransactionHistoryService',
              );
              return const <WalletTransactionRecord>[];
            },
          );
      return TransactionHistoryPageResult(records: records, nextCursor: null);
    } catch (error) {
      if (hasSuccessfulExplorer) {
        return const TransactionHistoryPageResult(
          records: [],
          nextCursor: null,
        );
      }
      rethrow;
    }
  }

  Future<TransactionHistoryPageResult> _loadEvmExplorerRecordPage({
    required String apiUrl,
    String? apiKey,
    required String walletId,
    required ChainBalance asset,
    required int page,
  }) async {
    final normalizedApiKey = apiKey?.trim() ?? '';
    final response = await _dio.get(
      apiUrl,
      queryParameters: {
        'module': 'account',
        'action': asset.isNative ? 'txlist' : 'tokentx',
        'address': asset.address,
        if (!asset.isNative) 'contractaddress': asset.contractAddress,
        'page': page,
        'offset': _historyLimit,
        'sort': 'desc',
        if (_isEtherscanV2Api(apiUrl) && asset.chainRef.evmChainId != null)
          'chainid': asset.chainRef.evmChainId,
        if (normalizedApiKey.isNotEmpty) 'apikey': normalizedApiKey,
      },
    );
    final data = response.data;
    if (data is! Map) {
      throw StateError('Invalid ${asset.chainRef.name} explorer response');
    }

    final result = data['result'];
    if (result is List) {
      final records = result
          .whereType<Map>()
          .map(
            (item) => asset.isNative
                ? _evmNativeRecordFromExplorer(
                    walletId: walletId,
                    asset: asset,
                    item: item,
                  )
                : _evmTokenRecordFromExplorer(
                    walletId: walletId,
                    asset: asset,
                    item: item,
                  ),
          )
          .whereType<WalletTransactionRecord>()
          .take(_historyLimit)
          .toList(growable: false);
      return TransactionHistoryPageResult(
        records: records,
        nextCursor: records.length >= _historyLimit
            ? TransactionHistoryCursor.evmExplorerPage(page + 1)
            : null,
      );
    }

    final message = data['message']?.toString().toLowerCase() ?? '';
    final resultText = result?.toString().toLowerCase() ?? '';
    if (message.contains('no transactions') ||
        resultText.contains('no transactions')) {
      return const TransactionHistoryPageResult(records: [], nextCursor: null);
    }
    throw StateError(
      data['result']?.toString() ??
          data['message']?.toString() ??
          'Explorer request failed',
    );
  }

  Future<TransactionHistoryPageResult> _loadBlockscoutRecordPage({
    required String baseUrl,
    required String walletId,
    required ChainBalance asset,
    String? cursor,
  }) async {
    final apiBase = _blockscoutApiBase(baseUrl);
    final path = asset.isNative ? 'transactions' : 'token-transfers';
    var queryParameters =
        _decodeBlockscoutCursor(cursor) ??
        (asset.isNative
            ? <String, dynamic>{}
            : <String, dynamic>{'type': 'ERC-20'});
    if (!asset.isNative) {
      queryParameters['type'] = 'ERC-20';
    }
    final records = <WalletTransactionRecord>[];
    final seenIds = <String>{};
    TransactionHistoryCursor? nextCursor;

    for (var page = 0; page < _blockscoutMaxPages; page++) {
      final requestQueryParameters = queryParameters;
      final response = await _dio.get(
        '$apiBase/addresses/${Uri.encodeComponent(asset.address)}/$path',
        queryParameters: requestQueryParameters.isEmpty
            ? null
            : requestQueryParameters,
      );
      final data = response.data;
      if (data is! Map) {
        throw StateError('Invalid ${asset.chainRef.name} Blockscout response');
      }

      final items = data['items'];
      if (items is! List) {
        throw StateError('Invalid ${asset.chainRef.name} Blockscout items');
      }
      for (final item in items.whereType<Map>()) {
        final record = asset.isNative
            ? _evmNativeRecordFromBlockscout(
                walletId: walletId,
                asset: asset,
                item: item,
              )
            : _evmTokenRecordFromBlockscout(
                walletId: walletId,
                asset: asset,
                item: item,
              );
        if (record != null && seenIds.add(record.id)) {
          records.add(record);
        }
      }
      records.sort(_compareRecordTimeDesc);
      if (records.length >= _historyLimit) {
        break;
      }

      final nextPageParams = data['next_page_params'];
      if (nextPageParams is! Map || nextPageParams.isEmpty) {
        break;
      }
      queryParameters = {
        for (final entry in nextPageParams.entries)
          entry.key.toString(): entry.value,
        if (!asset.isNative) 'type': 'ERC-20',
      };
      nextCursor = TransactionHistoryCursor.blockscoutPage(
        jsonEncode(queryParameters),
      );
    }

    records.sort(_compareRecordTimeDesc);
    return TransactionHistoryPageResult(
      records: records.take(_historyLimit).toList(growable: false),
      nextCursor: nextCursor,
    );
  }

  Map<String, dynamic>? _decodeBlockscoutCursor(String? cursor) {
    if (cursor == null || cursor.isEmpty) return null;
    try {
      final decoded = jsonDecode(cursor);
      if (decoded is! Map) return null;
      return {
        for (final entry in decoded.entries) entry.key.toString(): entry.value,
      };
    } catch (_) {
      return null;
    }
  }

  WalletTransactionRecord? _evmNativeRecordFromExplorer({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> item,
  }) {
    final txHash = item['hash']?.toString() ?? '';
    if (txHash.isEmpty) return null;

    final from = _normalizeEvmDisplayAddress(item['from']?.toString() ?? '');
    final to = _normalizeEvmDisplayAddress(item['to']?.toString() ?? '');
    final rawValue =
        BigInt.tryParse(item['value']?.toString() ?? '') ?? BigInt.zero;
    final gasUsed =
        BigInt.tryParse(item['gasUsed']?.toString() ?? '') ?? BigInt.zero;
    final gasPrice =
        BigInt.tryParse(item['gasPrice']?.toString() ?? '') ?? BigInt.zero;

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
      status: _evmExplorerStatus(item),
      source: WalletTransactionSource.remote,
      feeAmount: gasUsed > BigInt.zero && gasPrice > BigInt.zero
          ? WalletTransferService.rawUnitsToAmount(gasUsed * gasPrice, 18)
          : null,
      feeSymbol: asset.chainRef.symbol,
      blockNumber: int.tryParse(item['blockNumber']?.toString() ?? ''),
      timestamp: _dateTimeFromSeconds(item['timeStamp']),
    );
  }

  WalletTransactionRecord? _evmTokenRecordFromExplorer({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> item,
  }) {
    final txHash = item['hash']?.toString() ?? '';
    if (txHash.isEmpty) return null;
    final contractAddress = item['contractAddress']?.toString() ?? '';
    if (!_sameEvmAddress(contractAddress, asset.contractAddress ?? '')) {
      return null;
    }

    final decimals =
        int.tryParse(item['tokenDecimal']?.toString() ?? '') ?? asset.decimals;
    final rawValue =
        BigInt.tryParse(item['value']?.toString() ?? '') ?? BigInt.zero;
    final from = _normalizeEvmDisplayAddress(item['from']?.toString() ?? '');
    final to = _normalizeEvmDisplayAddress(item['to']?.toString() ?? '');
    final gasUsed =
        BigInt.tryParse(item['gasUsed']?.toString() ?? '') ?? BigInt.zero;
    final gasPrice =
        BigInt.tryParse(item['gasPrice']?.toString() ?? '') ?? BigInt.zero;

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
        normalize: _normalizeEvmCompareAddress,
      ),
      status: _evmExplorerStatus(item),
      source: WalletTransactionSource.remote,
      contractAddress: asset.contractAddress,
      feeAmount: gasUsed > BigInt.zero && gasPrice > BigInt.zero
          ? WalletTransferService.rawUnitsToAmount(gasUsed * gasPrice, 18)
          : null,
      feeSymbol: asset.chainRef.symbol,
      blockNumber: int.tryParse(item['blockNumber']?.toString() ?? ''),
      timestamp: _dateTimeFromSeconds(item['timeStamp']),
    );
  }

  WalletTransactionRecord? _evmNativeRecordFromBlockscout({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> item,
  }) {
    final txHash = item['hash']?.toString() ?? '';
    if (txHash.isEmpty) return null;

    final from = _normalizeEvmDisplayAddress(_blockscoutAddress(item['from']));
    final to = _normalizeEvmDisplayAddress(_blockscoutAddress(item['to']));
    final rawValue =
        BigInt.tryParse(item['value']?.toString() ?? '') ?? BigInt.zero;
    final feeValue = _blockscoutFeeValue(item);

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
      status: _blockscoutStatus(item),
      source: WalletTransactionSource.remote,
      feeAmount: feeValue > BigInt.zero
          ? WalletTransferService.rawUnitsToAmount(feeValue, 18)
          : null,
      feeSymbol: asset.chainRef.symbol,
      blockNumber: _intFromObject(item['block_number']),
      timestamp: _dateTimeFromIso(item['timestamp']),
    );
  }

  WalletTransactionRecord? _evmTokenRecordFromBlockscout({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> item,
  }) {
    final txHash = item['transaction_hash']?.toString() ?? '';
    if (txHash.isEmpty) return null;

    final token = item['token'];
    final contractAddress = token is Map
        ? token['address_hash']?.toString() ?? ''
        : '';
    if (!_sameEvmAddress(contractAddress, asset.contractAddress ?? '')) {
      return null;
    }

    final total = item['total'];
    final decimals = total is Map
        ? int.tryParse(total['decimals']?.toString() ?? '') ?? asset.decimals
        : token is Map
        ? int.tryParse(token['decimals']?.toString() ?? '') ?? asset.decimals
        : asset.decimals;
    final rawValue = total is Map
        ? BigInt.tryParse(total['value']?.toString() ?? '')
        : null;
    if (rawValue == null) return null;

    final from = _normalizeEvmDisplayAddress(_blockscoutAddress(item['from']));
    final to = _normalizeEvmDisplayAddress(_blockscoutAddress(item['to']));
    final logIndex = item['log_index']?.toString() ?? '';

    return WalletTransactionRecord(
      id: _recordId(walletId, asset, '$txHash:$logIndex'),
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
      blockNumber: _intFromObject(item['block_number']),
      timestamp: _dateTimeFromIso(item['timestamp']),
    );
  }

  Future<List<WalletTransactionRecord>> _loadEvmTokenLogs({
    required String walletId,
    required ChainBalance asset,
  }) async {
    final latestBlock = await _evmRpcBigInt(
      asset.chainRef,
      'eth_blockNumber',
      const [],
    );
    final latest = latestBlock.toInt();
    final start = math.max(
      0,
      latest - _evmLogScanBlockWindowFor(asset.chainRef),
    );
    final walletTopic = _evmAddressTopic(asset.address);
    final records = <WalletTransactionRecord>[];
    final seenIds = <String>{};

    for (var toBlock = latest; toBlock >= start; toBlock -= _evmLogChunkSize) {
      final fromBlock = math.max(start, toBlock - _evmLogChunkSize + 1);

      // ✅ 并行获取转出和转入日志
      final results = await Future.wait([
        _evmGetLogs(asset.chainRef, {
          'address': asset.contractAddress,
          'fromBlock': _hexQuantity(BigInt.from(fromBlock)),
          'toBlock': _hexQuantity(BigInt.from(toBlock)),
          'topics': [_evmTransferEventTopic, walletTopic],
        }),
        _evmGetLogs(asset.chainRef, {
          'address': asset.contractAddress,
          'fromBlock': _hexQuantity(BigInt.from(fromBlock)),
          'toBlock': _hexQuantity(BigInt.from(toBlock)),
          'topics': [_evmTransferEventTopic, null, walletTopic],
        }),
      ]);

      final outgoing = results[0];
      final incoming = results[1];

      // ✅ 并行处理所有日志
      final logFutures = [...outgoing, ...incoming].whereType<Map>().map(
        (log) =>
            _evmTokenRecordFromLog(walletId: walletId, asset: asset, log: log),
      );

      final processedRecords = await Future.wait(logFutures);

      for (final record in processedRecords) {
        if (record != null && seenIds.add(record.id)) {
          records.add(record);
        }
      }

      records.sort(_compareRecordTimeDesc);
      if (records.length >= _historyLimit) {
        break;
      }
    }

    records.sort(_compareRecordTimeDesc);
    return records.take(_historyLimit).toList(growable: false);
  }

  int _evmLogScanBlockWindowFor(WalletChainRef chain) {
    if (chain.id == WalletChain.arbitrum.id) {
      return _arbitrumLogScanBlockWindow;
    }
    return _evmLogScanBlockWindow;
  }

  Future<WalletTransactionRecord?> _evmTokenRecordFromLog({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> log,
  }) async {
    final txHash = log['transactionHash']?.toString() ?? '';
    final topics = log['topics'];
    if (txHash.isEmpty || topics is! List || topics.length < 3) return null;

    final from = _evmAddressFromTopic(topics[1]?.toString() ?? '');
    final to = _evmAddressFromTopic(topics[2]?.toString() ?? '');
    final rawValue = _parseHexQuantity(log['data']?.toString() ?? '0x0');
    final blockHex = log['blockNumber']?.toString() ?? '0x0';
    final blockNumber = _parseHexQuantity(blockHex).toInt();
    final receipt = await _evmRpcMap(
      asset.chainRef,
      'eth_getTransactionReceipt',
      [txHash],
    );
    final block = await _evmRpcMap(asset.chainRef, 'eth_getBlockByNumber', [
      blockHex,
      false,
    ]);
    final gasUsed = _parseHexQuantity(receipt['gasUsed']?.toString() ?? '0x0');
    final gasPrice = _parseHexQuantity(
      receipt['effectiveGasPrice']?.toString() ??
          receipt['gasPrice']?.toString() ??
          '0x0',
    );

    return WalletTransactionRecord(
      id: _recordId(walletId, asset, '$txHash:$blockNumber:${log['logIndex']}'),
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
      status: receipt['status']?.toString() == '0x0'
          ? WalletTransactionStatus.failed
          : WalletTransactionStatus.success,
      source: WalletTransactionSource.remote,
      contractAddress: asset.contractAddress,
      feeAmount: gasUsed > BigInt.zero && gasPrice > BigInt.zero
          ? WalletTransferService.rawUnitsToAmount(gasUsed * gasPrice, 18)
          : null,
      feeSymbol: asset.chainRef.symbol,
      blockNumber: blockNumber,
      timestamp: _dateTimeFromSeconds(
        _parseHexQuantity(block['timestamp']?.toString() ?? '0x0').toString(),
      ),
    );
  }

  Future<TransactionHistoryPageResult> _loadTronRecordPage({
    required String walletId,
    required ChainBalance asset,
    TransactionHistoryCursor? cursor,
  }) async {
    Object? lastError;
    for (final apiUrl in _tronApiUrls(asset.chainRef)) {
      try {
        final response = await _dio.get(
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
    if (!_apiConfig.hasTronGridApiKey) return null;
    final uri = Uri.tryParse(apiUrl);
    if (uri == null || !uri.host.toLowerCase().contains('trongrid')) {
      return null;
    }
    return Options(
      headers: {'TRON-PRO-API-KEY': _apiConfig.tronGridApiKey.trim()},
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

  Future<TransactionHistoryPageResult> _loadSolanaRecordPage({
    required String walletId,
    required ChainBalance asset,
    TransactionHistoryCursor? cursor,
  }) async {
    if (asset.isNative) {
      return _loadSolanaNativeRecordPage(
        walletId: walletId,
        asset: asset,
        cursor: cursor,
      );
    }
    if (cursor != null) {
      return const TransactionHistoryPageResult(records: [], nextCursor: null);
    }
    final records = await _loadSolanaTokenRecords(
      walletId: walletId,
      asset: asset,
    );
    return TransactionHistoryPageResult(records: records, nextCursor: null);
  }

  Future<TransactionHistoryPageResult> _loadSolanaNativeRecordPage({
    required String walletId,
    required ChainBalance asset,
    TransactionHistoryCursor? cursor,
  }) async {
    final signatures = await _solanaSignaturesForAddress(
      chain: asset.chainRef,
      address: asset.address,
      before: cursor?.solanaBefore,
    );
    final records = <WalletTransactionRecord>[];
    for (final signature in signatures.take(_historyLimit)) {
      final transaction = await _solanaParsedTransaction(
        chain: asset.chainRef,
        signature: signature,
      );
      records.addAll(
        _solanaNativeRecordsFromTransaction(
          walletId: walletId,
          asset: asset,
          signature: signature,
          transaction: transaction,
        ),
      );
      if (records.length >= _historyLimit) break;
    }
    records.sort(_compareRecordTimeDesc);
    return TransactionHistoryPageResult(
      records: records.take(_historyLimit).toList(growable: false),
      nextCursor: signatures.length >= _historyLimit
          ? TransactionHistoryCursor.solanaBefore(signatures.last)
          : null,
    );
  }

  Future<List<WalletTransactionRecord>> _loadSolanaTokenRecords({
    required String walletId,
    required ChainBalance asset,
  }) async {
    final tokenAccounts = await _solanaTokenAccountsForMint(
      chain: asset.chainRef,
      ownerAddress: asset.address,
      mintAddress: asset.contractAddress ?? '',
    );
    if (tokenAccounts.isEmpty) {
      return const [];
    }

    final signatures = <String>{};
    for (final account in tokenAccounts.take(4)) {
      final accountSignatures = await _solanaSignaturesForAddress(
        chain: asset.chainRef,
        address: account,
        limit: math.max(8, _historyLimit ~/ tokenAccounts.length),
      );
      signatures.addAll(accountSignatures);
      if (signatures.length >= _historyLimit) break;
    }

    final records = <WalletTransactionRecord>[];
    for (final signature in signatures.take(_historyLimit)) {
      final transaction = await _solanaParsedTransaction(
        chain: asset.chainRef,
        signature: signature,
      );
      records.addAll(
        _solanaTokenRecordsFromTransaction(
          walletId: walletId,
          asset: asset,
          signature: signature,
          transaction: transaction,
          ownedTokenAccounts: tokenAccounts.toSet(),
        ),
      );
      if (records.length >= _historyLimit) break;
    }
    records.sort(_compareRecordTimeDesc);
    return records.take(_historyLimit).toList(growable: false);
  }

  List<WalletTransactionRecord> _solanaNativeRecordsFromTransaction({
    required String walletId,
    required ChainBalance asset,
    required String signature,
    required Map<dynamic, dynamic> transaction,
  }) {
    final records = <WalletTransactionRecord>[];
    final instructions = _solanaInstructions(transaction);
    for (var index = 0; index < instructions.length; index++) {
      final instruction = instructions[index];
      final parsed = instruction is Map ? instruction['parsed'] : null;
      final info = parsed is Map ? parsed['info'] : null;
      if (info is! Map || parsed['type']?.toString() != 'transfer') continue;
      if (instruction['program']?.toString() != 'system') continue;

      final from = info['source']?.toString() ?? '';
      final to = info['destination']?.toString() ?? '';
      if (from != asset.address && to != asset.address) continue;

      final lamports =
          BigInt.tryParse(info['lamports']?.toString() ?? '') ?? BigInt.zero;
      records.add(
        WalletTransactionRecord(
          id: _recordId(walletId, asset, '$signature:$index'),
          walletId: walletId,
          chainId: asset.chainId,
          chainName: asset.chainRef.name,
          symbol: asset.symbol,
          assetName: asset.name,
          walletAddress: asset.address,
          txHash: signature,
          fromAddress: from,
          toAddress: to,
          amount: WalletTransferService.rawUnitsToAmount(lamports, 9),
          decimals: 9,
          direction: _directionForAddress(
            walletAddress: asset.address,
            fromAddress: from,
            toAddress: to,
            normalize: (value) => value.trim(),
          ),
          status: _solanaStatus(transaction),
          source: WalletTransactionSource.remote,
          feeAmount: _solanaFeeAmount(transaction),
          feeSymbol: asset.chainRef.symbol,
          timestamp: _dateTimeFromSeconds(transaction['blockTime']),
        ),
      );
    }
    return records;
  }

  List<WalletTransactionRecord> _solanaTokenRecordsFromTransaction({
    required String walletId,
    required ChainBalance asset,
    required String signature,
    required Map<dynamic, dynamic> transaction,
    required Set<String> ownedTokenAccounts,
  }) {
    final records = <WalletTransactionRecord>[];
    final instructions = _solanaInstructions(transaction);
    for (var index = 0; index < instructions.length; index++) {
      final instruction = instructions[index];
      if (instruction is! Map ||
          instruction['program']?.toString() != 'spl-token') {
        continue;
      }
      final parsed = instruction['parsed'];
      final type = parsed is Map ? parsed['type']?.toString() : null;
      if (type != 'transfer' && type != 'transferChecked') continue;
      final info = parsed is Map ? parsed['info'] : null;
      if (info is! Map) continue;

      final mint = info['mint']?.toString();
      if (mint != null && mint.isNotEmpty && mint != asset.contractAddress) {
        continue;
      }
      final source = info['source']?.toString() ?? '';
      final destination = info['destination']?.toString() ?? '';
      final touchesWallet =
          ownedTokenAccounts.contains(source) ||
          ownedTokenAccounts.contains(destination);
      if (!touchesWallet) continue;

      final tokenAmount = info['tokenAmount'];
      final decimals = tokenAmount is Map
          ? int.tryParse(tokenAmount['decimals']?.toString() ?? '') ??
                asset.decimals
          : asset.decimals;
      final rawValue = tokenAmount is Map
          ? BigInt.tryParse(tokenAmount['amount']?.toString() ?? '')
          : BigInt.tryParse(info['amount']?.toString() ?? '');
      if (rawValue == null) continue;

      final direction = ownedTokenAccounts.contains(source)
          ? ownedTokenAccounts.contains(destination)
                ? WalletTransactionDirection.selfTransfer
                : WalletTransactionDirection.outgoing
          : WalletTransactionDirection.incoming;
      records.add(
        WalletTransactionRecord(
          id: _recordId(walletId, asset, '$signature:$index'),
          walletId: walletId,
          chainId: asset.chainId,
          chainName: asset.chainRef.name,
          symbol: asset.symbol,
          assetName: asset.name,
          walletAddress: asset.address,
          txHash: signature,
          fromAddress: info['authority']?.toString() ?? source,
          toAddress: destination,
          amount: WalletTransferService.rawUnitsToAmount(rawValue, decimals),
          decimals: decimals,
          direction: direction,
          status: _solanaStatus(transaction),
          source: WalletTransactionSource.remote,
          contractAddress: asset.contractAddress,
          feeAmount: _solanaFeeAmount(transaction),
          feeSymbol: asset.chainRef.symbol,
          timestamp: _dateTimeFromSeconds(transaction['blockTime']),
        ),
      );
    }
    return records;
  }

  Future<List<String>> _solanaSignaturesForAddress({
    required WalletChainRef chain,
    required String address,
    int limit = _historyLimit,
    String? before,
  }) async {
    final result = await _solanaRpc(chain, 'getSignaturesForAddress', [
      address,
      {
        'limit': limit,
        if (before != null && before.isNotEmpty) 'before': before,
      },
    ]);
    if (result is! List) {
      return const [];
    }
    return result
        .whereType<Map>()
        .map((item) => item['signature']?.toString() ?? '')
        .where((signature) => signature.isNotEmpty)
        .toList(growable: false);
  }

  Future<Map<dynamic, dynamic>> _solanaParsedTransaction({
    required WalletChainRef chain,
    required String signature,
  }) async {
    final result = await _solanaRpc(chain, 'getParsedTransaction', [
      signature,
      {'encoding': 'jsonParsed', 'maxSupportedTransactionVersion': 0},
    ]);
    if (result is Map) {
      return result;
    }
    return const {};
  }

  Future<List<String>> _solanaTokenAccountsForMint({
    required WalletChainRef chain,
    required String ownerAddress,
    required String mintAddress,
  }) async {
    if (mintAddress.isEmpty) return const [];
    final result = await _solanaRpc(chain, 'getTokenAccountsByOwner', [
      ownerAddress,
      {'mint': mintAddress},
      {'encoding': 'jsonParsed'},
    ]);
    final values = result is Map ? result['value'] : null;
    if (values is! List) return const [];
    return values
        .whereType<Map>()
        .map((item) => item['pubkey']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  List<dynamic> _solanaInstructions(Map<dynamic, dynamic> transaction) {
    final instructions = <dynamic>[];
    final tx = transaction['transaction'];
    final message = tx is Map ? tx['message'] : null;
    final rootInstructions = message is Map ? message['instructions'] : null;
    if (rootInstructions is List) {
      instructions.addAll(rootInstructions);
    }

    final meta = transaction['meta'];
    final inner = meta is Map ? meta['innerInstructions'] : null;
    if (inner is List) {
      for (final item in inner.whereType<Map>()) {
        final values = item['instructions'];
        if (values is List) {
          instructions.addAll(values);
        }
      }
    }
    return instructions;
  }

  Future<dynamic> _evmRpc(
    WalletChainRef chain,
    String method,
    List<dynamic> params,
  ) async {
    Object? lastError;
    for (final rpcUrl in _evmRpcUrls(chain)) {
      try {
        final response = await _dio.post(
          rpcUrl,
          data: {'jsonrpc': '2.0', 'method': method, 'params': params, 'id': 1},
          options: Options(headers: {'content-type': 'application/json'}),
        );
        final data = response.data;
        if (data is Map && data.containsKey('result')) {
          return data['result'];
        }
        throw StateError(data is Map ? data.toString() : 'Invalid RPC data');
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError('${chain.name} RPC failed: ${lastError ?? 'unknown'}');
  }

  Future<BigInt> _evmRpcBigInt(
    WalletChainRef chain,
    String method,
    List<dynamic> params,
  ) async {
    return _parseHexQuantity((await _evmRpc(chain, method, params)).toString());
  }

  Future<Map<dynamic, dynamic>> _evmRpcMap(
    WalletChainRef chain,
    String method,
    List<dynamic> params,
  ) async {
    final result = await _evmRpc(chain, method, params);
    if (result is Map) {
      return result;
    }
    throw StateError('Invalid ${chain.name} $method response');
  }

  Future<List<dynamic>> _evmGetLogs(
    WalletChainRef chain,
    Map<String, dynamic> filter,
  ) async {
    final result = await _evmRpc(chain, 'eth_getLogs', [filter]);
    return result is List ? result : const [];
  }

  Future<dynamic> _solanaRpc(
    WalletChainRef chain,
    String method,
    List<dynamic> params,
  ) async {
    Object? lastError;
    for (final rpcUrl in _solanaRpcUrls(chain)) {
      try {
        final response = await _dio.post(
          rpcUrl,
          data: {'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params},
          options: Options(headers: {'content-type': 'application/json'}),
        );
        final data = response.data;
        if (data is Map && data.containsKey('result')) {
          return data['result'];
        }
        throw StateError(data is Map ? data.toString() : 'Invalid RPC data');
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError('Solana RPC failed: ${lastError ?? 'unknown'}');
  }

  WalletTransactionStatus _evmExplorerStatus(Map<dynamic, dynamic> item) {
    if (item['isError']?.toString() == '1' ||
        item['txreceipt_status']?.toString() == '0') {
      return WalletTransactionStatus.failed;
    }
    if (item['txreceipt_status']?.toString() == '1' ||
        item['isError']?.toString() == '0' ||
        !item.containsKey('txreceipt_status')) {
      return WalletTransactionStatus.success;
    }
    return WalletTransactionStatus.unknown;
  }

  WalletTransactionStatus _blockscoutStatus(Map<dynamic, dynamic> item) {
    final status = item['status']?.toString().toLowerCase() ?? '';
    final result = item['result']?.toString().toLowerCase() ?? '';
    if (status == 'error' ||
        result.contains('error') ||
        result.contains('fail') ||
        result.contains('out of gas')) {
      return WalletTransactionStatus.failed;
    }
    if (status == 'ok' || result == 'success') {
      return WalletTransactionStatus.success;
    }
    return WalletTransactionStatus.unknown;
  }

  String _blockscoutAddress(Object? value) {
    if (value is Map) {
      return value['hash']?.toString() ?? '';
    }
    return value?.toString() ?? '';
  }

  BigInt _blockscoutFeeValue(Map<dynamic, dynamic> item) {
    final fee = item['fee'];
    if (fee is Map) {
      return BigInt.tryParse(fee['value']?.toString() ?? '') ?? BigInt.zero;
    }
    return BigInt.tryParse(fee?.toString() ?? '') ?? BigInt.zero;
  }

  bool _sameEvmAddress(String left, String right) {
    final normalizedLeft = _normalizeEvmCompareAddress(left);
    final normalizedRight = _normalizeEvmCompareAddress(right);
    return normalizedLeft.isNotEmpty && normalizedLeft == normalizedRight;
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

  WalletTransactionStatus _solanaStatus(Map<dynamic, dynamic> transaction) {
    final meta = transaction['meta'];
    if (meta is Map && meta.containsKey('err')) {
      return meta['err'] == null
          ? WalletTransactionStatus.success
          : WalletTransactionStatus.failed;
    }
    return WalletTransactionStatus.unknown;
  }

  WalletTransactionDirection _directionForAddress({
    required String walletAddress,
    required String fromAddress,
    required String toAddress,
    required String Function(String value) normalize,
  }) {
    final wallet = normalize(walletAddress);
    final from = normalize(fromAddress);
    final to = normalize(toAddress);
    if (wallet.isEmpty) return WalletTransactionDirection.unknown;
    if (from == wallet && to == wallet) {
      return WalletTransactionDirection.selfTransfer;
    }
    if (to == wallet) return WalletTransactionDirection.incoming;
    if (from == wallet) return WalletTransactionDirection.outgoing;
    return WalletTransactionDirection.unknown;
  }

  List<String> _evmRpcUrls(WalletChainRef chain) {
    final fallback = _evmRpcFallbacks[chain.id] ?? const [];
    if (chain is WalletChainConfig) {
      return _mergeUrls(chain.rpcUrls, fallback);
    }
    return _mergeUrls([chain.rpcUrl], fallback);
  }

  List<_EvmHistoryProvider> _evmHistoryProviders(WalletChainRef chain) {
    final providers = <_EvmHistoryProvider>[];
    final apiKey = _configuredExplorerApiKey(chain);
    final configuredApiUrl = _configuredExplorerApiUrl(chain);
    if (configuredApiUrl != null) {
      providers.add(_evmProviderFromUrl(configuredApiUrl, apiKey: apiKey));
    }

    if (_apiConfig.hasEtherscanApiKey && chain.evmChainId != null) {
      developer.log(
        'Using Etherscan V2 history provider for ${chain.name} '
        'chainId=${chain.evmChainId}',
        name: 'WalletTransactionHistoryService',
      );
      providers.add(
        _EvmHistoryProvider(
          url: _etherscanV2ApiUrl,
          apiKey: _apiConfig.etherscanApiKey,
          type: _EvmHistoryProviderType.etherscanCompatible,
        ),
      );
    } else if (chain.id == WalletChain.arbitrum.id) {
      developer.log(
        'Etherscan V2 API key is not injected for Arbitrum history',
        name: 'WalletTransactionHistoryService',
      );
    }

    for (final baseUrl in _evmBlockscoutBaseUrls[chain.id] ?? const []) {
      providers.add(
        _EvmHistoryProvider(
          url: baseUrl,
          type: _EvmHistoryProviderType.blockscoutV2,
        ),
      );
    }

    final legacyApiUrl = _evmExplorerApiUrls[chain.id];
    if (legacyApiUrl != null) {
      providers.add(
        _EvmHistoryProvider(
          url: legacyApiUrl,
          apiKey: apiKey,
          type: _EvmHistoryProviderType.etherscanCompatible,
        ),
      );
    }

    final seen = <String>{};
    return providers
        .where((provider) {
          final key = [
            provider.type.name,
            _normalizeExplorerUrl(provider.url),
            provider.apiKey ?? '',
          ].join(':');
          return seen.add(key);
        })
        .toList(growable: false);
  }

  _EvmHistoryProvider _evmProviderFromUrl(String apiUrl, {String? apiKey}) {
    final type = _looksLikeBlockscoutUrl(apiUrl)
        ? _EvmHistoryProviderType.blockscoutV2
        : _EvmHistoryProviderType.etherscanCompatible;
    return _EvmHistoryProvider(url: apiUrl, apiKey: apiKey, type: type);
  }

  String? _configuredExplorerApiUrl(WalletChainRef chain) {
    if (chain is WalletChainConfig) {
      final value = chain.explorerApiUrl?.trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  String? _configuredExplorerApiKey(WalletChainRef chain) {
    if (chain is WalletChainConfig) {
      final value = chain.explorerApiKey?.trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  bool _looksLikeBlockscoutUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;
    return uri.host.toLowerCase().contains('blockscout') ||
        uri.path.toLowerCase().contains('/api/v2');
  }

  String _blockscoutApiBase(String value) {
    final normalized = _normalizeExplorerUrl(value);
    const marker = '/api/v2';
    final markerIndex = normalized.toLowerCase().indexOf(marker);
    if (markerIndex >= 0) {
      return normalized.substring(0, markerIndex + marker.length);
    }
    return '$normalized$marker';
  }

  bool _isEtherscanV2Api(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;
    return uri.path.toLowerCase().contains('/v2/api');
  }

  String _normalizeExplorerUrl(String value) {
    return value.trim().replaceAll(RegExp(r'/+$'), '');
  }

  List<String> _tronApiUrls(WalletChainRef chain) {
    if (chain is WalletChainConfig) {
      return _mergeUrls(chain.rpcUrls, _tronApiFallbacks);
    }
    return _mergeUrls([chain.rpcUrl], _tronApiFallbacks);
  }

  List<String> _solanaRpcUrls(WalletChainRef chain) {
    if (chain is WalletChainConfig) {
      return _mergeUrls(chain.rpcUrls, _solanaRpcFallbacks);
    }
    return _mergeUrls([chain.rpcUrl], _solanaRpcFallbacks);
  }

  List<String> _mergeUrls(List<String> primary, List<String> fallback) {
    final values = <String>{};
    for (final url in [...primary, ...fallback]) {
      final normalized = url.trim();
      if (normalized.isNotEmpty) {
        values.add(normalized);
      }
    }
    return values.toList(growable: false);
  }

  bool _isTronChain(WalletChainRef chain) {
    return chain.id == WalletChain.tron.id ||
        (chain is WalletChainConfig && chain.type == WalletChainType.tron);
  }

  bool _isSolanaChain(WalletChainRef chain) {
    return chain.id == WalletChain.solana.id ||
        (chain is WalletChainConfig && chain.type == WalletChainType.solana);
  }

  String _recordId(String walletId, ChainBalance asset, String txHash) {
    return [
      'remote',
      walletId,
      asset.chainId,
      _assetKey(asset),
      txHash.toLowerCase(),
    ].join(':');
  }

  String _assetKey(ChainBalance asset) {
    final contract = asset.contractAddress?.trim() ?? '';
    return [
      asset.chainId,
      contract.isEmpty ? 'native' : contract.toLowerCase(),
      asset.symbol.toUpperCase(),
    ].join(':');
  }

  int _compareRecordTimeDesc(
    WalletTransactionRecord left,
    WalletTransactionRecord right,
  ) {
    final leftTime = left.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
    final rightTime = right.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
    return rightTime.compareTo(leftTime);
  }

  String _normalizeEvmDisplayAddress(String value) {
    final trimmed = value.trim();
    if (!RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(trimmed)) {
      return trimmed;
    }
    return '0x${trimmed.substring(2).toLowerCase()}';
  }

  String _normalizeEvmCompareAddress(String value) {
    return value.trim().toLowerCase();
  }

  String _evmAddressTopic(String address) {
    final normalized = _normalizeEvmCompareAddress(
      address,
    ).replaceFirst('0x', '');
    return '0x${normalized.padLeft(64, '0')}';
  }

  String _evmAddressFromTopic(String topic) {
    final value = topic.replaceFirst('0x', '');
    if (value.length < 40) return topic;
    return '0x${value.substring(value.length - 40).toLowerCase()}';
  }

  String _normalizeTronDisplayAddress(String value) {
    final trimmed = value.trim();
    if (RegExp(r'^(41)?[0-9a-fA-F]{40}$').hasMatch(trimmed)) {
      final hexValue = trimmed.startsWith('41') ? trimmed : '41$trimmed';
      return _tronHexToAddress(hexValue);
    }
    return trimmed;
  }

  String _normalizeTronCompareAddress(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    if (RegExp(r'^(41)?[0-9a-fA-F]{40}$').hasMatch(trimmed)) {
      final hexValue = trimmed.startsWith('41') ? trimmed : '41$trimmed';
      return hexValue.toLowerCase();
    }
    try {
      return WalletTransferService.tronAddressToHex(trimmed).toLowerCase();
    } catch (_) {
      return trimmed;
    }
  }

  Map<dynamic, dynamic> _firstTronContractValue(Map<dynamic, dynamic> item) {
    final rawData = item['raw_data'];
    final contracts = rawData is Map ? rawData['contract'] : null;
    if (contracts is! List || contracts.isEmpty || contracts.first is! Map) {
      return const {};
    }
    final parameter = (contracts.first as Map)['parameter'];
    final value = parameter is Map ? parameter['value'] : null;
    return value is Map ? value : const {};
  }

  String? _nestedValue(Map<dynamic, dynamic> item, List<String> keys) {
    dynamic current = item;
    for (final key in keys) {
      if (current is! Map) return null;
      current = current[key];
    }
    return current?.toString();
  }

  String? _solanaFeeAmount(Map<dynamic, dynamic> transaction) {
    final meta = transaction['meta'];
    final fee = meta is Map
        ? BigInt.tryParse(meta['fee']?.toString() ?? '')
        : null;
    if (fee == null || fee == BigInt.zero) return null;
    return WalletTransferService.rawUnitsToAmount(fee, 9);
  }

  DateTime? _dateTimeFromSeconds(Object? value) {
    final seconds = int.tryParse(value?.toString() ?? '');
    if (seconds == null || seconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  DateTime? _dateTimeFromMilliseconds(Object? value) {
    final milliseconds = int.tryParse(value?.toString() ?? '');
    if (milliseconds == null || milliseconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  DateTime? _dateTimeFromIso(Object? value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  int? _intFromObject(Object? value) {
    return int.tryParse(value?.toString() ?? '');
  }

  BigInt _parseHexQuantity(String value) {
    final normalized = value.trim().replaceFirst('0x', '');
    if (normalized.isEmpty) return BigInt.zero;
    return BigInt.parse(normalized, radix: 16);
  }

  String _hexQuantity(BigInt value) {
    return '0x${value.toRadixString(16)}';
  }

  String _tronHexToAddress(String value) {
    final bytes = Uint8List.fromList(hex.decode(value));
    final firstHash = _sha256(bytes);
    final secondHash = _sha256(firstHash);
    final checksum = secondHash.take(4);
    return _base58Encode(Uint8List.fromList([...bytes, ...checksum]));
  }

  Uint8List _sha256(Uint8List input) {
    return SHA256Digest().process(input);
  }

  String _base58Encode(Uint8List bytes) {
    var value = BigInt.zero;
    for (final byte in bytes) {
      value = value * BigInt.from(256) + BigInt.from(byte);
    }

    final base = BigInt.from(58);
    final output = StringBuffer();
    while (value > BigInt.zero) {
      final mod = value % base;
      output.write(CryptoConstants.base58Alphabet[mod.toInt()]);
      value ~/= base;
    }

    for (final byte in bytes) {
      if (byte == 0) {
        output.write(CryptoConstants.base58Alphabet[0]);
      } else {
        break;
      }
    }
    return output.toString().split('').reversed.join();
  }
}

enum _EvmHistoryProviderType { etherscanCompatible, blockscoutV2 }

class _EvmHistoryProvider {
  const _EvmHistoryProvider({
    required this.url,
    required this.type,
    this.apiKey,
  });

  final String url;
  final _EvmHistoryProviderType type;
  final String? apiKey;
}
