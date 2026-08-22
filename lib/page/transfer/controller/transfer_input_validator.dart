import '../../../wallet/adapters/chain_adapter.dart';
import '../../../wallet/adapters/default_chain_adapter_registry.dart';
import '../../../wallet/models/chain_balance.dart';
import '../../../wallet/services/wallet_transfer_service.dart';

class TransferInputValidator {
  const TransferInputValidator._();

  static void validateAddress(ChainBalance asset, String address) {
    createDefaultChainAdapterRegistry()
        .require(asset.chainRef, capability: ChainCapability.addressValidation)
        .normalizeAddress(address);
  }

  static bool canEstimateFee({
    required ChainBalance asset,
    required String address,
    required String amount,
  }) {
    WalletTransferService.amountToRawUnits(amount, asset.decimals);
    validateAddress(asset, address);

    return true;
  }
}
