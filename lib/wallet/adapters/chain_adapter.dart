import '../models/wallet_account.dart';
import '../models/wallet_chain.dart';

/// 链适配器可声明的业务能力。
enum ChainCapability {
  walletAddressResolution,
  addressValidation,
  balance,
  transfer,
  feeEstimation,
  history,
  transactionStatus,
  receive,
  blockExplorer,
  customNetworks,
  customAssets,
  paymentUri,
  rpcHealth,
}

/// 余额查询失败时的链特有兜底策略。
enum ChainBalanceFallbackStrategy { genericAssets, solanaOwnerTokenLookup }

/// 链在页面层使用的非业务展示元数据。
class ChainPresentation {
  const ChainPresentation({
    required this.colorValue,
    required this.label,
    required this.addressHint,
  });

  final int colorValue;
  final String label;
  final String addressHint;
}

/// 一类链当前已经接入的能力集合。
class ChainCapabilities {
  const ChainCapabilities(this.values);

  final Set<ChainCapability> values;

  bool supports(ChainCapability capability) => values.contains(capability);
}

/// 不依赖具体钱包模型的多链地址集合。
class ChainWalletAddresses {
  const ChainWalletAddresses(this.byNamespace);

  factory ChainWalletAddresses.fromWallet(WalletAccount wallet) {
    return ChainWalletAddresses(wallet.addressesByNamespace);
  }

  final Map<String, String> byNamespace;

  String addressFor(String namespace) => byNamespace[namespace]?.trim() ?? '';

  String get evm => addressFor(WalletAddressNamespace.evm);
  String get tron => addressFor(WalletAddressNamespace.tron);
  String get solana => addressFor(WalletAddressNamespace.solana);
  String get bitcoin => addressFor(WalletAddressNamespace.bitcoin);
  String get sui => addressFor(WalletAddressNamespace.sui);
  String get aptos => addressFor(WalletAddressNamespace.aptos);
}

typedef ChainAddressNormalizer = String Function(String input);
typedef ChainAddressExtractor = String? Function(String input);
typedef ChainWalletAddressSelector =
    String Function(ChainWalletAddresses addresses);
typedef ChainExplorerUriBuilder =
    Uri? Function(WalletChainRef chain, String value);
typedef ChainBurnAddressMatcher = bool Function(String input);

/// 转账确认页使用的链规则，避免页面直接依赖具体链类型。
class ChainTransferPolicy {
  const ChainTransferPolicy({
    required this.caseInsensitiveAddress,
    required this.requiresNetworkConfirmation,
    required this.isBurnAddress,
  });

  final bool caseInsensitiveAddress;
  final bool requiresNetworkConfirmation;
  final ChainBurnAddressMatcher isBurnAddress;
}

bool _neverBurnAddress(String input) => false;

const _defaultTransferPolicy = ChainTransferPolicy(
  caseInsensitiveAddress: false,
  requiresNetworkConfirmation: false,
  isBurnAddress: _neverBurnAddress,
);

ChainTransferPolicy _defaultTransferPolicyBuilder(WalletChainRef chain) =>
    _defaultTransferPolicy;

String? _identityAddressExtractor(String input) => input;

ChainPresentation _defaultPresentation(WalletChainRef chain) {
  return const ChainPresentation(
    colorValue: 0xFF2563EB,
    label: '?',
    addressHint: 'Address',
  );
}

/// 单类链的统一能力入口。
///
/// Adapter 统一声明链识别、钱包地址、密钥材料、页面 capability 和浏览器策略；
/// 链上操作实现由同一 adapterId 注册到类型安全的 `ChainOperationRegistry`。
abstract interface class ChainAdapter {
  String get id;
  WalletChainType get type;
  String get addressNamespace;
  String get keyMaterialNamespace;
  Set<String> get paymentUriSchemes;
  ChainCapabilities get capabilities;
  ChainBalanceFallbackStrategy get balanceFallbackStrategy;
  ChainPresentation presentation(WalletChainRef chain);
  ChainTransferPolicy transferPolicy(WalletChainRef chain);

