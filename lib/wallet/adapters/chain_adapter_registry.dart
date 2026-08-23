import '../models/wallet_chain.dart';
import '../models/wallet_chain_extensions.dart';
import 'chain_adapter.dart';

/// 地址编码器集合，由组合根注入，避免 Adapter 反向依赖转账服务。
class ChainAddressNormalizers {
  const ChainAddressNormalizers({
    required this.evm,
    required this.tron,
    required this.solana,
    required this.bitcoin,
    required this.sui,
    required this.aptos,
  });

  final ChainAddressNormalizer evm;
  final ChainAddressNormalizer tron;
  final ChainAddressNormalizer solana;
  final ChainAddressNormalizer bitcoin;
  final ChainAddressNormalizer sui;
  final ChainAddressNormalizer aptos;
}

/// ChainAdapter 注册表。
///
/// 默认按 [WalletChainType] 唯一注册。测试或后续链实现可显式 replace，业务代码
/// 只通过 [require] 获取适配器，不再自行判断内置链 ID。
class ChainAdapterRegistry {
  ChainAdapterRegistry([Iterable<ChainAdapter> adapters = const []]) {
    for (final adapter in adapters) {
      register(adapter);
    }
  }

  factory ChainAdapterRegistry.standard(ChainAddressNormalizers normalizers) {
    const commonCapabilities = ChainCapabilities({
      ChainCapability.walletAddressResolution,
      ChainCapability.addressValidation,
      ChainCapability.balance,
      ChainCapability.transfer,
      ChainCapability.feeEstimation,
      ChainCapability.history,
      ChainCapability.transactionStatus,
      ChainCapability.receive,
      ChainCapability.blockExplorer,
    });
    const evmCapabilities = ChainCapabilities({
      ChainCapability.walletAddressResolution,
      ChainCapability.addressValidation,
      ChainCapability.balance,
      ChainCapability.transfer,
      ChainCapability.feeEstimation,
      ChainCapability.history,
      ChainCapability.transactionStatus,
      ChainCapability.receive,
      ChainCapability.blockExplorer,
      ChainCapability.customNetworks,
    });

    return ChainAdapterRegistry([
      RegisteredChainAdapter(
        type: WalletChainType.evm,
        capabilities: evmCapabilities,
        presentationBuilder: (chain) =>
            _presentationFor(WalletChainType.evm, chain),
        transferPolicyBuilder: (_) => const ChainTransferPolicy(
          caseInsensitiveAddress: true,
          requiresNetworkConfirmation: true,
          isBurnAddress: _isEvmBurnAddress,
        ),
        walletAddressSelector: (addresses) => addresses.evm,
        addressNormalizer: normalizers.evm,
        addressExtractor: _extractEvmAddress,
        addressExplorerBuilder: _evmAddressExplorerUri,
        transactionExplorerBuilder: _evmTransactionExplorerUri,
      ),
      RegisteredChainAdapter(
        type: WalletChainType.tron,
        capabilities: commonCapabilities,
        presentationBuilder: (chain) =>
            _presentationFor(WalletChainType.tron, chain),
        transferPolicyBuilder: (_) => const ChainTransferPolicy(
          caseInsensitiveAddress: false,
          requiresNetworkConfirmation: false,
          isBurnAddress: _neverBurnAddress,
        ),
        walletAddressSelector: (addresses) => addresses.tron,
        addressNormalizer: normalizers.tron,
        addressExtractor: _extractTronAddress,
        addressExplorerBuilder: (chain, address) =>
            Uri.parse('https://tronscan.org/#/address/$address'),
        transactionExplorerBuilder: (chain, hash) =>
            Uri.parse('https://tronscan.org/#/transaction/$hash'),
      ),
      RegisteredChainAdapter(
        type: WalletChainType.solana,
        capabilities: commonCapabilities,
        presentationBuilder: (chain) =>
            _presentationFor(WalletChainType.solana, chain),
        transferPolicyBuilder: (_) => const ChainTransferPolicy(
          caseInsensitiveAddress: false,
          requiresNetworkConfirmation: false,
          isBurnAddress: _isSolanaBurnAddress,
        ),
        balanceFallbackStrategy:
            ChainBalanceFallbackStrategy.solanaOwnerTokenLookup,
        walletAddressSelector: (addresses) => addresses.solana,
        addressNormalizer: normalizers.solana,
        addressExtractor: _extractSolanaAddress,
        addressExplorerBuilder: (chain, address) =>
            Uri.parse('https://solscan.io/account/$address'),
        transactionExplorerBuilder: (chain, hash) =>
            Uri.parse('https://solscan.io/tx/$hash'),
      ),
      RegisteredChainAdapter(
        type: WalletChainType.bitcoin,
        capabilities: commonCapabilities,
        presentationBuilder: (chain) =>
            _presentationFor(WalletChainType.bitcoin, chain),
        transferPolicyBuilder: (_) => const ChainTransferPolicy(
          caseInsensitiveAddress: true,
          requiresNetworkConfirmation: false,
          isBurnAddress: _neverBurnAddress,
        ),
        walletAddressSelector: (addresses) => addresses.bitcoin,
        addressNormalizer: normalizers.bitcoin,
        addressExtractor: _extractBitcoinAddress,
        addressExplorerBuilder: (chain, address) =>
            Uri.parse('https://mempool.space/address/$address'),
        transactionExplorerBuilder: (chain, hash) =>
            Uri.parse('https://mempool.space/tx/$hash'),
      ),
      RegisteredChainAdapter(
        type: WalletChainType.sui,
        capabilities: commonCapabilities,
        presentationBuilder: (chain) =>
            _presentationFor(WalletChainType.sui, chain),
        transferPolicyBuilder: (_) => const ChainTransferPolicy(
          caseInsensitiveAddress: true,
          requiresNetworkConfirmation: false,
          isBurnAddress: _isZeroAddressBurnAddress,
        ),
        walletAddressSelector: (addresses) => addresses.sui,
        addressNormalizer: normalizers.sui,
        addressExtractor: _extractSuiAddress,
        addressExplorerBuilder: (chain, address) =>
            Uri.parse('https://suiscan.xyz/mainnet/account/$address'),
        transactionExplorerBuilder: (chain, hash) =>
            Uri.parse('https://suiscan.xyz/mainnet/tx/$hash'),
      ),
      RegisteredChainAdapter(
        type: WalletChainType.aptos,
        capabilities: commonCapabilities,
        presentationBuilder: (chain) =>
            _presentationFor(WalletChainType.aptos, chain),
        transferPolicyBuilder: (_) => const ChainTransferPolicy(
          caseInsensitiveAddress: true,
          requiresNetworkConfirmation: false,
          isBurnAddress: _isZeroAddressBurnAddress,
        ),
        walletAddressSelector: (addresses) => addresses.aptos,
        addressNormalizer: normalizers.aptos,
        addressExtractor: _extractAptosAddress,
        addressExplorerBuilder: (chain, address) => Uri.parse(
          'https://explorer.aptoslabs.com/account/$address?network=mainnet',
        ),
        transactionExplorerBuilder: (chain, hash) => Uri.parse(
          'https://explorer.aptoslabs.com/txn/$hash?network=mainnet',
        ),
      ),
    ]);
  }

