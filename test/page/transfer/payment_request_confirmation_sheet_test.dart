import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/generated/l10n.dart';
import 'package:omnicast/page/transfer/controller/transfer_controller.dart';
import 'package:omnicast/page/transfer/view/widgets/payment_request_confirmation_sheet.dart';
import 'package:omnicast/wallet/adapters/default_chain_adapter_registry.dart';
import 'package:omnicast/wallet/models/chain_balance.dart';
import 'package:omnicast/wallet/models/payment_request.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/policies/chain_presentation_policy.dart';
import 'package:omnicast/widget/chain_presentation_scope.dart';

void main() {
  testWidgets('shows the current network before accepting a plain address', (
    tester,
  ) async {
    const asset = ChainBalance(
      chain: WalletChain.base,
      symbol: 'ETH',
      name: 'Ethereum',
      amount: '1',
      address: '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
      decimals: 18,
    );
    const resolution = PaymentRequestResolution(
      request: PaymentRequest(
        scheme: '',
        chainId: 'base',
        address: '0x2222222222222222222222222222222222222222',
        isPlainAddress: true,
      ),
      currentAsset: asset,
      targetAsset: asset,
      existingAmount: '',
    );

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => ChainPresentationScope(
          policy: ChainPresentationPolicy(createDefaultChainAdapterRegistry()),
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: const [
              S.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: S.delegate.supportedLocales,
            home: const Scaffold(
              body: PaymentRequestConfirmationSheet(resolution: resolution),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('核对付款请求'), findsOneWidget);
    expect(find.text('该二维码仅包含地址，将按照 Base 网络使用。'), findsOneWidget);
    expect(find.text('Base'), findsOneWidget);
    expect(find.text('使用该请求'), findsOneWidget);
  });
}
