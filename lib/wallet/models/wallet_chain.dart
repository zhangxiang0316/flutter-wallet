enum WalletChain implements WalletChainRef {
  bsc(
    id: 'bsc',
    name: 'BNB Smart Chain',
    symbol: 'BNB',
    rpcUrl: 'https://bsc-dataseed.bnbchain.org',
    evmChainId: 56,
  ),
  ethereum(
    id: 'ethereum',
    name: 'Ethereum',
    symbol: 'ETH',
    rpcUrl: 'https://ethereum-rpc.publicnode.com',
    evmChainId: 1,
  ),
  xLayer(
    id: 'x-layer',
    name: 'X Layer',
    symbol: 'OKB',
    rpcUrl: 'https://rpc.xlayer.tech',
    evmChainId: 196,
  ),
  arbitrum(
    id: 'arbitrum',
    name: 'Arbitrum',
    symbol: 'ETH',
    rpcUrl: 'https://arb1.arbitrum.io/rpc',
    evmChainId: 42161,
  ),
  bitcoin(
    id: 'bitcoin',
    name: 'Bitcoin',
    symbol: 'BTC',
    rpcUrl: 'https://mempool.space/api',
  ),
  solana(
    id: 'solana',
    name: 'Solana',
    symbol: 'SOL',
    rpcUrl: 'https://api.mainnet-beta.solana.com',
  ),
  tron(
    id: 'tron',
    name: 'TRON',
    symbol: 'TRX',
    rpcUrl: 'https://api.trongrid.io',
  );

  const WalletChain({
    required this.id,
    required this.name,
    required this.symbol,
    required this.rpcUrl,
    this.evmChainId,
  });

  @override
  final String id;
  @override
  final String name;
  @override
  final String symbol;
  @override
  final String rpcUrl;
  @override
  final int? evmChainId;

  @override
  bool get isEvm => evmChainId != null;
}

/// 钱包链的通用只读接口。
///
/// 内置链使用 [WalletChain]，用户添加的 EVM 链使用 [WalletChainConfig]。业务层尽量依赖
/// 这组字段，减少继续把新增链写死到 enum switch 中。
abstract interface class WalletChainRef {
  String get id;
  String get name;
  String get symbol;
  String get rpcUrl;
  int? get evmChainId;
  bool get isEvm;
}

/// 让内置链也能作为通用链配置使用。
extension WalletChainRefExtension on WalletChain {
  WalletChainConfig get config => WalletChainConfig.builtin(this);
}

/// 可持久化的钱包链配置。
///
/// 第一版动态添加链只开放 EVM 网络，因此 [customEvm] 会强制要求 [evmChainId]。
/// Solana/TRON 等非 EVM 链仍作为内置链存在，不允许用户动态添加。
class WalletChainConfig implements WalletChainRef {
  const WalletChainConfig({
    required this.id,
    required this.name,
    required this.symbol,
    required this.rpcUrls,
    required this.type,
    this.evmChainId,
    this.builtinChain,
    this.colorValue,
    this.explorerApiUrl,
    this.explorerApiKey,
    this.isEnabled = true,
  });

  factory WalletChainConfig.builtin(WalletChain chain) {
    return WalletChainConfig(
      id: chain.id,
      name: chain.name,
      symbol: chain.symbol,
      rpcUrls: [chain.rpcUrl],
      type: chain.isEvm
          ? WalletChainType.evm
          : switch (chain) {
              WalletChain.bitcoin => WalletChainType.bitcoin,
              WalletChain.solana => WalletChainType.solana,
              WalletChain.tron => WalletChainType.tron,
              _ => throw StateError('Unsupported builtin chain ${chain.id}'),
            },
      evmChainId: chain.evmChainId,
      builtinChain: chain,
      colorValue: _builtinColorValue(chain),
      explorerApiUrl: _builtinExplorerApiUrl(chain),
    );
  }

  factory WalletChainConfig.customEvm({
    required String id,
    required String name,
    required String symbol,
    required List<String> rpcUrls,
    required int evmChainId,
    int? colorValue,
    String? explorerApiUrl,
    String? explorerApiKey,
    bool isEnabled = true,
  }) {
    return WalletChainConfig(
      id: id,
      name: name,
      symbol: symbol,
      rpcUrls: rpcUrls,
      type: WalletChainType.evm,
      evmChainId: evmChainId,
      colorValue: colorValue,
      explorerApiUrl: explorerApiUrl,
      explorerApiKey: explorerApiKey,
      isEnabled: isEnabled,
    );
  }