  final Map<WalletChainType, ChainAdapter> _adapters = {};

  Iterable<ChainAdapter> get adapters => _adapters.values;

  void register(ChainAdapter adapter, {bool replace = false}) {
    if (!replace && _adapters.containsKey(adapter.type)) {
      throw StateError('Adapter already registered for ${adapter.type.name}');
    }
    _adapters[adapter.type] = adapter;
  }

  ChainAdapter? find(WalletChainRef chain) => _adapters[chain.chainType];

  ChainAdapter require(WalletChainRef chain, {ChainCapability? capability}) {
    final adapter = find(chain);
    if (adapter == null || !adapter.supports(chain)) {
      throw StateError('No ChainAdapter registered for ${chain.id}');
    }
    if (capability != null && !adapter.capabilities.supports(capability)) {
      throw StateError('${chain.name} does not support ${capability.name}');
    }
    return adapter;
  }

  /// 在注册表边界完成链类型路由，业务服务不再读取 `adapter.type` 自行分支。
  ///
  /// 处理器仍由具体业务服务提供，因为它们需要访问各自的 RPC 客户端和密钥上下文；
  /// 注册表只负责校验链适配器和能力，并统一处理未注册链的错误。
  T route<T>(
    WalletChainRef chain, {
    ChainCapability? capability,
    required Map<WalletChainType, T Function()> handlers,
  }) {
    final adapter = require(chain, capability: capability);
    final handler = handlers[adapter.type];
    if (handler == null) {
      throw StateError(
        'Missing ${capability?.name ?? 'operation'} handler for ${adapter.type.name}',
      );
    }
    return handler();
  }
}

