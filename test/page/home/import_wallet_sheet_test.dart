import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/generated/l10n.dart';
import 'package:omnicast/page/home/view/widgets/import_wallet_sheet.dart';
import 'package:omnicast/utils/sensitive_data_lifecycle.dart';

void main() {
  setUp(SensitiveDataLifecycle.reset);
  tearDown(SensitiveDataLifecycle.reset);

  testWidgets('copies submit values then immediately clears every input', (
    tester,
  ) async {
    final result = Completer<bool>();
    String? submittedMnemonic;
    String? submittedPassword;
    await tester.pumpWidget(
      _testApp(
        onMnemonicSubmit: (mnemonic, password) {
          submittedMnemonic = mnemonic;
          submittedPassword = password;
          return result.future;
        },
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'word one two three');
    await tester.enterText(fields.at(1), '123456');
    await tester.enterText(fields.at(2), '123456');
    await tester.tap(find.widgetWithText(FilledButton, '确认导入'));
    await tester.pump();
    await tester.pump();

    expect(submittedMnemonic, 'word one two three');
    expect(submittedPassword, '123456');
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.controller?.text, isEmpty);
    }

    result.complete(false);
    await tester.pumpAndSettle();
  });

  testWidgets('clears secret and passwords when the app becomes inactive', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(onMnemonicSubmit: (_, _) async => false));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'secret mnemonic');
    await tester.enterText(fields.at(1), '123456');
    await tester.enterText(fields.at(2), '123456');

    SensitiveDataLifecycle.clearAll();
    await tester.pump();

    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.controller?.text, isEmpty);
    }
  });

  testWidgets('does not start import after lifecycle clearing the form', (
    tester,
  ) async {
    var submitCount = 0;
    await tester.pumpWidget(
      _testApp(
        onMnemonicSubmit: (_, _) async {
          submitCount++;
          return false;
        },
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'secret mnemonic');
    await tester.enterText(fields.at(1), '123456');
    await tester.enterText(fields.at(2), '123456');
    await tester.tap(find.widgetWithText(FilledButton, '确认导入'));
    SensitiveDataLifecycle.clearAll();
    await tester.pumpAndSettle();

    expect(submitCount, 0);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}

Widget _testApp({
  required Future<bool> Function(String mnemonic, String password)
  onMnemonicSubmit,
}) {
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
        body: ImportWalletSheet(
          validatePassword: (password, confirmation) {
            return password.length >= 6 && password == confirmation;
          },
          onMnemonicSubmit: onMnemonicSubmit,
          onPrivateKeySubmit: (_, _) async => false,
        ),
      ),
    ),
  );
}