  factory WalletChainConfig.fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString() ?? WalletChainType.evm.name;
    final type = WalletChainType.values.firstWhere(
      (item) => item.name == typeName,
      orElse: () => WalletChainType.evm,
    );
    final rpcValue = json['rpcUrls'];
    final rpcUrls = rpcValue is List
        ? rpcValue.map((item) => item.toString()).where(_isNotBlank).toList()
        : <String>[];
    final evmChainIdValue = json['evmChainId'];
    return WalletChainConfig(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
      rpcUrls: rpcUrls,
      type: type,
      evmChainId: evmChainIdValue is int
          ? evmChainIdValue
          : int.tryParse(evmChainIdValue?.toString() ?? ''),
      colorValue: json['colorValue'] is int ? json['colorValue'] as int : null,
      explorerApiUrl: json['explorerApiUrl']?.toString(),
      explorerApiKey: json['explorerApiKey']?.toString(),
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }

  @override
  final String id;

  @override
  final String name;

  @override
  final String symbol;

  final List<String> rpcUrls;

  final WalletChainType type;

  @override
  final int? evmChainId;

  final WalletChain? builtinChain;

  final int? colorValue;

  /// Etherscan 兼容或链浏览器交易记录 API 地址。
  final String? explorerApiUrl;

  /// 链浏览器 API Key。为空时按无 key 请求。
  final String? explorerApiKey;

  final bool isEnabled;

  @override
  String get rpcUrl => rpcUrls.first;

  @override
  bool get isEvm => type == WalletChainType.evm && evmChainId != null;

  bool get isBuiltin => builtinChain != null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'symbol': symbol,
      'rpcUrls': rpcUrls,
      'type': type.name,
      'evmChainId': evmChainId,
      'colorValue': colorValue,
      'explorerApiUrl': explorerApiUrl,
      'explorerApiKey': explorerApiKey,
      'isEnabled': isEnabled,
    };
  }

  WalletChainConfig copyWith({
    String? id,
    String? name,
    String? symbol,
    List<String>? rpcUrls,
    WalletChainType? type,
    int? evmChainId,
    WalletChain? builtinChain,
    int? colorValue,
    String? explorerApiUrl,
    String? explorerApiKey,
    bool? isEnabled,
  }) {
    return WalletChainConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      rpcUrls: rpcUrls ?? this.rpcUrls,
      type: type ?? this.type,
      evmChainId: evmChainId ?? this.evmChainId,
      builtinChain: builtinChain ?? this.builtinChain,
      colorValue: colorValue ?? this.colorValue,
      explorerApiUrl: explorerApiUrl ?? this.explorerApiUrl,
      explorerApiKey: explorerApiKey ?? this.explorerApiKey,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  static bool _isNotBlank(String value) => value.trim().isNotEmpty;

  static int _builtinColorValue(WalletChain chain) {
    switch (chain) {
      case WalletChain.bsc:
        return 0xFFF0B90B;
      case WalletChain.ethereum:
        return 0xFF627EEA;
      case WalletChain.xLayer:
        return 0xFF111827;
      case WalletChain.arbitrum:
        return 0xFF28A0F0;
      case WalletChain.bitcoin:
        return 0xFFF7931A;
      case WalletChain.solana:
        return 0xFF14F195;
      case WalletChain.tron:
        return 0xFFE50914;
    }
  }

  static String? _builtinExplorerApiUrl(WalletChain chain) {
    switch (chain) {
      case WalletChain.bsc:
        return 'https://api.bscscan.com/api';
      case WalletChain.ethereum:
        return 'https://api.etherscan.io/api';
      case WalletChain.arbitrum:
        return 'https://api.arbiscan.io/api';
      case WalletChain.bitcoin:
        return 'https://mempool.space/api';
      case WalletChain.xLayer:
      case WalletChain.solana:
      case WalletChain.tron:
        return null;
    }
  }
}

enum WalletChainType { evm, bitcoin, solana, tron }
