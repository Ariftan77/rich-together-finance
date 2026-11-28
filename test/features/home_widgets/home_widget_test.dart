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
      expect(
        HomeWidgetLaunchActionX.fromUri(
          Uri.parse('richtogether://widget/budget-new?homeWidget=1'),
        ),
        HomeWidgetLaunchAction.createBudget,
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
        snapshotDay: '2026-11-28',
        budgetPeriodEndDay: '2026-11-30',
        zeroAmountFmt: 'Rp 0',
        lblStale: 'Open Richer to refresh',
        safePerDayAheadFmt: ['Rp 400.000', 'Rp 800.000', '', '', '', ''],
        lblDaysLeftAhead: ['2 days left', '1 day left', '', '', '', ''],
      );

      final map = snapshot.toStorageMap();
      expect(map['widget_snapshot_day'], '2026-11-28');
      expect(map['widget_budget_period_end_day'], '2026-11-30');
      expect(map['widget_zero_fmt'], 'Rp 0');
      expect(map['widget_lbl_stale'], 'Open Richer to refresh');
      expect(map['widget_safe_per_day_fmt_d1'], 'Rp 400.000');
      expect(map['widget_lbl_days_left_d2'], '1 day left');
      expect(map['widget_safe_per_day_fmt_d6'], '');
      expect(map.containsKey('widget_safe_per_day_fmt_d7'), isFalse);
      expect(map['widget_has_data'], true);
      expect(map['widget_profile_name'], 'Personal');
      expect(map['widget_budget_progress_pct'], 60);
      expect(map['widget_budget_status'], 'ok');
      expect(map['widget_today_expense_fmt'], 'Rp 50.000');
    });
  });

  group('Day rollover helpers', () {
    test('formatWidgetDay zero-pads to yyyy-MM-dd', () {
      expect(formatWidgetDay(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
    });

    test('calendarDaysBetween ignores time of day', () {
      expect(
        calendarDaysBetween(DateTime(2026, 11, 28, 23, 59), DateTime(2026, 11, 29, 0, 1)),
        1,
      );
      expect(calendarDaysBetween(DateTime(2026, 12, 31), DateTime(2027, 1, 1)), 1);
      expect(calendarDaysBetween(DateTime(2026, 11, 28), DateTime(2026, 11, 27)), -1);
    });

    test('BudgetWindow monthly ends on last day of month, inclusive count', () {
      final w = BudgetWindow.resolve(BudgetPeriod.monthly, DateTime(2026, 11, 28, 15));
      expect(w.periodEnd, DateTime(2026, 11, 30));
      expect(w.daysLeft, 3);

      final leap = BudgetWindow.resolve(BudgetPeriod.monthly, DateTime(2028, 2, 1));
      expect(leap.periodEnd, DateTime(2028, 2, 29));
      expect(leap.daysLeft, 29);
    });

    test('BudgetWindow weekly ends on Sunday, crossing month boundary', () {
      // 2026-11-28 is a Saturday.
      final sat = BudgetWindow.resolve(BudgetPeriod.weekly, DateTime(2026, 11, 28));
      expect(sat.periodEnd, DateTime(2026, 11, 29));
      expect(sat.daysLeft, 2);

      // 2026-11-30 is a Monday; week ends 2026-12-06.
      final mon = BudgetWindow.resolve(BudgetPeriod.weekly, DateTime(2026, 11, 30));
      expect(mon.periodEnd, DateTime(2026, 12, 6));
      expect(mon.daysLeft, 7);

      final sun = BudgetWindow.resolve(BudgetPeriod.weekly, DateTime(2026, 11, 29));
      expect(sun.daysLeft, 1);
    });

    test('BudgetWindow mixed/yearly ends Dec 31', () {
      final w = BudgetWindow.resolve(null, DateTime(2026, 12, 31));
      expect(w.periodEnd, DateTime(2026, 12, 31));
      expect(w.daysLeft, 1);
      expect(BudgetWindow.resolve(BudgetPeriod.yearly, DateTime(2026, 1, 1)).daysLeft, 365);
    });

    test('projectSafePerDay divides remaining by shrinking days and stops at period end', () {
      final p = projectSafePerDay(remaining: 900000, daysLeft: 4);
      expect(p, hasLength(kWidgetProjectionHorizonDays));
      expect(p[0], 300000); // tomorrow: 3 days left
      expect(p[1], 450000);
      expect(p[2], 900000);
      expect(p.sublist(3), everyElement(isNull));
    });

    test('projectSafePerDay yields 0 (not negative) when over budget', () {
      final p = projectSafePerDay(remaining: -50000, daysLeft: 10);
      expect(p.every((v) => v == 0), isTrue);
    });

    test('toStorageMap rejects projection lists of the wrong length', () {
      const bad = HomeWidgetSnapshot(
        profileName: 'P',
        themeMode: 'default',
        maskedPlaceholder: 'Rp ••••••',
        lblQuickAdd: '',
        lblExpense: '',
        lblIncome: '',
        lblTransfer: '',
        lblSafePerDay: '',
        lblBudgetLeft: '',
        lblOverBudget: '',
        lblNoBudget: '',
        lblDaysLeft: '',
        lblTodaySpend: '',
        lblMonthIn: '',
        lblMonthOut: '',
        hasBudget: false,
        budgetRemainingFmt: '',
        safePerDayFmt: '',
        budgetSpentOfTotalFmt: '',
        budgetProgressPct: 0,
        budgetStatus: 'ok',
        todayExpenseFmt: '',
        monthExpenseFmt: '',
        monthIncomeFmt: '',
        snapshotDay: '2026-11-28',
        budgetPeriodEndDay: '',
        zeroAmountFmt: 'Rp 0',
        lblStale: '',
        safePerDayAheadFmt: [''],
        lblDaysLeftAhead: [''],
      );
      expect(bad.toStorageMap, throwsArgumentError);
    });
  });
}
