import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/page/transfer/controller/transfer_controller.dart';
import 'package:omnicast/wallet/models/chain_balance.dart';
import 'package:omnicast/wallet/models/payment_request.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('does not change form until a cross-chain request is confirmed', () {
    final ethereumUsdc = _asset(
      chain: WalletChain.ethereum,
      symbol: 'USDC',
      contract: '0xA0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
    );
    final polygonNative = _asset(chain: WalletChain.polygon, symbol: 'POL');
    final polygonUsdc = _asset(
      chain: WalletChain.polygon,
      symbol: 'USDC',
      contract: '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359',
    );
    final controller = TransferController()
      ..availableAssets = [ethereumUsdc, polygonNative, polygonUsdc]
      ..selectedAsset = ethereumUsdc
      ..addressController.text = '0x1111111111111111111111111111111111111111'
      ..amountController.text = '3';
    addTearDown(controller.onClose);
    final payload = const PaymentRequest(
      scheme: 'omnicast',
      chainId: 'polygon',
      address: '0x2222222222222222222222222222222222222222',
      symbol: 'USDC',
      contractAddress: '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359',
      amount: '12.5',
      memo: 'invoice 42',
    ).toUri().toString();

    final resolution = controller.resolvePaymentRequest(payload);

    expect(resolution, isNotNull);
    expect(resolution!.requiresNetworkSwitch, isTrue);
    expect(resolution.requiresAssetSwitch, isFalse);
    expect(resolution.overwritesAmount, isTrue);
    expect(resolution.targetAsset, same(polygonUsdc));
    expect(controller.currentAsset, same(ethereumUsdc));
    expect(controller.amountController.text, '3');
    expect(
      controller.addressController.text,
      '0x1111111111111111111111111111111111111111',
    );

    controller.applyPaymentRequest(resolution);

    expect(controller.currentAsset, same(polygonUsdc));
    expect(controller.amountController.text, '12.5');
    expect(
      controller.addressController.text,
      '0x2222222222222222222222222222222222222222',
    );
    expect(controller.scannedPaymentMemo, 'invoice 42');
  });

  test('uses the contract to detect a same-chain token mismatch', () {
    final usdc = _asset(
      chain: WalletChain.ethereum,
      symbol: 'USDC',
      contract: '0xA0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
    );
    final usdt = _asset(
      chain: WalletChain.ethereum,
      symbol: 'USDT',
      contract: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
    );
    final controller = TransferController()
      ..availableAssets = [usdc, usdt]
      ..selectedAsset = usdc;
    addTearDown(controller.onClose);
    final payload = const PaymentRequest(
      scheme: 'omnicast',
      chainId: 'ethereum',
      address: '0x2222222222222222222222222222222222222222',
      symbol: 'USDC',
      contractAddress: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
    ).toUri().toString();

    final resolution = controller.resolvePaymentRequest(payload);

    expect(resolution?.requiresNetworkSwitch, isFalse);
    expect(resolution?.requiresAssetSwitch, isTrue);
    expect(resolution?.targetAsset, same(usdt));
    expect(controller.currentAsset, same(usdc));
  });
}

ChainBalance _asset({
  required WalletChain chain,
  required String symbol,
  String? contract,
}) {
  return ChainBalance(
    chain: chain,
    symbol: symbol,
    name: symbol,
    amount: '100',
    address: '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
    contractAddress: contract,
    decimals: contract == null ? 18 : 6,
  );
}
