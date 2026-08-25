import '../services/wallet_transfer_service.dart';
import 'chain_adapter_registry.dart';

final ChainAdapterRegistry _defaultChainAdapterRegistry =
    ChainAdapterRegistry.standard(
      ChainAddressNormalizers(
        evm: WalletTransferService.normalizeEvmAddress,
        tron: (input) {
          WalletTransferService.tronAddressToHex(input);
          return input.trim();
        },
        solana: WalletTransferService.normalizeSolanaAddress,
        bitcoin: WalletTransferService.normalizeBitcoinAddress,
        sui: WalletTransferService.normalizeSuiAddress,
        aptos: WalletTransferService.normalizeAptosAddress,
      ),
    );

/// 返回应用级共享的默认 ChainAdapter 注册表。
///
/// 独立测试或需要隔离注册内容的调用方应直接构造 [ChainAdapterRegistry]。
ChainAdapterRegistry createDefaultChainAdapterRegistry() {
  return _defaultChainAdapterRegistry;
}
