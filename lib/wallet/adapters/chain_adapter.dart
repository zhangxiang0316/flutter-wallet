import '../models/wallet_account.dart';
import '../models/wallet_chain.dart';
import '../models/wallet_chain_extensions.dart';

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
  const ChainWalletAddresses({
    required this.evm,
    required this.tron,
    required this.solana,
    required this.bitcoin,
    required this.sui,
    required this.aptos,
  });

  factory ChainWalletAddresses.fromWallet(WalletAccount wallet) {
    return ChainWalletAddresses(
      evm: wallet.bscAddress,
      tron: wallet.tronAddress,
      solana: wallet.solanaAddress,
      bitcoin: wallet.bitcoinAddress,
      sui: wallet.suiAddress,
      aptos: wallet.aptosAddress,
    );
  }

  final String evm;
  final String tron;
  final String solana;
  final String bitcoin;
  final String sui;
  final String aptos;
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
/// RPC 读写仍由各业务服务负责，Adapter 统一解决链类型识别、钱包地址选择、
/// 地址校验和浏览器链接等跨服务路由问题。
abstract interface class ChainAdapter {
  WalletChainType get type;
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
    required this.type,
    required this.capabilities,
    this.balanceFallbackStrategy = ChainBalanceFallbackStrategy.genericAssets,
    this.presentationBuilder = _defaultPresentation,
    this.transferPolicyBuilder = _defaultTransferPolicyBuilder,
    required ChainWalletAddressSelector walletAddressSelector,
    required ChainAddressNormalizer addressNormalizer,
    ChainAddressExtractor addressExtractor = _identityAddressExtractor,
    required ChainExplorerUriBuilder addressExplorerBuilder,
    required ChainExplorerUriBuilder transactionExplorerBuilder,
  }) : _walletAddressSelector = walletAddressSelector,
       _addressNormalizer = addressNormalizer,
       _addressExtractor = addressExtractor,
       _addressExplorerBuilder = addressExplorerBuilder,
       _transactionExplorerBuilder = transactionExplorerBuilder;

  @override
  final WalletChainType type;

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

  final ChainWalletAddressSelector _walletAddressSelector;
  final ChainAddressNormalizer _addressNormalizer;
  final ChainAddressExtractor _addressExtractor;
  final ChainExplorerUriBuilder _addressExplorerBuilder;
  final ChainExplorerUriBuilder _transactionExplorerBuilder;

  @override
  bool supports(WalletChainRef chain) => chain.chainType == type;

  @override
  String walletAddress(ChainWalletAddresses addresses) {
    return _walletAddressSelector(addresses).trim();
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
