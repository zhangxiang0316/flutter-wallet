import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/generated/l10n.dart';
import 'package:omnicast/page/transfer/controller/transfer_controller.dart';
import 'package:omnicast/page/transfer/view/widgets/transfer_fee_panel.dart';
import 'package:omnicast/wallet/models/chain_balance.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/services/wallet_transfer_service.dart';

void main() {
  testWidgets('shows the selected L2 network while keeping ETH as gas token', (
    tester,
  ) async {
    final controller = TransferController()
      ..feeEstimate = TransferFeeEstimate(
        amount: '0.000021',
        symbol: 'ETH',
        rawAmount: BigInt.from(21000000000000),
      );
    addTearDown(controller.onClose);

    await tester.pumpWidget(_app(_asset(WalletChain.base), controller));
    await tester.pumpAndSettle();

    expect(find.text('Base 预计网络手续费'), findsOneWidget);
    expect(find.text('0.000021 ETH'), findsOneWidget);
    expect(find.text('Base 网络使用 ETH 支付手续费。'), findsOneWidget);

    await tester.pumpWidget(_app(_asset(WalletChain.arbitrum), controller));
    await tester.pumpAndSettle();

    expect(find.text('Arbitrum 预计网络手续费'), findsOneWidget);
    expect(find.text('0.000021 ETH'), findsOneWidget);
    expect(find.text('Arbitrum 网络使用 ETH 支付手续费。'), findsOneWidget);
    expect(find.text('Base 预计网络手续费'), findsNothing);
  });
}

Widget _app(ChainBalance asset, TransferController controller) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, _) => MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: const [
        S.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: Scaffold(
        body: TransferFeePanel(asset: asset, controller: controller),
      ),
    ),
  );
}

ChainBalance _asset(WalletChain chain) {
  return ChainBalance(
    chain: chain,
    symbol: 'USDC',
    name: 'USD Coin',
    amount: '10',
    address: '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
    contractAddress: chain == WalletChain.base
        ? '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'
        : '0xaf88d065e77c8C2239327C5EDb3A432268e5831',
    decimals: 6,
  );
}
