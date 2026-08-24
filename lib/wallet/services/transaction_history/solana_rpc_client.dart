part of '../wallet_transaction_history_service.dart';

/// Owns Solana JSON-RPC transport and response validation.
class _SolanaRpcClient with _TransactionHistoryProviderHelpers {
  _SolanaRpcClient({required this.dio, required this.apiConfig});

  @override
  final Dio dio;

  @override
  final WalletHistoryApiConfig apiConfig;

  static const List<String> _fallbackUrls = [
    'https://api.mainnet-beta.solana.com',
    'https://solana-rpc.publicnode.com',
  ];

  Future<List<String>> signaturesForAddress({
    required WalletChainRef chain,
    required String address,
    int limit = _SolanaHistoryLimits.historyLimit,
    String? before,
  }) async {
    final result = await request(chain, 'getSignaturesForAddress', [
      address,
      {
        'limit': limit,
        if (before != null && before.isNotEmpty) 'before': before,
      },
    ]);
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((item) => item['signature']?.toString() ?? '')
        .where((signature) => signature.isNotEmpty)
        .toList(growable: false);
  }

  Future<Map<dynamic, dynamic>> parsedTransaction({
    required WalletChainRef chain,
    required String signature,
  }) async {
    final result = await request(chain, 'getParsedTransaction', [
      signature,
      {'encoding': 'jsonParsed', 'maxSupportedTransactionVersion': 0},
    ]);
    return result is Map ? result : const {};
  }

  Future<dynamic> request(
    WalletChainRef chain,
    String method,
    List<dynamic> params,
  ) async {
    try {
      final data = await RpcRetryHelper.executeJsonRpc(
        dio: dio,
        rpcUrls: _rpcUrls(chain),
        method: method,
        params: params,
        chainName: 'Solana',
        logName: 'WalletTransactionHistoryService',
      );
      if (data.containsKey('result')) return data['result'];
      throw _historyLoadException('Invalid Solana RPC data', data);
    } catch (error) {
      throw _historyLoadException('Solana RPC failed', error);
    }
  }

  List<String> _rpcUrls(WalletChainRef chain) {
    if (chain is WalletChainConfig) {
      return _mergeUrls(chain.rpcUrls, _fallbackUrls);
    }
    return _mergeUrls([chain.rpcUrl], _fallbackUrls);
  }
}
