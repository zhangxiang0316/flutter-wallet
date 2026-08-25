import '../adapters/chain_adapter.dart';
import '../adapters/chain_adapter_registry.dart';
import '../models/wallet_chain.dart';

/// 页面展示和确认交互所需的只读链策略门面。
///
/// UI 只能读取链展示信息、转账确认规则和地址文本解析能力，不直接持有完整
/// [ChainAdapterRegistry]，从而避免页面自行创建或修改 Adapter 注册表。
class ChainPresentationPolicy {
  const ChainPresentationPolicy(this._registry);

  final ChainAdapterRegistry _registry;

  ChainPresentation presentation(WalletChainRef chain) {
    return _registry.require(chain).presentation(chain);
  }

  ChainTransferPolicy transferPolicy(WalletChainRef chain) {
    return _registry.require(chain).transferPolicy(chain);
  }

  String? extractAddress(WalletChainRef chain, String input) {
    return _registry.require(chain).extractAddress(input);
  }

  bool isValidAddress(WalletChainRef chain, String input) {
    try {
      _registry
          .require(chain, capability: ChainCapability.addressValidation)
          .normalizeAddress(input);
      return true;
    } catch (_) {
      return false;
    }
  }
}