const _evmAddressTemplates = <String, String>{
  'bsc': 'https://bscscan.com/address/{value}',
  'ethereum': 'https://etherscan.io/address/{value}',
  'x-layer': 'https://web3.okx.com/explorer/xlayer/address/{value}',
  'arbitrum': 'https://arbiscan.io/address/{value}',
  'base': 'https://basescan.org/address/{value}',
  'polygon': 'https://polygonscan.com/address/{value}',
  'avalanche': 'https://snowtrace.io/address/{value}',
};

String? _extractEvmAddress(String value) {
  return RegExp(r'0x[a-fA-F0-9]{40}').firstMatch(value)?.group(0);
}

bool _neverBurnAddress(String value) => false;

bool _isEvmBurnAddress(String value) {
  final address = value.trim().toLowerCase();
  return address == '0x0000000000000000000000000000000000000000' ||
      address == '0x000000000000000000000000000000000000dead';
}

bool _isSolanaBurnAddress(String value) =>
    value.trim() == '11111111111111111111111111111111';

bool _isZeroAddressBurnAddress(String value) =>
    value.trim().toLowerCase() ==
    '0x0000000000000000000000000000000000000000000000000000000000000000';

String? _extractBitcoinAddress(String value) {
  return RegExp(
    r'(?<![02-9ac-hj-np-z])bc1q[02-9ac-hj-np-z]{38}(?![02-9ac-hj-np-z])',
    caseSensitive: false,
  ).firstMatch(value)?.group(0);
}

String? _extractTronAddress(String value) {
  return RegExp(r'T[1-9A-HJ-NP-Za-km-z]{33}').firstMatch(value)?.group(0);
}

String? _extractSolanaAddress(String value) {
  return RegExp(
    r'(?<![1-9A-HJ-NP-Za-km-z])[1-9A-HJ-NP-Za-km-z]{32,44}(?![1-9A-HJ-NP-Za-km-z])',
  ).firstMatch(value)?.group(0);
}

String? _extractSuiAddress(String value) {
  return RegExp(r'0x[a-fA-F0-9]{64}').firstMatch(value)?.group(0);
}

String? _extractAptosAddress(String value) {
  return RegExp(
    r'(?<![a-fA-F0-9])0x[a-fA-F0-9]{1,64}(?![a-fA-F0-9])',
  ).firstMatch(value)?.group(0);
}

const _chainColors = <String, int>{
  'bsc': 0xFFF0B90B,
  'ethereum': 0xFF627EEA,
  'x-layer': 0xFF111827,
  'arbitrum': 0xFF28A0F0,
  'base': 0xFF0052FF,
  'polygon': 0xFF8247E5,
  'avalanche': 0xFFE84142,
  'bitcoin': 0xFFF7931A,
  'solana': 0xFF14F195,
  'sui': 0xFF4DA2FF,
  'aptos': 0xFF13B5A4,
  'tron': 0xFFE50914,
};

