import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/currency_exchange_providers.dart';
import '../../../../core/services/currency_exchange_service.dart';
import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';

/// Summary of all budgets for a given period, converted to the user's default currency
class BudgetPeriodSummary {
  final BudgetPeriod period;
  final double totalBudget;
  final double totalSpent;
  final double progress;
  final Currency displayCurrency;
  final int count;

  BudgetPeriodSummary({
    required this.period,
    required this.totalBudget,
    required this.totalSpent,
    required this.displayCurrency,
    required this.count,
  }) : progress = totalBudget > 0 ? totalSpent / totalBudget : 0.0;
}

/// Model to hold budget data combined with spending info and multi-category details
class BudgetWithSpending {
  final Budget budget;
  final List<Category> categories;

  /// The raw count of category IDs linked to this budget in the junction table.
  /// This may differ from [categories].length when linked categories have been
  /// deleted from the DB.  Use this for "has multiple categories" checks so
  /// that the breakdown long-press is not silently disabled by stale deletes.
  final int linkedCategoryCount;

  final double spentAmount;
  final double remainingAmount;
  final double progress; // 0.0 to 1.0 (or > 1.0 if over budget)

  /// Per-category spending breakdown: categoryId → converted spent amount.
  final Map<int, double> spentByCategory;

  // Convenience accessors kept for backward compatibility with display widgets.
  String get categoryName => _derivedName;
  String get categoryIcon => categories.isNotEmpty ? categories.first.icon : '';
  String get categoryColor =>
      categories.isNotEmpty ? (categories.first.color ?? '#808080') : '#808080';

  /// The color hex string saved alongside the budget's own icon (may be null).
  String? get budgetIconColor => budget.iconColor;

  /// The icon to display for this budget.
  /// Priority: budget's own icon → single-category icon → null (use generic).
  String? get displayIcon {
    if (budget.icon != null && budget.icon!.isNotEmpty) return budget.icon;
    if (categories.isNotEmpty) return categories.first.icon;
    return null;
  }

  String get _derivedName {
    if (budget.name != null && budget.name!.trim().isNotEmpty) {
      return budget.name!.trim();
    }
    if (categories.isEmpty) return 'Unnamed Budget';
    if (categories.length == 1) return categories.first.name;
    if (categories.length == 2) {
      return '${categories[0].name} & ${categories[1].name}';
    }
    return '${categories[0].name} + ${categories.length - 1} more';
  }

  BudgetWithSpending({
    required this.budget,
    required this.categories,
    required this.linkedCategoryCount,
    required this.spentAmount,
    this.spentByCategory = const {},
  })  : remainingAmount = budget.amount - spentAmount,
        progress = (budget.amount > 0) ? (spentAmount / budget.amount) : 0.0;
}

