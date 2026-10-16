import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rich_together/core/database/database.dart';
import 'package:rich_together/core/localization/translations_en.dart';
import 'package:rich_together/core/localization/translations_id.dart';
import 'package:rich_together/core/models/enums.dart';
import 'package:rich_together/core/providers/locale_provider.dart';
import 'package:rich_together/core/providers/profile_provider.dart';
import 'package:rich_together/features/investments/domain/investment_math.dart';
import 'package:rich_together/features/investments/presentation/widgets/investment_allocation_chart.dart';
import 'package:rich_together/features/investments/presentation/widgets/investment_chart_carousel.dart';
import 'package:rich_together/features/investments/presentation/widgets/investment_value_chart.dart';
import 'package:rich_together/shared/theme/app_theme_mode.dart';
import 'package:rich_together/shared/theme/theme_provider_widget.dart';

const _jt = 1000000.0;

InvestmentAsset _asset(int id, String name, AssetType type) {
  final now = DateTime(2026, 1, 1);
  return InvestmentAsset(
    id: id,
    profileId: 1,
    name: name,
    assetType: type,
    currency: Currency.idr,
    isArchived: false,
    createdAt: now,
    updatedAt: now,
    isSynced: false,
  );
}

InvestmentSnapshot _snap(
  int id,
  int assetId,
  DateTime date,
  double value, {
  double contribution = 0,
}) {
  return InvestmentSnapshot(
    id: id,
    profileId: 1,
    assetId: assetId,
    snapshotDate: date,
    value: value,
    contribution: contribution,
    fxRateToBase: 1,
    baseCurrency: Currency.idr,
    createdAt: date,
    isSynced: false,
  );
}

/// Stock 52jt on 40jt invested (+30%), gold 28jt on 40jt (-30%), over three
/// dates so the value chart has enough points to draw.
InvestmentSummary _summary() {
  final sept = DateTime(2026, 9, 13);
  final oct = DateTime(2026, 10, 12);
  final nov = DateTime(2026, 11, 10);
  return buildInvestmentSummary(
    assets: [
      _asset(1, 'BBCA', AssetType.stock),
      _asset(2, 'A very long asset name that has to ellipsize', AssetType.stock),
      _asset(3, 'Gold bar', AssetType.gold),
    ],
    snapshots: [
      _snap(1, 1, sept, 20 * _jt, contribution: 20 * _jt),
      _snap(2, 2, sept, 20 * _jt, contribution: 20 * _jt),
      _snap(3, 3, sept, 40 * _jt, contribution: 40 * _jt),
      _snap(4, 1, oct, 25 * _jt),
      _snap(5, 3, oct, 35 * _jt),
      _snap(6, 1, nov, 30 * _jt),
      _snap(7, 2, nov, 22 * _jt),
      _snap(8, 3, nov, 28 * _jt),
    ],
    baseCurrency: Currency.idr,
    rates: const {'USD': 1.0, 'IDR': 16000.0},
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required String language,
  required AppThemeMode theme,
  required InvestmentSummary summary,
}) async {
  // A 360dp-wide phone, the narrowest the app targets.
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localeProvider.overrideWithValue(Locale(language)),
        defaultCurrencyProvider.overrideWithValue(Currency.idr),
        showDecimalProvider.overrideWithValue(false),
        cardShadowProvider.overrideWithValue(true),
      ],
      child: AppThemeProvider(
        themeMode: theme,
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [InvestmentChartCarousel(summary: summary)],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // The value chart's date labels need locale data, which main() loads.
  setUpAll(() => initializeDateFormatting());

  for (final language in ['en', 'id']) {
    for (final theme in AppThemeMode.values) {
      testWidgets('slides and hold popup — $language, ${theme.name}',
          (tester) async {
        final trans =
            language == 'id' ? AppTranslationsId() : AppTranslationsEn();
        await _pump(tester,
            language: language, theme: theme, summary: _summary());

        // Slide 1: the value chart.
        expect(find.byType(InvestmentValueChart), findsOneWidget);
        expect(find.text(trans.investmentChartTitle), findsOneWidget);

        // Swipe to slide 2: the allocation pie.
        await tester.drag(
            find.byType(InvestmentValueChart), const Offset(-300, 0));
        await tester.pumpAndSettle();
        expect(find.byType(InvestmentAllocationChart), findsOneWidget);
        expect(find.text(trans.investmentAllocationTitle), findsOneWidget);
        expect(find.text('65.0%'), findsOneWidget);
        expect(find.text('35.0%'), findsOneWidget);

        // Hold a category: total and gain on top, its assets underneath.
        await tester.longPress(find.text(trans.investmentAssetTypeStock));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text(trans.investmentTotalValue), findsOneWidget);
        expect(find.textContaining('52.000.000'), findsNWidgets(2));
        expect(find.textContaining('(+30.00%)'), findsOneWidget);
        expect(find.text('BBCA'), findsOneWidget);
        expect(find.textContaining('(+50.00%)'), findsOneWidget);
        expect(find.textContaining('(+10.00%)'), findsOneWidget);
        expect(find.text('Gold bar'), findsNothing);

        await tester.tap(find.text(trans.close));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);

        // A loss is signed and shown the same way.
        await tester.tap(find.text(trans.investmentAssetTypeGold));
        await tester.pumpAndSettle();
        expect(find.textContaining('(-30.00%)'), findsNWidgets(2));
      });
    }
  }

  testWidgets('allocation is available before the value chart has enough data',
      (tester) async {
    final summary = buildInvestmentSummary(
      assets: [_asset(1, 'BBCA', AssetType.stock)],
      snapshots: [
        _snap(1, 1, DateTime(2026, 9, 13), 20 * _jt, contribution: 20 * _jt),
      ],
      baseCurrency: Currency.idr,
      rates: const {'USD': 1.0, 'IDR': 16000.0},
    );
    await _pump(tester,
        language: 'en', theme: AppThemeMode.defaultTheme, summary: summary);

    final trans = AppTranslationsEn();
    expect(find.text(trans.investmentChartNeedMore(2)), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text(trans.investmentAllocationTitle), findsOneWidget);
    expect(find.text('100.0%'), findsOneWidget);
  });

  testWidgets('no slides when nothing held has a value', (tester) async {
    final summary = buildInvestmentSummary(
      assets: [_asset(1, 'BBCA', AssetType.stock)],
      snapshots: const [],
      baseCurrency: Currency.idr,
      rates: const {'USD': 1.0, 'IDR': 16000.0},
    );
    await _pump(tester,
        language: 'en', theme: AppThemeMode.defaultTheme, summary: summary);

    expect(find.byType(PageView), findsNothing);
    expect(find.byType(InvestmentAllocationChart), findsNothing);
  });
}