const _chainLabels = <String, String>{
  'bsc': 'B',
  'ethereum': 'E',
  'x-layer': 'O',
  'arbitrum': 'A',
  'base': 'B',
  'polygon': 'P',
  'avalanche': 'V',
};

ChainPresentation _presentationFor(WalletChainType type, WalletChainRef chain) {
  final configuredColor = chain is WalletChainConfig ? chain.colorValue : null;
  final color = configuredColor ?? _chainColors[chain.id] ?? 0xFF2563EB;
  final (defaultLabel, hint) = switch (type) {
    WalletChainType.evm => ('E', '0x...'),
    WalletChainType.tron => ('T', 'T...'),
    WalletChainType.solana => ('S', 'Solana address'),
    WalletChainType.bitcoin => ('₿', 'bc1q...'),
    WalletChainType.sui => ('S', '0x + 64 hex'),
    WalletChainType.aptos => ('A', '0x + 1–64 hex'),
  };
  return ChainPresentation(
    colorValue: color,
    label: _chainLabels[chain.id] ?? defaultLabel,
    addressHint: hint,
  );
}

const _evmTransactionTemplates = <String, String>{
  'bsc': 'https://bscscan.com/tx/{value}',
  'ethereum': 'https://etherscan.io/tx/{value}',
  'x-layer': 'https://web3.okx.com/explorer/xlayer/tx/{value}',
  'arbitrum': 'https://arbiscan.io/tx/{value}',
  'base': 'https://basescan.org/tx/{value}',
  'polygon': 'https://polygonscan.com/tx/{value}',
  'avalanche': 'https://snowtrace.io/tx/{value}',
};

Uri? _evmAddressExplorerUri(WalletChainRef chain, String address) {
  final template =
      _evmAddressTemplates[chain.id] ??
      _configuredEvmExplorerTemplate(chain, segment: 'address');
  return _buildTemplateUri(template, address);
}

Uri? _evmTransactionExplorerUri(WalletChainRef chain, String hash) {
  final template =
      _evmTransactionTemplates[chain.id] ??
      _configuredEvmExplorerTemplate(chain, segment: 'tx');
  return _buildTemplateUri(template, hash);
}

Uri? _buildTemplateUri(String? template, String value) {
  if (template == null) return null;
  return Uri.parse(template.replaceAll('{value}', value));
}

String? _configuredEvmExplorerTemplate(
  WalletChainRef chain, {
  required String segment,
}) {
  if (chain is! WalletChainConfig) return null;
  final rawUrl = chain.explorerApiUrl?.trim() ?? '';
  final uri = Uri.tryParse(rawUrl);
  if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) return null;

  final lowerPath = uri.path.toLowerCase();
  final markerIndex = lowerPath.indexOf('/api/v2');
  if (uri.host.toLowerCase().contains('blockscout') || markerIndex >= 0) {
    final basePath = markerIndex >= 0
        ? uri.path.substring(0, markerIndex)
        : uri.path;
    final normalizedPath = basePath.replaceAll(RegExp(r'/+$'), '');
    return '${uri.scheme}://${uri.host}$normalizedPath/$segment/{value}';
  }

  final webHost = uri.host.startsWith('api.')
      ? uri.host.substring(4)
      : uri.host;
  if (!_looksLikeEvmScanHost(webHost)) return null;
  return '${uri.scheme}://$webHost/$segment/{value}';
}

bool _looksLikeEvmScanHost(String host) {
  final value = host.toLowerCase();
  return value.contains('etherscan.io') ||
      value.contains('bscscan.com') ||
      value.contains('arbiscan.io') ||
      value.contains('polygonscan.com') ||
      value.contains('snowtrace.io') ||
      value.contains('basescan.org') ||
      value.contains('optimistic.etherscan.io');
}
