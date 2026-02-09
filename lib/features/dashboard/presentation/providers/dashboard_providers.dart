import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/enums.dart';

/// Total balance across all accounts
final dashboardTotalBalanceProvider = StreamProvider.autoDispose<double>((ref) async* {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) {
    yield 0;
    return;
  }
  
  final accountDao = ref.watch(accountDaoProvider);
  final transactionDao = ref.watch(transactionDaoProvider);
  
  await for (final accounts in accountDao.watchAllAccounts(profileId)) {
    double total = 0;
    for (final account in accounts) {
      final balance = await transactionDao.calculateAccountBalance(account.id);
      total += balance;
    }
    yield total;
  }
});

/// Net worth (assets - liabilities)
final dashboardNetWorthProvider = StreamProvider.autoDispose<double>((ref) async* {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) {
    yield 0;
    return;
  }
  
  final accountDao = ref.watch(accountDaoProvider);
  final transactionDao = ref.watch(transactionDaoProvider);
  final debtDao = ref.watch(debtDaoProvider);
  
  // Get total assets (account balances)
  double totalAssets = 0;
  await for (final accounts in accountDao.watchAllAccounts(profileId)) {
    for (final account in accounts) {
      final balance = await transactionDao.calculateAccountBalance(account.id);
      totalAssets += balance;
    }
    
    // Get total liabilities (debts payable)
    final debts = await debtDao.getAllDebts();
    double totalLiabilities = 0;
    for (final debt in debts) {
      if (debt.type == DebtType.payable) {
        totalLiabilities += debt.amount;
      }
    }
    
    yield totalAssets - totalLiabilities;
    break; // Only emit once per account update
  }
});

/// Monthly income for current month
final dashboardMonthlyIncomeProvider = StreamProvider.autoDispose<double>((ref) async* {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) {
    yield 0;
    return;
  }
  
  final transactionDao = ref.watch(transactionDaoProvider);
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  
  await for (final transactions in transactionDao.watchAllTransactions(profileId)) {
    double total = 0;
    for (final t in transactions) {
      if (t.type == TransactionType.income &&
          t.date.isAfter(startOfMonth) &&
          t.date.isBefore(endOfMonth)) {
        total += t.amount;
      }
    }
    yield total;
  }
});

/// Monthly expenses for current month
final dashboardMonthlyExpenseProvider = StreamProvider.autoDispose<double>((ref) async* {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) {
    yield 0;
    return;
  }
  
  final transactionDao = ref.watch(transactionDaoProvider);
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  
  await for (final transactions in transactionDao.watchAllTransactions(profileId)) {
    double total = 0;
    for (final t in transactions) {
      if (t.type == TransactionType.expense &&
          t.date.isAfter(startOfMonth) &&
          t.date.isBefore(endOfMonth)) {
        total += t.amount;
      }
    }
    yield total;
  }
});

/// Category breakdown data for current month
class CategoryBreakdown {
  final String categoryName;
  final double amount;
  final double percentage;
  
  CategoryBreakdown({
    required this.categoryName,
    required this.amount,
    required this.percentage,
  });
}

final dashboardCategoryBreakdownProvider = StreamProvider.autoDispose<List<CategoryBreakdown>>((ref) async* {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) {
    yield [];
    return;
  }
  
  final transactionDao = ref.watch(transactionDaoProvider);
  final categoryDao = ref.watch(categoryDaoProvider);
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  
  await for (final transactions in transactionDao.watchAllTransactions(profileId)) {
    // Get all categories
    final categories = await categoryDao.getAllCategories();
    final categoryMap = {for (var c in categories) c.id: c.name};
    
    // Group expenses by category
    final Map<int, double> categoryTotals = {};
    double totalExpenses = 0;
    
    for (final t in transactions) {
      if (t.type == TransactionType.expense &&
          t.categoryId != null &&
          t.date.isAfter(startOfMonth) &&
          t.date.isBefore(endOfMonth)) {
        categoryTotals[t.categoryId!] = (categoryTotals[t.categoryId!] ?? 0) + t.amount;
        totalExpenses += t.amount;
      }
    }
    
    // Convert to CategoryBreakdown list
    final breakdowns = categoryTotals.entries.map((entry) {
      final categoryName = categoryMap[entry.key] ?? 'Unknown';
      final amount = entry.value;
      final percentage = totalExpenses > 0 ? ((amount / totalExpenses) * 100).toDouble() : 0.0;
      
      return CategoryBreakdown(
        categoryName: categoryName,
        amount: amount,
        percentage: percentage,
      );
    }).toList();
    
    // Sort by amount descending and take top 5
    breakdowns.sort((a, b) => b.amount.compareTo(a.amount));
    yield breakdowns.take(5).toList();
  }
});

/// Cash flow data for last 6 months
class MonthlyFlow {
  final String month; // e.g., "Jan", "Feb"
  final double income;
  final double expense;
  
  MonthlyFlow({
    required this.month,
    required this.income,
    required this.expense,
  });
}

final dashboardCashFlowProvider = StreamProvider.autoDispose<List<MonthlyFlow>>((ref) async* {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) {
    yield [];
    return;
  }
  
  final transactionDao = ref.watch(transactionDaoProvider);
  final now = DateTime.now();
  
  await for (final transactions in transactionDao.watchAllTransactions(profileId)) {
    final List<MonthlyFlow> flows = [];
    
    // Calculate for last 6 months
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
      
      double income = 0;
      double expense = 0;
      
      for (final t in transactions) {
        if (t.date.isAfter(startOfMonth) && t.date.isBefore(endOfMonth)) {
          if (t.type == TransactionType.income) {
            income += t.amount;
          } else if (t.type == TransactionType.expense) {
            expense += t.amount;
          }
        }
      }
      
      // Month name (Jan, Feb, etc.)
      final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final monthName = monthNames[month.month - 1];
      
      flows.add(MonthlyFlow(
        month: monthName,
        income: income,
        expense: expense,
      ));
    }
    
    yield flows.toList();
  }
});

/// Recent transactions (last 10)
final dashboardRecentTransactionsProvider = StreamProvider.autoDispose<List<Transaction>>((ref) {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return Stream.value([]);
  
  final transactionDao = ref.watch(transactionDaoProvider);
  
  return transactionDao.watchAllTransactions(profileId).map((transactions) {
    // Already sorted by date descending in DAO
    return transactions.take(10).toList();
  });
});