  bool supports(WalletChainRef chain);
  String walletAddress(ChainWalletAddresses addresses);
  String normalizeAddress(String input);

  /// Extracts a single address from arbitrary text (for QR/scanner input).
  String? extractAddress(String input);
  Uri? addressExplorerUri(WalletChainRef chain, String address);
  Uri? transactionExplorerUri(WalletChainRef chain, String txHash);
}

/// 使用注册回调组装的标准链适配器。
class RegisteredChainAdapter implements ChainAdapter {
  const RegisteredChainAdapter({
    String? id,
    required this.type,
    required this.addressNamespace,
    String? keyMaterialNamespace,
    this.paymentUriSchemes = const {},
    required this.capabilities,
    this.balanceFallbackStrategy = ChainBalanceFallbackStrategy.genericAssets,
    this.presentationBuilder = _defaultPresentation,
    this.transferPolicyBuilder = _defaultTransferPolicyBuilder,
    ChainWalletAddressSelector? walletAddressSelector,
    required ChainAddressNormalizer addressNormalizer,
    ChainAddressExtractor addressExtractor = _identityAddressExtractor,
    required ChainExplorerUriBuilder addressExplorerBuilder,
    required ChainExplorerUriBuilder transactionExplorerBuilder,
  }) : _id = id,
       _keyMaterialNamespace = keyMaterialNamespace,
       _walletAddressSelector = walletAddressSelector,
       _addressNormalizer = addressNormalizer,
       _addressExtractor = addressExtractor,
       _addressExplorerBuilder = addressExplorerBuilder,
       _transactionExplorerBuilder = transactionExplorerBuilder;

  final String? _id;

  @override
  String get id => _id ?? type.name;

  @override
  final WalletChainType type;

  @override
  final String addressNamespace;

  final String? _keyMaterialNamespace;

  @override
  String get keyMaterialNamespace => _keyMaterialNamespace ?? addressNamespace;

  @override
  final Set<String> paymentUriSchemes;

  @override
  final ChainCapabilities capabilities;

  @override
  final ChainBalanceFallbackStrategy balanceFallbackStrategy;
  final ChainPresentation Function(WalletChainRef chain) presentationBuilder;
  final ChainTransferPolicy Function(WalletChainRef chain)
  transferPolicyBuilder;

  @override
  ChainPresentation presentation(WalletChainRef chain) =>
      presentationBuilder(chain);

  @override
  ChainTransferPolicy transferPolicy(WalletChainRef chain) =>
      transferPolicyBuilder(chain);

  final ChainWalletAddressSelector? _walletAddressSelector;
  final ChainAddressNormalizer _addressNormalizer;
  final ChainAddressExtractor _addressExtractor;
  final ChainExplorerUriBuilder _addressExplorerBuilder;
  final ChainExplorerUriBuilder _transactionExplorerBuilder;

  @override
  bool supports(WalletChainRef chain) => chain.adapterId == id;

  @override
  String walletAddress(ChainWalletAddresses addresses) {
    return (_walletAddressSelector?.call(addresses) ??
            addresses.addressFor(addressNamespace))
        .trim();
  }

  @override
  String normalizeAddress(String input) => _addressNormalizer(input);

  @override
  String? extractAddress(String input) => _addressExtractor(input);

  @override
  Uri? addressExplorerUri(WalletChainRef chain, String address) {
    final value = address.trim();
    if (value.isEmpty || !supports(chain)) return null;
    return _addressExplorerBuilder(chain, value);
  }

  @override
  Uri? transactionExplorerUri(WalletChainRef chain, String txHash) {
    final value = txHash.trim();
    if (value.isEmpty || !supports(chain)) return null;
    return _transactionExplorerBuilder(chain, value);
  }
}
