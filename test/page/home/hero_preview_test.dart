import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/common/theme/app_theme_extension.dart';
import 'package:omnicast/generated/l10n.dart';
import 'package:omnicast/page/home/view/widgets/wallet_overview_card.dart';
import 'package:omnicast/wallet/models/wallet_account.dart';

final _wallet = WalletAccount(
  id: 'w1',
  name: 'Main Wallet',
  bscAddress: '0x1234567890abcdef1234567890abcdef12345678',
  tronAddress: 'TXYZ1234567890',
  createdAt: DateTime(2026, 1, 1),
);

Future<void> _loadFont() async {
  final flutterRoot = _flutterRoot();
  await _loadFamily(
    'TestRoboto',
    '$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
  );
  await _loadFamily(
    'MaterialIcons',
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
}

String _flutterRoot() {
  final configuredRoot = Platform.environment['FLUTTER_ROOT'];
  if (configuredRoot != null && configuredRoot.isNotEmpty) {
    return configuredRoot;
  }

  var directory = File(Platform.resolvedExecutable).parent;
  for (var index = 0; index < 4; index++) {
    directory = directory.parent;
  }
  return directory.path;
}

Future<void> _loadFamily(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(bytes.buffer.asByteData()));
  await loader.load();
}

Widget _app({required Brightness brightness}) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    minTextAdapt: true,
    fontSizeResolver: (fontSize, screenUtil) {
      final baseSize = screenUtil.setWidth(fontSize);
      return baseSize * (fontSize >= 12 ? 0.86 : 0.95);
    },
    builder: (_, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en'),
      localizationsDelegates: const [
        S.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: S.delegate.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        brightness: brightness,
        fontFamily: 'TestRoboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: brightness,
          primary: Colors.blue,
          onPrimary: brightness == Brightness.dark
              ? Colors.black
              : Colors.white,
        ),
        extensions: <ThemeExtension<dynamic>>[
          brightness == Brightness.dark
              ? AppThemeExtension.dark()
              : AppThemeExtension.light(),
        ],
      ),
      home: Scaffold(
        backgroundColor: brightness == Brightness.dark
            ? const Color(0xFF121212)
            : const Color(0xFFF7F8FA),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: WalletOverviewCard(
            wallet: _wallet,
            wallets: [_wallet],
            totalAssetsText: r'$1234567.89',
            onWalletSelected: (_) {},
            onWalletRemoved: (_) async {},
            onAddWallet: () {},
            onReceivePressed: () {},
            onTransferPressed: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('hero card light', (tester) async {
    await _loadFont();
    tester.view.physicalSize = const Size(1125, 900);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(brightness: Brightness.light));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(WalletOverviewCard),
      matchesGoldenFile('goldens/hero_light.png'),
    );
  });

  testWidgets('hero card dark', (tester) async {
    await _loadFont();
    tester.view.physicalSize = const Size(1125, 900);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(brightness: Brightness.dark));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(WalletOverviewCard),
      matchesGoldenFile('goldens/hero_dark.png'),
    );
  });
}
