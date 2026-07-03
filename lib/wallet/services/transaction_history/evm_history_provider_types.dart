part of '../wallet_transaction_history_service.dart';

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
