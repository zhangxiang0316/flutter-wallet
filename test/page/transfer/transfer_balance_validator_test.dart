import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/page/transfer/controller/transfer_balance_validator.dart';
import 'package:omnicast/wallet/models/chain_balance.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/services/wallet_transfer_service.dart';

void main() {
  group('TransferBalanceValidator', () {
    test('accepts native transfer when amount plus fee equals balance', () {
      final asset = _native(amount: '1');

      final result = TransferBalanceValidator.validate(
        asset: asset,
        nativeAsset: asset,
        amount: '0.99979',
        feeEstimate: _fee('0.00021'),
      );

      expect(result.isValid, isTrue);
    });

    test('rejects native transfer when amount leaves no room for fee', () {
      final asset = _native(amount: '1');

      final result = TransferBalanceValidator.validate(
        asset: asset,
        nativeAsset: asset,
        amount: '1',
        feeEstimate: _fee('0.00021'),
      );

      expect(
        result.failure,
        TransferBalanceFailure.insufficientNativeFeeBalance,
      );
    });

    test('distinguishes transfer amount greater than asset balance', () {
      final asset = _native(amount: '1');

      final result = TransferBalanceValidator.validate(
        asset: asset,
        nativeAsset: asset,
        amount: '1.000000000000000001',
        feeEstimate: _fee('0.00021'),
      );

      expect(result.failure, TransferBalanceFailure.insufficientAssetBalance);
    });

    test('checks token balance and native fee balance independently', () {
      final token = _token(amount: '10');
      final native = _native(amount: '0.0001');

      final tokenFailure = TransferBalanceValidator.validate(
        asset: token,
        nativeAsset: native,
        amount: '10.000001',
        feeEstimate: _fee('0.00021'),
      );
      final feeFailure = TransferBalanceValidator.validate(
        asset: token,
        nativeAsset: native,
        amount: '10',
        feeEstimate: _fee('0.00021'),
      );

      expect(
        tokenFailure.failure,
        TransferBalanceFailure.insufficientAssetBalance,
      );
      expect(
        feeFailure.failure,
        TransferBalanceFailure.insufficientNativeFeeBalance,
      );
    });

    test('rejects unavailable balances and missing fee estimates', () {
      final failedToken = _token(amount: '0', error: 'rpc failed');
      final native = _native(amount: '1');

      expect(
        TransferBalanceValidator.validate(
          asset: failedToken,
          nativeAsset: native,
          amount: '1',
          feeEstimate: _fee('0.00021'),
        ).failure,
        TransferBalanceFailure.assetBalanceUnavailable,
      );
      expect(
        TransferBalanceValidator.validate(
          asset: _token(amount: '1'),
          nativeAsset: native,
          amount: '1',
          feeEstimate: null,
        ).failure,
        TransferBalanceFailure.feeUnavailable,
      );
    });

    test('calculates safe maximum for native and complete token balance', () {
      final nativeMax = TransferBalanceValidator.maximumTransferAmount(
        asset: _native(amount: '1'),
        feeEstimate: _fee('0.00021'),
      );
      final tokenMax = TransferBalanceValidator.maximumTransferAmount(
        asset: _token(amount: '1.123456789123', decimals: 18),
        feeEstimate: null,
      );

      expect(nativeMax.amount, '0.99979');
      expect(tokenMax.amount, '1.123456789123');
    });

    test('converts zero and full-precision balances to raw units', () {
      expect(TransferBalanceValidator.balanceToRawUnits('0', 18), BigInt.zero);
      expect(
        TransferBalanceValidator.balanceToRawUnits('1.000001', 6),
        BigInt.from(1000001),
      );
    });
  });
}

ChainBalance _native({required String amount, String? error}) {
  return ChainBalance(
    chain: WalletChain.ethereum,
    symbol: 'ETH',
    name: 'Ethereum',
    amount: amount,
    address: '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
    decimals: 18,
    error: error,
  );
}

ChainBalance _token({required String amount, String? error, int decimals = 6}) {
  return ChainBalance(
    chain: WalletChain.ethereum,
    symbol: 'USDC',
    name: 'USD Coin',
    amount: amount,
    address: '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
    contractAddress: '0xA0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
    decimals: decimals,
    error: error,
  );
}

TransferFeeEstimate _fee(String amount) {
  return TransferFeeEstimate(
    amount: amount,
    symbol: 'ETH',
    rawAmount: WalletTransferService.amountToRawUnits(amount, 18),
  );
}
