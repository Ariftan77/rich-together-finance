// Domain models and action routing for Android & iOS Home Screen Widgets.

import '../../../core/models/enums.dart';

/// How many days past the snapshot day native widgets can roll forward on
/// their own (without the app re-pushing data). Beyond this, widgets show a
/// "open the app to refresh" hint instead of guessing.
const int kWidgetProjectionHorizonDays = 6;

/// Formats a local calendar day as `yyyy-MM-dd`, the format native widgets parse.
String formatWidgetDay(DateTime day) {
  final y = day.year.toString().padLeft(4, '0');
  final m = day.month.toString().padLeft(2, '0');
  final d = day.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Calendar-day distance computed in UTC so DST transitions never shift it.
int calendarDaysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// The budget period that the Budget Pulse widget tracks for [today].
class BudgetWindow {
  final DateTime periodEnd;
  final int daysLeft; // inclusive of today, always >= 1

  const BudgetWindow({required this.periodEnd, required this.daysLeft});

  /// [period] null means a mix of periods; it falls back to the calendar year,
  /// matching the widget's "any budget" fallback.
  factory BudgetWindow.resolve(BudgetPeriod? period, DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    final DateTime end;
    switch (period) {
      case BudgetPeriod.monthly:
        end = DateTime(day.year, day.month + 1, 0);
      case BudgetPeriod.weekly:
        // Weeks end on Sunday (DateTime.sunday == 7).
        end = DateTime(day.year, day.month, day.day + (7 - day.weekday));
      case BudgetPeriod.yearly:
      case null:
        end = DateTime(day.year, 12, 31);
    }
    final left = calendarDaysBetween(day, end) + 1;
    return BudgetWindow(periodEnd: end, daysLeft: left < 1 ? 1 : left);
  }
}

/// Safe-to-spend per day for each of the next [horizon] days, assuming no new
/// spending is recorded. Index 0 is tomorrow. Null means the period has ended
/// by that day, so the widget must not show a projection.
List<double?> projectSafePerDay({
  required double remaining,
  required int daysLeft,
  int horizon = kWidgetProjectionHorizonDays,
}) {
  return List<double?>.generate(horizon, (i) {
    final left = daysLeft - (i + 1);
    if (left < 1) return null;
    return remaining > 0 ? remaining / left : 0.0;
  });
}

/// Supported native Home Screen Widget kinds.
enum HomeWidgetKind {
  quickActions,
  budgetPulse,
  cashFlow,
}

extension HomeWidgetKindX on HomeWidgetKind {
  /// Fully qualified Android `AppWidgetProvider` class name.
  String get qualifiedAndroidName {
    switch (this) {
      case HomeWidgetKind.quickActions:
        return 'com.axiomtechdev.richtogether.widgets.QuickActionsWidgetProvider';
      case HomeWidgetKind.budgetPulse:
        return 'com.axiomtechdev.richtogether.widgets.BudgetPulseWidgetProvider';
      case HomeWidgetKind.cashFlow:
        return 'com.axiomtechdev.richtogether.widgets.CashFlowWidgetProvider';
    }
  }

  /// iOS WidgetKit `kind` identifier.
  String get iOSName {
    switch (this) {
      case HomeWidgetKind.quickActions:
        return 'RicherQuickActionsWidget';
      case HomeWidgetKind.budgetPulse:
        return 'RicherBudgetPulseWidget';
      case HomeWidgetKind.cashFlow:
        return 'RicherCashFlowWidget';
    }
  }
}

/// Deep-link actions triggered when tapping a Home Screen Widget element.
enum HomeWidgetLaunchAction {
  addExpense,
  addIncome,
  addTransfer,
  openBudget,
  openOverview,
  togglePrivacy,
  createBudget,
}

extension HomeWidgetLaunchActionX on HomeWidgetLaunchAction {
  /// Parses a widget URI such as `richtogether://widget/expense?homeWidget=1`.
  static HomeWidgetLaunchAction? fromUri(Uri? uri) {
    if (uri == null) return null;
    if (uri.scheme != 'richtogether') return null;

    // Support both `richtogether://widget/expense` (host=widget, path=/expense)
    // and `richtogether://expense` (host=expense).
    final segment = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.first.toLowerCase()
        : uri.host.toLowerCase();

    switch (segment) {
      case 'expense':
        return HomeWidgetLaunchAction.addExpense;
      case 'income':
        return HomeWidgetLaunchAction.addIncome;
      case 'transfer':
        return HomeWidgetLaunchAction.addTransfer;
      case 'budget':
        return HomeWidgetLaunchAction.openBudget;
      case 'budget-new':
      case 'budget_new':
        return HomeWidgetLaunchAction.createBudget;
      case 'overview':
      case 'dashboard':
        return HomeWidgetLaunchAction.openOverview;
      case 'toggle-privacy':
      case 'toggle_privacy':
        return HomeWidgetLaunchAction.togglePrivacy;
      default:
        return null;
    }
  }
}

/// Pre-formatted, locale-aware and theme-aware data payload synced to
/// `SharedPreferences` (Android) and App Group `UserDefaults` (iOS).
class HomeWidgetSnapshot {
  final String profileName;
  final String themeMode; // 'default' | 'dark' | 'light' | 'system'
  final String maskedPlaceholder;

  // Localized short labels
  final String lblQuickAdd;
  final String lblExpense;
  final String lblIncome;
  final String lblTransfer;
  final String lblSafePerDay;
  final String lblBudgetLeft;
  final String lblOverBudget;
  final String lblNoBudget;
  final String lblDaysLeft;
  final String lblTodaySpend;
  final String lblMonthIn;
  final String lblMonthOut;

  // Widget #2: Safe-to-Spend Budget Pulse
  final bool hasBudget;
  final String budgetRemainingFmt;
  final String safePerDayFmt;
  final String budgetSpentOfTotalFmt;
  final int budgetProgressPct; // 0..100
  final String budgetStatus; // 'ok' | 'warning' | 'over'

  // Widget #3: Today & Monthly Cash Flow
  final String todayExpenseFmt;
  final String monthExpenseFmt;
  final String monthIncomeFmt;

  // Day-rollover support: lets native widgets stay correct after midnight
  // (and across month boundaries) when the app has not been opened.
  final String snapshotDay; // yyyy-MM-dd, local
  final String budgetPeriodEndDay; // yyyy-MM-dd, '' when no budget
  final String zeroAmountFmt;
  final String lblStale;
  /// Length [kWidgetProjectionHorizonDays]; index 0 = tomorrow. '' = no projection.
  final List<String> safePerDayAheadFmt;
  final List<String> lblDaysLeftAhead;

  const HomeWidgetSnapshot({
    required this.profileName,
    required this.themeMode,
    required this.maskedPlaceholder,
    required this.lblQuickAdd,
    required this.lblExpense,
    required this.lblIncome,
    required this.lblTransfer,
    required this.lblSafePerDay,
    required this.lblBudgetLeft,
    required this.lblOverBudget,
    required this.lblNoBudget,
    required this.lblDaysLeft,
    required this.lblTodaySpend,
    required this.lblMonthIn,
    required this.lblMonthOut,
    required this.hasBudget,
    required this.budgetRemainingFmt,
    required this.safePerDayFmt,
    required this.budgetSpentOfTotalFmt,
    required this.budgetProgressPct,
    required this.budgetStatus,
    required this.todayExpenseFmt,
    required this.monthExpenseFmt,
    required this.monthIncomeFmt,
    required this.snapshotDay,
    required this.budgetPeriodEndDay,
    required this.zeroAmountFmt,
    required this.lblStale,
    required this.safePerDayAheadFmt,
    required this.lblDaysLeftAhead,
  });

  Map<String, Object> toStorageMap() {
    if (safePerDayAheadFmt.length != kWidgetProjectionHorizonDays ||
        lblDaysLeftAhead.length != kWidgetProjectionHorizonDays) {
      throw ArgumentError(
        'Projection lists must have $kWidgetProjectionHorizonDays entries',
      );
    }
    return {
      'widget_has_data': true,
      'widget_profile_name': profileName,
      'widget_theme_mode': themeMode,
      'widget_masked_placeholder': maskedPlaceholder,
      'widget_lbl_quick_add': lblQuickAdd,
      'widget_lbl_expense': lblExpense,
      'widget_lbl_income': lblIncome,
      'widget_lbl_transfer': lblTransfer,
      'widget_lbl_safe_per_day': lblSafePerDay,
      'widget_lbl_budget_left': lblBudgetLeft,
      'widget_lbl_over_budget': lblOverBudget,
      'widget_lbl_no_budget': lblNoBudget,
      'widget_lbl_days_left': lblDaysLeft,
      'widget_lbl_today_spend': lblTodaySpend,
      'widget_lbl_month_in': lblMonthIn,
      'widget_lbl_month_out': lblMonthOut,
      'widget_has_budget': hasBudget,
      'widget_budget_remaining_fmt': budgetRemainingFmt,
      'widget_safe_per_day_fmt': safePerDayFmt,
      'widget_budget_spent_of_total_fmt': budgetSpentOfTotalFmt,
      'widget_budget_progress_pct': budgetProgressPct,
      'widget_budget_status': budgetStatus,
      'widget_today_expense_fmt': todayExpenseFmt,
      'widget_month_expense_fmt': monthExpenseFmt,
      'widget_month_income_fmt': monthIncomeFmt,
      'widget_snapshot_day': snapshotDay,
      'widget_budget_period_end_day': budgetPeriodEndDay,
      'widget_zero_fmt': zeroAmountFmt,
      'widget_lbl_stale': lblStale,
      for (var i = 0; i < kWidgetProjectionHorizonDays; i++) ...{
        'widget_safe_per_day_fmt_d${i + 1}': safePerDayAheadFmt[i],
        'widget_lbl_days_left_d${i + 1}': lblDaysLeftAhead[i],
      },
    };
  }
}
