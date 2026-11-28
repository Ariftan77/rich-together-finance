import 'package:flutter_test/flutter_test.dart';
import 'package:rich_together/core/models/enums.dart';
import 'package:rich_together/features/home_widgets/domain/home_widget_models.dart';
import 'package:rich_together/features/home_widgets/services/home_widget_service.dart';
import 'package:rich_together/shared/theme/app_theme_mode.dart';

void main() {
  group('HomeWidgetLaunchActionX.fromUri', () {
    test('parses expense, income, transfer, budget, overview, and toggle-privacy URIs', () {
      expect(
        HomeWidgetLaunchActionX.fromUri(
          Uri.parse('richtogether://widget/expense?homeWidget=1'),
        ),
        HomeWidgetLaunchAction.addExpense,
      );
      expect(
        HomeWidgetLaunchActionX.fromUri(
          Uri.parse('richtogether://widget/income?homeWidget=1'),
        ),
        HomeWidgetLaunchAction.addIncome,
      );
      expect(
        HomeWidgetLaunchActionX.fromUri(
          Uri.parse('richtogether://widget/transfer?homeWidget=1'),
        ),
        HomeWidgetLaunchAction.addTransfer,
      );
      expect(
        HomeWidgetLaunchActionX.fromUri(
          Uri.parse('richtogether://widget/budget?homeWidget=1'),
        ),
        HomeWidgetLaunchAction.openBudget,
      );
      expect(
        HomeWidgetLaunchActionX.fromUri(
          Uri.parse('richtogether://widget/overview?homeWidget=1'),
        ),
        HomeWidgetLaunchAction.openOverview,
      );
      expect(
        HomeWidgetLaunchActionX.fromUri(
          Uri.parse('richtogether://widget/toggle-privacy?homeWidget=1'),
        ),
        HomeWidgetLaunchAction.togglePrivacy,
      );
    });

    test('returns null for unrelated schemes or null URI', () {
      expect(HomeWidgetLaunchActionX.fromUri(null), isNull);
      expect(
        HomeWidgetLaunchActionX.fromUri(Uri.parse('https://example.com/expense')),
        isNull,
      );
      expect(
        HomeWidgetLaunchActionX.fromUri(Uri.parse('richtogether://widget/unknown')),
        isNull,
      );
    });
  });

  group('HomeWidgetService.formatWidgetMoney', () {
    test('formats standard IDR and USD amounts accurately', () {
      expect(
        HomeWidgetService.formatWidgetMoney(
          85000,
          currency: Currency.idr,
          showDecimal: false,
          isIndonesian: true,
        ),
        'Rp 85.000',
      );
      expect(
        HomeWidgetService.formatWidgetMoney(
          125.5,
          currency: Currency.usd,
          showDecimal: true,
          isIndonesian: false,
        ),
        '\$ 125.50',
      );
    });

    test('compacts large millions and billions cleanly in EN and ID', () {
      expect(
        HomeWidgetService.formatWidgetMoney(
          12500000,
          currency: Currency.idr,
          showDecimal: false,
          isIndonesian: true,
        ),
        'Rp 12,5 jt',
      );
      expect(
        HomeWidgetService.formatWidgetMoney(
          12500000,
          currency: Currency.idr,
          showDecimal: false,
          isIndonesian: false,
        ),
        'Rp 12.5M',
      );
      expect(
        HomeWidgetService.formatWidgetMoney(
          1500000000,
          currency: Currency.idr,
          showDecimal: false,
          isIndonesian: true,
        ),
        'Rp 1,5 M',
      );
    });

    test('preserves negative sign for over-budget remaining values', () {
      expect(
        HomeWidgetService.formatWidgetMoney(
          -150000,
          currency: Currency.idr,
          showDecimal: false,
          isIndonesian: true,
        ),
        '-Rp 150.000',
      );
    });
  });

  group('HomeWidgetService.serializeThemeMode & Snapshot keys', () {
    test('serializes all four AppThemeMode values', () {
      expect(
        HomeWidgetService.serializeThemeMode(AppThemeMode.defaultTheme),
        'default',
      );
      expect(HomeWidgetService.serializeThemeMode(AppThemeMode.dark), 'dark');
      expect(HomeWidgetService.serializeThemeMode(AppThemeMode.light), 'light');
      expect(
        HomeWidgetService.serializeThemeMode(AppThemeMode.system),
        'system',
      );
    });

    test('HomeWidgetSnapshot.toStorageMap contains all native keys', () {
      const snapshot = HomeWidgetSnapshot(
        profileName: 'Personal',
        themeMode: 'default',
        maskedPlaceholder: 'Rp ••••••',
        lblQuickAdd: 'Quick Actions',
        lblExpense: 'Expense',
        lblIncome: 'Income',
        lblTransfer: 'Transfer',
        lblSafePerDay: 'Safe / day',
        lblBudgetLeft: 'Budget left',
        lblOverBudget: 'Over budget',
        lblNoBudget: 'Tap to set budget',
        lblDaysLeft: '4 days left',
        lblTodaySpend: 'Today\'s Spend',
        lblMonthIn: 'Month In',
        lblMonthOut: 'Month Out',
        hasBudget: true,
        budgetRemainingFmt: 'Rp 800.000',
        safePerDayFmt: 'Rp 200.000',
        budgetSpentOfTotalFmt: 'Rp 1.200.000 / Rp 2.000.000',
        budgetProgressPct: 60,
        budgetStatus: 'ok',
        todayExpenseFmt: 'Rp 50.000',
        monthExpenseFmt: 'Rp 1.200.000',
        monthIncomeFmt: 'Rp 5.000.000',
      );

      final map = snapshot.toStorageMap();
      expect(map['widget_has_data'], true);
      expect(map['widget_profile_name'], 'Personal');
      expect(map['widget_budget_progress_pct'], 60);
      expect(map['widget_budget_status'], 'ok');
      expect(map['widget_today_expense_fmt'], 'Rp 50.000');
    });
  });
}
