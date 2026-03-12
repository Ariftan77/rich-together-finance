import 'dart:async';

import 'package:flutter/foundation.dart';
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

/// Model to hold budget data combined with spending info
class BudgetWithSpending {
  final Budget budget;
  final String categoryName;
  final String categoryIcon;
  final String categoryColor;
  final double spentAmount;
  final double remainingAmount;
  final double progress; // 0.0 to 1.0 (or > 1.0 if over budget)

  BudgetWithSpending({
    required this.budget,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.spentAmount,
  }) :
    remainingAmount = budget.amount - spentAmount,
    progress = (budget.amount > 0) ? (spentAmount / budget.amount) : 0.0;
}

/// Provider to get all budgets with spending calculations
final budgetsWithSpendingProvider =
    StreamProvider.autoDispose<List<BudgetWithSpending>>((ref) {
  final budgetDao = ref.watch(budgetDaoProvider);
  final transactionDao = ref.watch(transactionDaoProvider);
  final categoryDao = ref.watch(categoryDaoProvider);
  final accountDao = ref.watch(accountDaoProvider);
  final exchangeService = ref.watch(currencyExchangeServiceProvider);
  final profileId = ref.watch(activeProfileIdProvider);



  if (profileId == null) return Stream.value([]);

  // Merge budget and transaction change events into a single trigger.
  // Both Drift streams emit their current value immediately on subscription,
  // so the first trigger fires right away to produce an initial result.
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

  // Trigger an immediate first computation without waiting for Drift to emit.
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

    final budgets = await budgetDao.getAllBudgets(profileId);

    if (budgets.isEmpty) return <BudgetWithSpending>[];

    final categories = await categoryDao.getAllCategories();
    final categoriesMap = {for (var c in categories) c.id: c};

    final List<BudgetWithSpending> result = [];

    for (final budget in budgets) {
      final category = categoriesMap[budget.categoryId];
      if (category == null) continue;

      // Determine date range for the budget period
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

      final transactions = await transactionDao.getTransactionsByCategoryAndDate(
        budget.categoryId,
        startDate,
        endDate,
        profileId: profileId,
      );

      // Sum expenses, converting each to the budget's own currency
      double totalSpent = 0;
      for (final tx in transactions) {
        if (tx.type != TransactionType.expense) continue;
        final account = accountMap[tx.accountId];
        if (account == null || account.currency == budget.currency) {
          totalSpent += tx.amount;
        } else {
          totalSpent += CurrencyExchangeService.convertCurrency(
            tx.amount,
            account.currency.code,
            budget.currency.code,
            rateResult.rates,
          );
        }
      }

      result.add(BudgetWithSpending(
        budget: budget,
        categoryName: category.name,
        categoryIcon: category.icon,
        categoryColor: category.color ?? '#808080',
        spentAmount: totalSpent,
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

  // Sort by period order: weekly → monthly → yearly
  result.sort((a, b) => a.period.index.compareTo(b.period.index));
  return result;
});

class _PeriodAccumulator {
  int count = 0;
  double totalBudget = 0;
  double totalSpent = 0;
}
