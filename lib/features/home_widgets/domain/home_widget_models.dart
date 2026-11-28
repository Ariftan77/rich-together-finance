// Domain models and action routing for Android & iOS Home Screen Widgets.

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
  });

  Map<String, Object> toStorageMap() {
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
    };
  }
}
