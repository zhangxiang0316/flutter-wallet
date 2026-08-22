import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/page/receive/controller/receive_controller.dart';
import 'package:omnicast/page/transfer/controller/transfer_scan_address_parser.dart';
import 'package:omnicast/wallet/models/wallet_account.dart';
import 'package:omnicast/wallet/models/wallet_asset.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('creates a chain-aware QR payload with optional details', () {
    final asset = WalletAssetRegistry.polygonAssets.firstWhere(
      (item) => item.symbol == 'USDC',
    );
    final controller = ReceiveController()
      ..wallet = WalletAccount(
        id: 'wallet-1',
        name: 'Wallet',
        bscAddress: '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        tronAddress: 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
        createdAt: DateTime(2026),
      )
      ..selectedChain = WalletChain.polygon.config
      ..selectedAsset = asset
      ..amountController.text = '12.5'
      ..memoController.text = 'invoice 42';
    addTearDown(controller.onClose);

    final payload = controller.currentQrPayload();
    final request = TransferScanAddressParser.parse(
      payload,
      WalletChain.ethereum.config,
    );

    expect(payload, startsWith('omnicast://receive?'));
    expect(request?.chainId, WalletChain.polygon.id);
    expect(request?.symbol, 'USDC');
    expect(request?.contractAddress, asset.contractAddress);
    expect(request?.amount, '12.5');
    expect(request?.memo, 'invoice 42');
  });

  test('keeps an empty payment request compatible as a plain address', () {
    const address = '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf';
    final controller = ReceiveController()
      ..wallet = WalletAccount(
        id: 'wallet-1',
        name: 'Wallet',
        bscAddress: address,
        tronAddress: 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
        createdAt: DateTime(2026),
      )
      ..selectedChain = WalletChain.polygon.config
      ..selectedAsset = WalletAssetRegistry.polygonAssets.first;
    addTearDown(controller.onClose);

    expect(controller.currentQrPayload(), address);
  });

  test('does not generate a request for an invalid asset amount', () {
    final controller = ReceiveController()
      ..wallet = WalletAccount(
        id: 'wallet-1',
        name: 'Wallet',
        bscAddress: '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        tronAddress: 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
        createdAt: DateTime(2026),
      )
      ..selectedChain = WalletChain.polygon.config
      ..selectedAsset = WalletAssetRegistry.polygonAssets.firstWhere(
        (item) => item.symbol == 'USDC',
      )
      ..amountController.text = '0.0000001';
    addTearDown(controller.onClose);

    expect(controller.isRequestAmountValid, isFalse);
    expect(controller.currentQrPayload(), isEmpty);
  });

  test('selects receive addresses through registered chain adapters', () {
    final controller = ReceiveController()
      ..wallet = WalletAccount(
        id: 'wallet-1',
        name: 'Wallet',
        bscAddress: 'evm-address',
        tronAddress: 'tron-address',
        solanaAddress: 'solana-address',
        bitcoinAddress: 'bitcoin-address',
        suiAddress: 'sui-address',
        aptosAddress: 'aptos-address',
        createdAt: DateTime(2026),
      );
    addTearDown(controller.onClose);
    final expected = <WalletChain, String>{
      WalletChain.ethereum: 'evm-address',
      WalletChain.tron: 'tron-address',
      WalletChain.solana: 'solana-address',
      WalletChain.bitcoin: 'bitcoin-address',
      WalletChain.sui: 'sui-address',
      WalletChain.aptos: 'aptos-address',
    };

    for (final entry in expected.entries) {
      controller.selectedChain = entry.key.config;
      expect(controller.currentAddress(), entry.value);
    }
  });
}
