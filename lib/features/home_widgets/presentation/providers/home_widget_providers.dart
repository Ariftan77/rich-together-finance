import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/currency_exchange_providers.dart';
import '../../../../core/providers/date_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/services/currency_exchange_service.dart';
import '../../../budget/presentation/providers/budget_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../domain/home_widget_models.dart';
import '../../services/home_widget_service.dart';

/// Holds a pending deep-link action launched from a Home Screen Widget
/// until [DashboardShell] is mounted and unlocked.
final pendingHomeWidgetActionProvider =
    StateProvider<HomeWidgetLaunchAction?>((ref) => null);

/// Reactive privacy-mask state synchronized with native widget storage.
class WidgetPrivacyNotifier extends StateNotifier<bool> {
  WidgetPrivacyNotifier() : super(false) {
    reload();
  }

  Future<void> reload() async {
    final masked = await HomeWidgetService.getAmountsMasked();
    if (mounted) state = masked;
  }

  Future<void> setMasked(bool masked) async {
    state = masked;
    await HomeWidgetService.setAmountsMasked(masked);
  }

  Future<void> toggle() async {
    final next = !state;
    await setMasked(next);
  }
}

final widgetAmountsMaskedProvider =
    StateNotifierProvider<WidgetPrivacyNotifier, bool>((ref) {
  return WidgetPrivacyNotifier();
});

