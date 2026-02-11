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
/// Monthly income for current month
final dashboardMonthlyIncomeProvider = StreamProvider.autoDispose<double>((ref) {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return Stream.value(0);
  
  final transactionDao = ref.watch(transactionDaoProvider);
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  
  return transactionDao.watchTotalByType(
    profileId, 
    TransactionType.income, 
    startOfMonth, 
    endOfMonth
  );
});

/// Monthly expenses for current month
/// Monthly expenses for current month
final dashboardMonthlyExpenseProvider = StreamProvider.autoDispose<double>((ref) {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return Stream.value(0);
  
  final transactionDao = ref.watch(transactionDaoProvider);
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  
  return transactionDao.watchTotalByType(
    profileId, 
    TransactionType.expense, 
    startOfMonth, 
    endOfMonth
  );
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

final dashboardCategoryBreakdownProvider = StreamProvider.autoDispose<List<CategoryBreakdown>>((ref) {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return Stream.value([]);
  
  final transactionDao = ref.watch(transactionDaoProvider);
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  
  return transactionDao.watchCategoryExpenseTotals(profileId, startOfMonth, endOfMonth).map((dtos) {
    // Calculate total for percentage
    final total = dtos.fold<double>(0, (sum, item) => sum + item.amount);
    
    return dtos.map((dto) {
      return CategoryBreakdown(
        categoryName: dto.name,
        amount: dto.amount,
        percentage: total > 0 ? ((dto.amount / total) * 100) : 0,
      );
    }).take(5).toList();
  });
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

final dashboardCashFlowProvider = StreamProvider.autoDispose<List<MonthlyFlow>>((ref) {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return Stream.value([]);
  
  final transactionDao = ref.watch(transactionDaoProvider);
  final now = DateTime.now();
  
  // Calculate range for last 6 months
  final startOfPeriod = DateTime(now.year, now.month - 5, 1);
  final endOfPeriod = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  
  return transactionDao.watchTransactionsInRange(profileId, startOfPeriod, endOfPeriod).map((transactions) {
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
    
    return flows;
  });
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
