import 'package:decimal/decimal.dart';

import '../../../wallet/models/chain_balance.dart';
import '../../../wallet/models/wallet_chain_extensions.dart';
import '../../../wallet/services/wallet_transfer_service.dart';

class TransferInputValidator {
  const TransferInputValidator._();

  static void validateAddress(ChainBalance asset, String address) {
    if (asset.chainRef.isEvm) {
      WalletTransferService.normalizeEvmAddress(address);
      return;
    }
    if (asset.chainRef.isTron) {
      WalletTransferService.tronAddressToHex(address);
      return;
    }
    if (asset.chainRef.isSolana) {
      WalletTransferService.normalizeSolanaAddress(address);
      return;
    }
    if (asset.chainRef.isBitcoin) {
      WalletTransferService.normalizeBitcoinAddress(address);
      return;
    }
    if (asset.chainRef.isSui) {
      WalletTransferService.normalizeSuiAddress(address);
      return;
    }
    throw FormatException('Unsupported chain ${asset.chainId}');
  }

  static bool canEstimateFee({
    required ChainBalance asset,
    required String address,
    required String amount,
  }) {
    WalletTransferService.amountToRawUnits(amount, asset.decimals);
    validateAddress(asset, address);

    final amountDecimal = Decimal.parse(amount);
    final balanceDecimal = Decimal.parse(asset.amount);
    return amountDecimal <= balanceDecimal;
  }
}
