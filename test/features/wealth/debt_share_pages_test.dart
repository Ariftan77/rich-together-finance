import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rich_together/core/database/database.dart';
import 'package:rich_together/core/models/enums.dart';
import 'package:rich_together/features/wealth/presentation/screens/wealth_screen.dart';
import 'package:rich_together/features/wealth/presentation/widgets/debt_share_pages.dart';
import 'package:rich_together/shared/theme/app_theme_mode.dart';
import 'package:rich_together/shared/theme/theme_provider_widget.dart';

void main() {
  setUpAll(() async => initializeDateFormatting());

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    AppThemeMode mode = AppThemeMode.defaultTheme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto'),
        home: AppThemeProvider(
          themeMode: mode,
          child: Stack(
            children: [
              Positioned(
                right: 801,
                top: 0,
                child: UnconstrainedBox(child: Material(child: child)),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final heights in <List<double>>[
    [100],
    [340, 340],
    [340, 340, 1],
    [340, 340, 340, 340, 340],
    [900, 100],
    List.filled(70, 340),
  ]) {
    testWidgets('packs intact children with heights $heights', (tester) async {
      final key = GlobalKey();
      await mount(
        tester,
        RepaintBoundary(
          key: key,
          child: DebtSharePages(
            children: [
              for (var i = 0; i < heights.length; i++)
                SizedBox(key: ValueKey(i), height: heights[i]),
            ],
          ),
        ),
      );
      final size = tester.getSize(find.byKey(key));
      var previousPage = 0.0;
      var previousBottom = 20.0;
      for (var i = 0; i < heights.length; i++) {
        final box = tester.renderObject<RenderBox>(find.byKey(ValueKey(i)));
        final offset = (box.parentData! as ContainerBoxParentData).offset;
        expect(box.size.height, heights[i]);
        expect(offset.dx, greaterThanOrEqualTo(previousPage));
        if (offset.dx == previousPage) {
          expect(offset.dy, greaterThanOrEqualTo(previousBottom));
        }
        expect(
          offset.dy + box.size.height,
          lessThanOrEqualTo(size.height - 20),
        );
        previousPage = offset.dx;
        previousBottom = offset.dy + box.size.height;
      }
      if (heights.length <= 2 && heights.first <= 340) {
        expect(size.width, 380);
      } else if (heights.length == 3 || heights.first == 900) {
        expect(size.width, 760);
      } else if (heights.length == 5) {
        expect(size.width, 1140);
      } else {
        expect(size.width, greaterThan(9999));
      }
      expect(tester.getTopRight(find.byKey(key)).dx, lessThan(0));
      expect(tester.takeException(), isNull);
    });
  }

  Debt debt(int i, {String? note}) => Debt(
    id: i,
    profileId: 1,
    type: DebtType.payable,
    personName: 'Test Person',
    amount: 1000,
    paidAmount: 200,
    currency: Currency.idr,
    isSettled: false,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    dueDate: DateTime(2026, 1, 2),
    note: note ?? 'Entry $i',
    isSynced: false,
  );

  for (final locale in ['en', 'id']) {
    for (final mode in AppThemeMode.values) {
      testWidgets('captures single horizontal PNG in $locale / $mode', (
        tester,
      ) async {
        final key = GlobalKey();
        final debts = List.generate(24, (i) => debt(i));
        await mount(
          tester,
          buildPersonDebtShareWidget(
            'Test Person',
            DebtType.payable,
            debts,
            locale,
            captureKey: key,
          ),
          mode: mode,
        );
        final pages = tester.renderObject<RenderBox>(
          find.byType(DebtSharePages),
        );
        expect(pages.size.width, greaterThan(380));
        expect(pages.size.height, 720);
        var previous = const Offset(0, 0);
        for (var i = 0; i < debts.length; i++) {
          final finder = find.text('Entry $i');
          expect(finder, findsOneWidget);
          final position = tester.getTopLeft(finder);
          if (i > 0) {
            expect(position.dx, greaterThanOrEqualTo(previous.dx));
            if (position.dx == previous.dx) {
              expect(position.dy, greaterThan(previous.dy));
            }
          }
          previous = position;
        }
        expect(find.textContaining(RegExp(r'^IDR\s+19\.200$')), findsOneWidget);
        expect(find.textContaining(RegExp(r'^IDR\s+24\.000$')), findsOneWidget);
        expect(tester.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          expect(image.width, pages.size.width.toInt() * 2);
          expect(image.height, 1440);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          expect(bytes, isNotNull);
          final codec = await ui.instantiateImageCodec(
            bytes!.buffer.asUint8List(),
          );
          final decoded = await codec.getNextFrame();
          expect(decoded.image.width, image.width);
          expect(decoded.image.height, image.height);
          if (locale == 'en' && mode == AppThemeMode.defaultTheme) {
            final file = File('build/debt_share_horizontal.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes.buffer.asUint8List());
          }
          decoded.image.dispose();
          codec.dispose();
          image.dispose();
        });
      });
    }
  }

  testWidgets('short export and oversized wrapped note keep all content', (
    tester,
  ) async {
    for (final note in [
      'Short note',
      List.filled(500, 'Long note').join(' '),
    ]) {
      final key = GlobalKey();
      await mount(
        tester,
        buildPersonDebtShareWidget(
          'Test Person',
          DebtType.receivable,
          [debt(1, note: note)],
          'en',
          captureKey: key,
        ),
      );
      expect(find.text(note), findsOneWidget);
      final size = tester.getSize(find.byKey(key));
      final text = tester.renderObject<RenderBox>(find.text(note));
      final boundary = key.currentContext!.findRenderObject()! as RenderBox;
      final offset = text.localToGlobal(Offset.zero, ancestor: boundary);
      expect(offset.dy + text.size.height, lessThan(size.height));
      expect(offset.dx + text.size.width, lessThan(size.width));
      if (note == 'Short note') expect(size.width, 380);
      expect(tester.takeException(), isNull);
    }
  });
}
