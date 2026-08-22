import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/generated/l10n.dart';
import 'package:omnicast/page/home/view/widgets/token_portfolio_section.dart';
import 'package:omnicast/wallet/services/chain_balance_cache.dart';

void main() {
  testWidgets('marks cached balances as stale after refresh failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        source: BalanceSnapshotSource.cache,
        status: BalanceRefreshStatus.failure,
        isStale: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('旧数据'), findsOneWidget);
    expect(find.textContaining('缓存数据'), findsOneWidget);
    expect(find.textContaining('更新于'), findsOneWidget);
    expect(find.textContaining('刷新失败'), findsOneWidget);
  });

  testWidgets('shows network source and successful refresh status', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        source: BalanceSnapshotSource.network,
        status: BalanceRefreshStatus.success,
        isStale: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('链上数据'), findsOneWidget);
    expect(find.textContaining('已是最新'), findsOneWidget);
    expect(find.textContaining('旧数据'), findsNothing);
  });
}

Widget _testApp({
  required BalanceSnapshotSource source,
  required BalanceRefreshStatus status,
  required bool isStale,
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
        body: TokenPortfolioSection(
          items: const [],
          isLoading: false,
          snapshotSource: source,
          refreshStatus: status,
          balanceAsOf: DateTime(2026, 8, 22, 12, 30),
          isStale: isStale,
          onTokenTap: (_) {},
        ),
      ),
    ),
  );
}
