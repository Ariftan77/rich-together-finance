import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../database/daos/account_dao.dart';
import '../database/daos/transaction_dao.dart';
import '../database/daos/category_dao.dart';
import '../database/daos/holding_dao.dart';
import '../database/daos/budget_dao.dart';
import '../database/daos/goal_dao.dart';
import '../database/daos/debt_dao.dart';
import '../database/daos/recurring_dao.dart';

/// Database provider - singleton instance
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Account DAO provider
final accountDaoProvider = Provider<AccountDao>((ref) {
  final db = ref.watch(databaseProvider);
  return AccountDao(db);
});

/// Transaction DAO provider
final transactionDaoProvider = Provider<TransactionDao>((ref) {
  final db = ref.watch(databaseProvider);
  return TransactionDao(db);
});

/// Category DAO provider
final categoryDaoProvider = Provider<CategoryDao>((ref) {
  final db = ref.watch(databaseProvider);
  return CategoryDao(db);
});

/// Holding DAO provider
final holdingDaoProvider = Provider<HoldingDao>((ref) {
  final db = ref.watch(databaseProvider);
  return HoldingDao(db);
});

/// Budget DAO provider
final budgetDaoProvider = Provider<BudgetDao>((ref) {
  final db = ref.watch(databaseProvider);
  return BudgetDao(db);
});

/// Goal DAO provider
final goalDaoProvider = Provider<GoalDao>((ref) {
  final db = ref.watch(databaseProvider);
  return GoalDao(db);
});

/// Debt DAO provider
final debtDaoProvider = Provider<DebtDao>((ref) {
  final db = ref.watch(databaseProvider);
  return DebtDao(db);
});

/// Recurring DAO provider
final recurringDaoProvider = Provider<RecurringDao>((ref) {
  final db = ref.watch(databaseProvider);
  return RecurringDao(db);
});

// ============================================
// Stream Providers for reactive data
// ============================================

/// All accounts stream
final accountsStreamProvider = StreamProvider<List<Account>>((ref) {
  final accountDao = ref.watch(accountDaoProvider);
  return accountDao.watchAllAccounts();
});

/// All transactions stream
final transactionsStreamProvider = StreamProvider<List<Transaction>>((ref) {
  final transactionDao = ref.watch(transactionDaoProvider);
  return transactionDao.watchAllTransactions();
});

/// All categories stream
final categoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  final categoryDao = ref.watch(categoryDaoProvider);
  return categoryDao.watchAllCategories();
});

/// All holdings stream
final holdingsStreamProvider = StreamProvider<List<Holding>>((ref) {
  final holdingDao = ref.watch(holdingDaoProvider);
  return holdingDao.watchAllHoldings();
});

/// All budgets stream
final budgetsStreamProvider = StreamProvider<List<Budget>>((ref) {
  final budgetDao = ref.watch(budgetDaoProvider);
  return budgetDao.watchAllBudgets();
});

/// Active goals stream
final goalsStreamProvider = StreamProvider<List<Goal>>((ref) {
  final goalDao = ref.watch(goalDaoProvider);
  return goalDao.watchActiveGoals();
});

/// Unsettled debts stream
final debtsStreamProvider = StreamProvider<List<Debt>>((ref) {
  final debtDao = ref.watch(debtDaoProvider);
  return debtDao.watchUnsettledDebts();
});

/// Active recurring stream
final recurringStreamProvider = StreamProvider<List<RecurringData>>((ref) {
  final recurringDao = ref.watch(recurringDaoProvider);
  return recurringDao.watchAllRecurring();
});
