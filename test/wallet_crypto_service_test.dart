import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/chain_balance.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/services/asset_valuation_service.dart';
import 'package:omnicast/wallet/services/chain_balance_service.dart';
import 'package:omnicast/wallet/services/wallet_crypto_service.dart';
import 'package:omnicast/wallet/services/wallet_transfer_service.dart';

void main() {
  group('WalletCryptoService', () {
    late WalletCryptoService service;

    setUp(() {
      service = WalletCryptoService();
    });

    test('derives BSC and TRON addresses from a private key', () {
      final keyPair = service.importPrivateKey(
        '0x0000000000000000000000000000000000000000000000000000000000000001',
      );

      expect(keyPair.bscAddress, '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf');
      expect(keyPair.tronAddress, 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC');
    });

    test('rejects malformed private keys', () {
      expect(() => service.importPrivateKey('abc'), throwsFormatException);
      expect(
        () => service.importPrivateKey(
          '0x0000000000000000000000000000000000000000000000000000000000000000',
        ),
        throwsFormatException,
      );
    });
  });

  group('ChainBalanceService', () {
    test('encodes ERC20 balanceOf calls', () {
      expect(
        ChainBalanceService.erc20BalanceOfData(
          '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        ),
        '0x70a082310000000000000000000000007e5f4552091a69125d5dfcb7b8c2659029395bdf',
      );
    });
  });

  group('AssetValuationService', () {
    late AssetValuationService service;

    setUp(() {
      service = AssetValuationService();
    });

    test('calculates total value from stable assets and injected prices', () {
      final total = service.calculateTotalUsdValue(
        const [
          ChainBalance(
            chain: WalletChain.bsc,
            symbol: 'USDT',
            name: 'Tether USD',
            amount: '10.25',
            address: '0x1',
          ),
          ChainBalance(
            chain: WalletChain.tron,
            symbol: 'USDC',
            name: 'USD Coin',
            amount: '5',
            address: 'T1',
          ),
          ChainBalance(
            chain: WalletChain.bsc,
            symbol: 'BNB',
            name: 'BNB',
            amount: '2',
            address: '0x1',
          ),
        ],
        prices: {'BNB': Decimal.parse('300')},
      );

      expect(total?.toStringAsFixed(2), '615.25');
      expect(service.formatUsdValue(total), r'$615.25');
    });

    test('uses stable coin prices without external price data', () {
      final total = service.calculateTotalUsdValue(const [
        ChainBalance(
          chain: WalletChain.bsc,
          symbol: 'USDT',
          name: 'Tether USD',
          amount: '0',
          address: '0x1',
        ),
      ]);

      expect(service.formatUsdValue(total), r'$0.00');
    });

    test('returns null when no asset has a known USD price', () {
      final total = service.calculateTotalUsdValue(const [
        ChainBalance(
          chain: WalletChain.bsc,
          symbol: 'UNKNOWN',
          name: 'Unknown Token',
          amount: '100',
          address: '0x1',
        ),
      ]);

      expect(total, isNull);
      expect(service.formatUsdValue(total), '--');
    });
  });

  group('WalletTransferService', () {
    test('converts decimal amounts to raw units', () {
      expect(
        WalletTransferService.amountToRawUnits('1.25', 18).toString(),
        '1250000000000000000',
      );
      expect(
        WalletTransferService.amountToRawUnits('0.000001', 6).toString(),
        '1',
      );
      expect(
        () => WalletTransferService.amountToRawUnits('0.0000001', 6),
        throwsFormatException,
      );
    });

    test('formats raw fee units for display', () {
      expect(
        WalletTransferService.rawUnitsToAmount(
          BigInt.from(21000) * BigInt.from(3000000000),
          18,
        ),
        '0.000063',
      );
      expect(
        WalletTransferService.rawUnitsToAmount(BigInt.from(30000000), 6),
        '30',
      );
    });

    test('encodes ERC20 transfer data', () {
      expect(
        WalletTransferService.erc20TransferData(
          '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
          BigInt.from(1000000),
        ),
        '0xa9059cbb0000000000000000000000007e5f4552091a69125d5dfcb7b8c2659029395bdf00000000000000000000000000000000000000000000000000000000000f4240',
      );
    });

    test('encodes TRC20 transfer parameters', () {
      expect(
        WalletTransferService.trc20TransferParameter(
          'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
          BigInt.from(1000000),
        ),
        '0000000000000000000000007e5f4552091a69125d5dfcb7b8c2659029395bdf00000000000000000000000000000000000000000000000000000000000f4240',
      );
    });
  });
}
