import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/transactions.dart';
import '../tables/accounts.dart';
import '../tables/categories.dart';
import '../../models/enums.dart';

part 'transaction_dao.g.dart';

/// Data Access Object for Transaction operations
@DriftAccessor(tables: [Transactions, Accounts, Categories])
class TransactionDao extends DatabaseAccessor<AppDatabase> with _$TransactionDaoMixin {
  TransactionDao(super.db);

  /// Get all transactions ordered by date descending
  Future<List<Transaction>> getAllTransactions() =>
      (select(transactions)..orderBy([(t) => OrderingTerm.desc(t.date)])).get();

  /// Get transactions for a specific account
  Future<List<Transaction>> getTransactionsByAccount(int accountId) =>
      (select(transactions)
            ..where((t) => t.accountId.equals(accountId) | t.toAccountId.equals(accountId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  /// Get transactions by type
  Future<List<Transaction>> getTransactionsByType(TransactionType type) =>
      (select(transactions)
            ..where((t) => t.type.equals(type.index))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  /// Get transactions by category
  Future<List<Transaction>> getTransactionsByCategory(int categoryId) =>
      (select(transactions)
            ..where((t) => t.categoryId.equals(categoryId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  /// Get transactions within date range
  Future<List<Transaction>> getTransactionsInRange(DateTime start, DateTime end) =>
      (select(transactions)
            ..where((t) => t.date.isBiggerOrEqualValue(start) & t.date.isSmallerOrEqualValue(end))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  /// Get transactions by category within date range
  Future<List<Transaction>> getTransactionsByCategoryAndDate(int categoryId, DateTime start, DateTime end) =>
      (select(transactions)
            ..where((t) => t.categoryId.equals(categoryId) & 
                           t.date.isBiggerOrEqualValue(start) & 
                           t.date.isSmallerOrEqualValue(end))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  /// Watch all transactions (reactive stream)
  Stream<List<Transaction>> watchAllTransactions() =>
      (select(transactions)..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();

  /// Watch transactions for a specific account
  Stream<List<Transaction>> watchTransactionsByAccount(int accountId) =>
      (select(transactions)
            ..where((t) => t.accountId.equals(accountId) | t.toAccountId.equals(accountId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .watch();

  /// Create a new transaction
  Future<int> insertTransaction(TransactionsCompanion transaction) =>
      into(transactions).insert(transaction);

  /// Get transaction by ID
  Future<Transaction?> getTransactionById(int id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Update a transaction by ID with companion
  Future<int> updateTransaction(int id, TransactionsCompanion transaction) =>
      (update(transactions)..where((t) => t.id.equals(id))).write(transaction);

  /// Delete a transaction
  Future<int> deleteTransaction(int id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  /// Calculate account balance
  /// balance = initialBalance + sum(income) - sum(expense) + sum(transfer_in) - sum(transfer_out)
  Future<double> calculateAccountBalance(int accountId) async {
    final account = await (select(db.accounts)..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (account == null) return 0;

    double balance = account.initialBalance;

    // Get all transactions for this account
    final txs = await getTransactionsByAccount(accountId);

    for (final tx in txs) {
      if (tx.accountId == accountId) {
        // Transaction is FROM this account
        switch (tx.type) {
          case TransactionType.income:
            balance += tx.amount;
            break;
          case TransactionType.expense:
            balance -= tx.amount;
            break;
          case TransactionType.transfer:
            balance -= tx.amount;
            break;
        }
      } else if (tx.toAccountId == accountId) {
        // Transaction is TO this account (transfer)
        balance += tx.destinationAmount ?? tx.amount;
      }
    }

    return balance;
  }

  /// Get monthly totals for income and expense
  Future<Map<String, double>> getMonthlySummary(int year, int month) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

    final txs = await getTransactionsInRange(startDate, endDate);

    double income = 0;
    double expense = 0;

    for (final tx in txs) {
      if (tx.type == TransactionType.income) {
        income += tx.amount;
      } else if (tx.type == TransactionType.expense) {
        expense += tx.amount;
      }
    }

    return {'income': income, 'expense': expense};
  }
}
