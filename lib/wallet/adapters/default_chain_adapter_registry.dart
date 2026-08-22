import '../services/wallet_transfer_service.dart';
import 'chain_adapter_registry.dart';

/// 创建应用默认 ChainAdapter 注册表。
ChainAdapterRegistry createDefaultChainAdapterRegistry() {
  return ChainAdapterRegistry.standard(
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
}