/// Builds the latest [HomeWidgetSnapshot] from the active profile's live streams.
final homeWidgetSnapshotProvider = Provider<HomeWidgetSnapshot?>((ref) {
  final profile = ref.watch(activeProfileProvider).valueOrNull;
  if (profile == null) return null;

  final currency = ref.watch(defaultCurrencyProvider);
  final showDecimal = ref.watch(showDecimalProvider);
  final themeMode = ref.watch(appThemeModeProvider);
  final locale = ref.watch(localeProvider);
  final trans = ref.watch(translationsProvider);
  final rates = ref.watch(todayRatesProvider);
  final currentDate = ref.watch(currentDateProvider);

  final monthlyTxs =
      ref.watch(convertedMonthlyTransactionsProvider).valueOrNull ?? const [];
  final budgets =
      ref.watch(budgetsWithSpendingProvider).valueOrNull ?? const [];

  final isIndonesian = locale.languageCode == 'id';

  String fmt(double value) => HomeWidgetService.formatWidgetMoney(
        value,
        currency: currency,
        showDecimal: showDecimal,
        isIndonesian: isIndonesian,
      );

  // 1. Today's Spend & Monthly Cash Flow (already converted to defaultCurrency)
  double todayExpense = 0;
  double monthExpense = 0;
  double monthIncome = 0;

  for (final item in monthlyTxs) {
    final tx = item.transaction;
    if (tx.type == TransactionType.expense) {
      monthExpense += item.convertedAmount;
      if (tx.date.year == currentDate.year &&
          tx.date.month == currentDate.month &&
          tx.date.day == currentDate.day) {
        todayExpense += item.convertedAmount;
      }
    } else if (tx.type == TransactionType.income) {
      monthIncome += item.convertedAmount;
    }
  }

  // 2. Safe-to-Spend Budget Pulse (prefer monthly budgets; fallback to weekly,
  // then all budgets measured against the calendar year).
  List<BudgetWithSpending> targetBudgets =
      budgets.where((b) => b.budget.period == BudgetPeriod.monthly).toList();
  BudgetPeriod? windowPeriod = BudgetPeriod.monthly;
  if (targetBudgets.isEmpty) {
    targetBudgets =
        budgets.where((b) => b.budget.period == BudgetPeriod.weekly).toList();
    windowPeriod = BudgetPeriod.weekly;
  }
  if (targetBudgets.isEmpty && budgets.isNotEmpty) {
    targetBudgets = budgets;
    windowPeriod = null;
  }
  final window = BudgetWindow.resolve(windowPeriod, currentDate);
  final daysLeft = window.daysLeft;

  final hasBudget = targetBudgets.isNotEmpty;
  double totalBudget = 0;
  double totalSpent = 0;

  for (final item in targetBudgets) {
    totalBudget += CurrencyExchangeService.convertCurrency(
      item.budget.amount,
      item.budget.currency.code,
      currency.code,
      rates,
    );
    totalSpent += CurrencyExchangeService.convertCurrency(
      item.spentAmount,
      item.budget.currency.code,
      currency.code,
      rates,
    );
  }

  final remaining = totalBudget - totalSpent;
  final safePerDay = remaining > 0 ? (remaining / daysLeft) : 0.0;
  final projected = hasBudget
      ? projectSafePerDay(remaining: remaining, daysLeft: daysLeft)
      : List<double?>.filled(kWidgetProjectionHorizonDays, null);
  final rawRatio = totalBudget > 0 ? (totalSpent / totalBudget) : 0.0;
  final progressPct = (rawRatio * 100).round().clamp(0, 100);
  final String budgetStatus;
  if (!hasBudget || totalBudget <= 0) {
    budgetStatus = 'ok';
  } else if (totalSpent >= totalBudget) {
    budgetStatus = 'over';
  } else if (rawRatio >= 0.8) {
    budgetStatus = 'warning';
  } else {
    budgetStatus = 'ok';
  }

  return HomeWidgetSnapshot(
    profileName: profile.name,
    themeMode: HomeWidgetService.serializeThemeMode(themeMode),
    maskedPlaceholder: '${currency.symbol} ••••••',
    lblQuickAdd: trans.widgetQuickAddTitle,
    lblExpense: trans.widgetLblExpenseShort,
    lblIncome: trans.widgetLblIncomeShort,
    lblTransfer: trans.widgetLblTransferShort,
    lblSafePerDay: trans.widgetLblSafePerDay,
    lblBudgetLeft: trans.widgetLblBudgetLeft,
    lblOverBudget: trans.widgetLblOverBudget,
    lblNoBudget: trans.widgetLblNoBudget,
    lblDaysLeft: trans.widgetLblDaysLeft(daysLeft),
    lblTodaySpend: trans.widgetLblTodaySpend,
    lblMonthIn: trans.widgetLblMonthIn,
    lblMonthOut: trans.widgetLblMonthOut,
    hasBudget: hasBudget,
    budgetRemainingFmt: hasBudget ? fmt(remaining) : fmt(0),
    safePerDayFmt: hasBudget ? fmt(safePerDay) : fmt(0),
    budgetSpentOfTotalFmt:
        hasBudget ? '${fmt(totalSpent)} / ${fmt(totalBudget)}' : '',
    budgetProgressPct: progressPct,
    budgetStatus: budgetStatus,
    todayExpenseFmt: fmt(todayExpense),
    monthExpenseFmt: fmt(monthExpense),
    monthIncomeFmt: fmt(monthIncome),
    snapshotDay: formatWidgetDay(currentDate),
    budgetPeriodEndDay: hasBudget ? formatWidgetDay(window.periodEnd) : '',
    zeroAmountFmt: fmt(0),
    lblStale: trans.widgetLblStale,
    safePerDayAheadFmt: [
      for (final v in projected) v == null ? '' : fmt(v),
    ],
    lblDaysLeftAhead: [
      for (var i = 0; i < projected.length; i++)
        projected[i] == null ? '' : trans.widgetLblDaysLeft(daysLeft - (i + 1)),
    ],
  );
});

/// Watched in [DashboardShell] to automatically push fresh data to Android & iOS
/// Home Screen Widgets whenever transactions, budgets, profile, currency,
/// language, theme, or calendar day change.
final homeWidgetSyncProvider = Provider<void>((ref) {
  Timer? debounceTimer;
  ref.onDispose(() => debounceTimer?.cancel());

  final initial = ref.read(homeWidgetSnapshotProvider);
  if (initial != null) {
    debounceTimer = Timer(const Duration(milliseconds: 250), () {
      HomeWidgetService.pushSnapshot(initial);
    });
  }

  ref.listen<HomeWidgetSnapshot?>(homeWidgetSnapshotProvider, (prev, next) {
    if (next == null) return;
    debounceTimer?.cancel();
    debounceTimer = Timer(const Duration(milliseconds: 200), () {
      HomeWidgetService.pushSnapshot(next);
    });
  });
});
