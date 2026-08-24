part of '../wallet_transaction_history_service.dart';

/// Resolves the wallet's SPL token accounts for a mint.
class _SolanaTokenAccountClient with _TransactionHistoryProviderHelpers {
  _SolanaTokenAccountClient({
    required this.dio,
    required this.apiConfig,
    required _SolanaRpcClient rpcClient,
  }) : _rpcClient = rpcClient;

  @override
  final Dio dio;

  @override
  final WalletHistoryApiConfig apiConfig;

  final _SolanaRpcClient _rpcClient;

  Future<List<String>> loadForMint({
    required WalletChainRef chain,
    required String ownerAddress,
    required String mintAddress,
  }) async {
    if (mintAddress.isEmpty) return const [];
    final result = await _rpcClient.request(chain, 'getTokenAccountsByOwner', [
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
}
