import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/generated/l10n.dart';
import 'package:omnicast/page/home/controller/home_controller.dart';
import 'package:omnicast/page/home/view/widgets/password_setup_sheet.dart';
import 'package:omnicast/utils/sensitive_data_lifecycle.dart';

void main() {
  setUp(SensitiveDataLifecycle.reset);
  tearDown(SensitiveDataLifecycle.reset);

  testWidgets('shows wallet creation progress and prevents duplicate submit', (
    tester,
  ) async {
    final result = Completer<Object?>();
    var submitCount = 0;

    await tester.pumpWidget(
      _testApp(
        onSubmit: (_) {
          submitCount += 1;
          return result.future;
        },
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), '123456');
    await tester.enterText(fields.at(1), '123456');
    await tester.tap(find.widgetWithText(FilledButton, '创建钱包'));
    await tester.pump();

    expect(submitCount, 1);
    expect(
      find.byKey(const ValueKey('wallet-submitting-status')),
      findsOneWidget,
    );
    expect(find.text('正在创建钱包...'), findsNWidgets(2));
    expect(find.text('正在本机生成并加密钱包，请保持当前页面开启。'), findsOneWidget);
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.controller?.text, isEmpty);
    }

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    expect(submitCount, 1);

    result.complete(null);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('wallet-submitting-status')),
      findsNothing,
    );
    expect(find.byType(TextField), findsNWidgets(2));
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.controller?.text, isEmpty);
    }
  });

  testWidgets('clears a displayed mnemonic when the app becomes inactive', (
    tester,
  ) async {
    const mnemonic =
        'abandon ability able about above absent absorb abstract absurd abuse access accident';
    await tester.pumpWidget(
      _testApp(
        onSubmit: (_) async =>
            const CreatedWalletBackup(walletId: 'wallet-1', mnemonic: mnemonic),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '123456');
    await tester.enterText(fields.at(1), '123456');
    await tester.tap(find.widgetWithText(FilledButton, '创建钱包'));
    await tester.pumpAndSettle();

    expect(find.textContaining('abandon'), findsOneWidget);
    SensitiveDataLifecycle.clearAll();
    await tester.pumpAndSettle();

    expect(find.textContaining('abandon'), findsNothing);
    expect(find.byType(TextField), findsNWidgets(2));
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.controller?.text, isEmpty);
    }
  });

  testWidgets('does not reveal a mnemonic returned after lifecycle clearing', (
    tester,
  ) async {
    const mnemonic =
        'abandon ability able about above absent absorb abstract absurd abuse access accident';
    final result = Completer<Object?>();
    await tester.pumpWidget(_testApp(onSubmit: (_) => result.future));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '123456');
    await tester.enterText(fields.at(1), '123456');
    await tester.tap(find.widgetWithText(FilledButton, '创建钱包'));
    await tester.pump();
    await tester.pump();

    SensitiveDataLifecycle.clearAll();
    result.complete(
      const CreatedWalletBackup(walletId: 'wallet-1', mnemonic: mnemonic),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('abandon'), findsNothing);
  });
}

Widget _testApp({required Future<Object?> Function(String password) onSubmit}) {
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
        body: PasswordSetupSheet(
          title: '创建钱包',
          submitLabel: '创建钱包',
          submittingLabel: '正在创建钱包...',
          submittingHint: '正在本机生成并加密钱包，请保持当前页面开启。',
          isDismissible: true,
          validatePassword: (password, confirmation) {
            return password.length >= 6 && password == confirmation;
          },
          onSubmit: onSubmit,
        ),
      ),
    ),
  );
}
