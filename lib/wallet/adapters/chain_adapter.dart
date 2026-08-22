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
typedef ChainWalletAddressSelector =
    String Function(ChainWalletAddresses addresses);
typedef ChainExplorerUriBuilder =
    Uri? Function(WalletChainRef chain, String value);

/// 单类链的统一能力入口。
///
/// RPC 读写仍由各业务服务负责，Adapter 统一解决链类型识别、钱包地址选择、
/// 地址校验和浏览器链接等跨服务路由问题。
abstract interface class ChainAdapter {
  WalletChainType get type;
  ChainCapabilities get capabilities;

  bool supports(WalletChainRef chain);
  String walletAddress(ChainWalletAddresses addresses);
  String normalizeAddress(String input);
  Uri? addressExplorerUri(WalletChainRef chain, String address);
  Uri? transactionExplorerUri(WalletChainRef chain, String txHash);
}

/// 使用注册回调组装的标准链适配器。
class RegisteredChainAdapter implements ChainAdapter {
  const RegisteredChainAdapter({
    required this.type,
    required this.capabilities,
    required ChainWalletAddressSelector walletAddressSelector,
    required ChainAddressNormalizer addressNormalizer,
    required ChainExplorerUriBuilder addressExplorerBuilder,
    required ChainExplorerUriBuilder transactionExplorerBuilder,
  }) : _walletAddressSelector = walletAddressSelector,
       _addressNormalizer = addressNormalizer,
       _addressExplorerBuilder = addressExplorerBuilder,
       _transactionExplorerBuilder = transactionExplorerBuilder;

  @override
  final WalletChainType type;

  @override
  final ChainCapabilities capabilities;

  final ChainWalletAddressSelector _walletAddressSelector;
  final ChainAddressNormalizer _addressNormalizer;
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
