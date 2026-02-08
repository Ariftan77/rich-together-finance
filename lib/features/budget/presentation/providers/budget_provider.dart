import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';
import 'package:collection/collection.dart';

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
final budgetsWithSpendingProvider = StreamProvider.autoDispose<List<BudgetWithSpending>>((ref) async* {
  final budgetDao = ref.watch(budgetDaoProvider);
  final transactionDao = ref.watch(transactionDaoProvider);
  final categoryDao = ref.watch(categoryDaoProvider);

  // Watch all active budgets
  final budgetsStream = budgetDao.watchAllBudgets();
  
  // Combine with transactions
  // Note: For simplicity in this stream, we might just fetch transactions whenever budgets change
  // or ideally watch both.
  
  await for (final budgets in budgetsStream) {
    if (budgets.isEmpty) {
      yield [];
      continue;
    }

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

      // Logic for period (Monthly is default/most common)
      if (budget.period == BudgetPeriod.monthly) {
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      } else if (budget.period == BudgetPeriod.weekly) {
        // Start of week (Monday)
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = startDate.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      } else {
        // Yearly
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31, 23, 59, 59);
      }

      // Calculate spending for this category in this period
      // expenses only
      final transactions = await transactionDao.getTransactionsByCategoryAndDate(
        budget.categoryId,
        startDate,
        endDate,
      );

      // Filter only expenses
      final expenses = transactions.where((t) => t.type == TransactionType.expense.index);
      final totalSpent = expenses.fold(0.0, (sum, t) => sum + t.amount);

      result.add(BudgetWithSpending(
        budget: budget,
        categoryName: category.name,
        categoryIcon: category.icon,
        categoryColor: category.color ?? '#808080', // Default grey if null
        spentAmount: totalSpent,
      ));
    }

    yield result;
  }
});
