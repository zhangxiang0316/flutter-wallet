import '../../adapters/chain_adapter.dart';
import '../../adapters/chain_adapter_registry.dart';
import '../../adapters/default_chain_adapter_registry.dart';
import '../../models/chain_balance.dart';

/// 通过 ChainAdapter 构造地址和交易详情浏览器 URL。
class WalletBlockExplorerService {
  WalletBlockExplorerService({ChainAdapterRegistry? adapterRegistry})
    : _adapterRegistry = adapterRegistry ?? createDefaultChainAdapterRegistry();

  final ChainAdapterRegistry _adapterRegistry;

  Uri? addressUri(ChainBalance asset) {
    final adapter = _adapterRegistry.require(
      asset.chainRef,
      capability: ChainCapability.blockExplorer,
    );
    return adapter.addressExplorerUri(asset.chainRef, asset.address);
  }

  Uri? transactionUri(ChainBalance asset, String txHash) {
    final adapter = _adapterRegistry.require(
      asset.chainRef,
      capability: ChainCapability.blockExplorer,
    );
    return adapter.transactionExplorerUri(asset.chainRef, txHash);
  }
}