/// Provider to get all budgets with spending calculations
final budgetsWithSpendingProvider =
    StreamProvider.autoDispose<List<BudgetWithSpending>>((ref) {
  final budgetDao = ref.watch(budgetDaoProvider);
  final transactionDao = ref.watch(transactionDaoProvider);
  final accountDao = ref.watch(accountDaoProvider);
  final exchangeService = ref.watch(currencyExchangeServiceProvider);
  final profileId = ref.watch(activeProfileIdProvider);

  if (profileId == null) return Stream.value([]);

  // Merge budget and transaction change events into a single trigger.
  final controller = StreamController<void>();
  void trigger() {
    if (!controller.isClosed) controller.add(null);
  }

  void propagateError(Object e, StackTrace s) {
    if (!controller.isClosed) controller.addError(e, s);
  }

  final budgetSub = budgetDao
      .watchAllBudgets(profileId)
      .listen((_) => trigger(), onError: propagateError);
  final txSub = transactionDao
      .watchAllTransactions(profileId)
      .listen((_) => trigger(), onError: propagateError);

  Future.microtask(trigger);

  ref.onDispose(() {
    budgetSub.cancel();
    txSub.cancel();
    controller.close();
  });

  return controller.stream.asyncMap((_) async {
    final rateResult = await exchangeService.getRates();

    final accounts = await accountDao.getAllAccountsIncludingInactive(profileId);
    final accountMap = {for (final a in accounts) a.id: a};

    final budgetList = await budgetDao.getAllBudgets(profileId);
    if (budgetList.isEmpty) return <BudgetWithSpending>[];

    // Load categories and budget-category links once.
    final categoryDao = ref.read(categoryDaoProvider);
    final allCategories = await categoryDao.getAllCategories();
    final categoryById = {for (final c in allCategories) c.id: c};

    final List<BudgetWithSpending> result = [];

    for (final budget in budgetList) {
      // Fetch linked category IDs for this budget.
      final linkedCatIds = await budgetDao.getLinkedCategoryIds(budget.id);
      final linkedCats = linkedCatIds
          .map((id) => categoryById[id])
          .whereType<Category>()
          .toList();

      // Determine date range for the budget period.
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate;

      if (budget.period == BudgetPeriod.monthly) {
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      } else if (budget.period == BudgetPeriod.weekly) {
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = startDate.add(
            const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      } else {
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31, 23, 59, 59);
      }

      // Sum expenses across all linked categories.
      double totalSpent = 0;
      final Map<int, double> spentByCategory = {};
      for (final catId in linkedCatIds) {
        final txs = await transactionDao.getTransactionsByCategoryAndDate(
          catId,
          startDate,
          endDate,
          profileId: profileId,
        );
        double catSpent = 0;
        for (final tx in txs) {
          if (tx.type != TransactionType.expense) continue;
          final account = accountMap[tx.accountId];
          double converted;
          if (account == null || account.currency == budget.currency) {
            converted = tx.amount;
          } else {
            converted = CurrencyExchangeService.convertCurrency(
              tx.amount,
              account.currency.code,
              budget.currency.code,
              rateResult.rates,
            );
          }
          catSpent += converted;
          totalSpent += converted;
        }
        spentByCategory[catId] = catSpent;
      }

      result.add(BudgetWithSpending(
        budget: budget,
        categories: linkedCats,
        linkedCategoryCount: linkedCatIds.length,
        spentAmount: totalSpent,
        spentByCategory: spentByCategory,
      ));
    }

    result.sort((a, b) => b.progress.compareTo(a.progress));
    return result;
  });
});

/// Derives period-level summaries from [budgetsWithSpendingProvider], converting
/// each budget's amount and spent to the user's default currency for display.
final budgetPeriodSummariesProvider =
    FutureProvider.autoDispose<List<BudgetPeriodSummary>>((ref) async {
  final defaultCurrency = ref.watch(defaultCurrencyProvider);
  final exchangeService = ref.watch(currencyExchangeServiceProvider);
  final budgets = ref.watch(budgetsWithSpendingProvider).valueOrNull ?? [];

  if (budgets.isEmpty) return [];

  final rateResult = await exchangeService.getRates();

  final Map<BudgetPeriod, _PeriodAccumulator> accumulators = {};
  for (final item in budgets) {
    final acc = accumulators.putIfAbsent(
      item.budget.period,
      () => _PeriodAccumulator(),
    );
    acc.count++;
    acc.totalBudget += CurrencyExchangeService.convertCurrency(
      item.budget.amount,
      item.budget.currency.code,
      defaultCurrency.code,
      rateResult.rates,
    );
    acc.totalSpent += CurrencyExchangeService.convertCurrency(
      item.spentAmount,
      item.budget.currency.code,
      defaultCurrency.code,
      rateResult.rates,
    );
  }

  final result = accumulators.entries.map((e) {
    return BudgetPeriodSummary(
      period: e.key,
      totalBudget: e.value.totalBudget,
      totalSpent: e.value.totalSpent,
      displayCurrency: defaultCurrency,
      count: e.value.count,
    );
  }).toList();

  result.sort((a, b) => a.period.index.compareTo(b.period.index));
  return result;
});

class _PeriodAccumulator {
  int count = 0;
  double totalBudget = 0;
  double totalSpent = 0;
}
