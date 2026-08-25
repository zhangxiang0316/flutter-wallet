import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/page/setting/view/widgets/selection_check.dart';

void main() {
  testWidgets('uses the bundled Material check icon when selected', (
    tester,
  ) async {
    const primaryColor = Color(0xFF246BFD);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
          ),
          home: const Scaffold(body: SelectionCheck(selected: true)),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.check_rounded));
    expect(
      icon.color,
      Theme.of(tester.element(find.byType(Icon))).colorScheme.primary,
    );
  });

  testWidgets('reserves its slot without drawing an icon when unselected', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => const MaterialApp(
          home: Scaffold(body: SelectionCheck(selected: false)),
        ),
      ),
    );

    expect(find.byType(SelectionCheck), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });
}
