import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rich_together/core/localization/translations_en.dart';
import 'package:rich_together/core/localization/translations_id.dart';
import 'package:rich_together/core/providers/profile_provider.dart';
import 'package:rich_together/shared/theme/app_theme_mode.dart';
import 'package:rich_together/shared/theme/theme_provider_widget.dart';
import 'package:rich_together/shared/widgets/glass_button.dart';

Widget _harness({
  required Widget child,
  required AppThemeMode themeMode,
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: [cardShadowProvider.overrideWithValue(false)],
    child: MaterialApp(
      home: AppThemeProvider(
        themeMode: themeMode,
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(body: child),
          ),
        ),
      ),
    ),
  );
}

/// Mirrors the Update Value / Sell-Withdraw pair on the investment asset
/// detail screen: two full-width icon buttons sharing a Row via Expanded.
Widget _sideBySide(String left, String right, GlassButtonSize size) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        Expanded(
          child: GlassButton(
            text: left,
            icon: Icons.edit_note,
            onPressed: () {},
            isFullWidth: true,
            size: size,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassButton(
            text: right,
            icon: Icons.sell_outlined,
            onPressed: () {},
            isPrimary: false,
            isFullWidth: true,
            size: size,
          ),
        ),
      ],
    ),
  );
}

Future<void> _setScreenWidth(WidgetTester tester, double width) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.reset);
}

void main() {
  final labels = {
    'en': (
      AppTranslationsEn().investmentUpdateValue,
      AppTranslationsEn().investmentSellOrWithdraw,
    ),
    'id': (
      AppTranslationsId().investmentUpdateValue,
      AppTranslationsId().investmentSellOrWithdraw,
    ),
  };

  group('GlassButton full-width label in a narrow Expanded', () {
    for (final width in [320.0, 375.0, 402.0]) {
      for (final lang in labels.entries) {
        for (final mode in AppThemeMode.values) {
          for (final scale in [1.0, 1.3]) {
            for (final size in GlassButtonSize.values) {
              testWidgets(
                  'given ${width}pt screen, ${lang.key}, $mode, '
                  'textScale $scale, $size '
                  'when laid out side by side '
                  'then nothing overflows', (tester) async {
                await _setScreenWidth(tester, width);
                await tester.pumpWidget(_harness(
                  themeMode: mode,
                  textScale: scale,
                  child: _sideBySide(lang.value.$1, lang.value.$2, size),
                ));
                expect(tester.takeException(), isNull);
              });
            }
          }
        }
      }
    }
  });

  testWidgets(
      'given a non-full-width button in an unbounded Row '
      'when laid out '
      'then it keeps its natural size and does not throw', (tester) async {
    await _setScreenWidth(tester, 402);
    await tester.pumpWidget(_harness(
      themeMode: AppThemeMode.defaultTheme,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            GlassButton(
              text: 'A fairly long button label',
              icon: Icons.add,
              onPressed: () {},
            ),
          ],
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.text('A fairly long button label'), findsOneWidget);
  });
}
