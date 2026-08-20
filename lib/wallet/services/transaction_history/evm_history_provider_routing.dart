part of '../wallet_transaction_history_service.dart';

const Map<String, String> _evmExplorerApiUrls = {
  'bsc': 'https://api.bscscan.com/api',
  'ethereum': 'https://api.etherscan.io/api',
  'arbitrum': 'https://api.arbiscan.io/api',
};

const String _etherscanV2ApiUrl = 'https://api.etherscan.io/v2/api';

const Map<String, List<String>> _evmBlockscoutBaseUrls = {
  'ethereum': ['https://eth.blockscout.com'],
  'base': ['https://base.blockscout.com'],
};

const Map<String, List<String>> _evmRpcFallbacks = {
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
  'base': ['https://mainnet.base.org', 'https://base-rpc.publicnode.com'],
};

extension _EvmHistoryProviderRouting on _EvmTransactionHistoryProvider {
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

    final canUseEtherscanV2 =
        apiConfig.hasEtherscanApiKey &&
        chain.evmChainId != null &&
        chain.id != WalletChain.bsc.id &&
        chain.id != WalletChain.xLayer.id;
    if (canUseEtherscanV2) {
      developer.log(
        'Using Etherscan V2 history provider for ${chain.name} '
        'chainId=${chain.evmChainId}',
        name: 'WalletTransactionHistoryService',
      );
      providers.add(
        _EvmHistoryProvider(
          url: _etherscanV2ApiUrl,
          apiKey: apiConfig.etherscanApiKey,
          type: _EvmHistoryProviderType.etherscanCompatible,
        ),
      );
    } else if (chain.id == WalletChain.arbitrum.id) {
      developer.log(
        'Etherscan V2 API key is not injected for Arbitrum history',
        name: 'WalletTransactionHistoryService',
      );
    }

    if (configuredApiUrl != null) {
      providers.add(_evmProviderFromUrl(configuredApiUrl, apiKey: apiKey));
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
      final legacyApiKey = _legacyExplorerApiKey(chain) ?? apiKey;
      providers.add(
        _EvmHistoryProvider(
          url: legacyApiUrl,
          apiKey: legacyApiKey,
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

  String? _legacyExplorerApiKey(WalletChainRef chain) {
    if (chain.id == WalletChain.arbitrum.id && apiConfig.hasEtherscanApiKey) {
      return apiConfig.etherscanApiKey.trim();
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
}
