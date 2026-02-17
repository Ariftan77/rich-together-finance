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

  /// Get all transactions for a profile ordered by date descending
  Future<List<Transaction>> getAllTransactions(int profileId) =>
      (select(transactions)
        ..where((t) => t.profileId.equals(profileId))
        ..orderBy([(t) => OrderingTerm.desc(t.date)])).get();

  /// Get transactions for a specific account
  Future<List<Transaction>> getTransactionsByAccount(int accountId) =>
      (select(transactions)
            ..where((t) => t.accountId.equals(accountId) | t.toAccountId.equals(accountId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  /// Get transactions by type for a profile
  Future<List<Transaction>> getTransactionsByType(int profileId, TransactionType type) =>
      (select(transactions)
            ..where((t) => t.profileId.equals(profileId) & t.type.equals(type.index))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  /// Get transactions by category
  Future<List<Transaction>> getTransactionsByCategory(int categoryId) =>
      (select(transactions)
            ..where((t) => t.categoryId.equals(categoryId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  /// Get transactions within date range for a profile
  Future<List<Transaction>> getTransactionsInRange(int profileId, DateTime start, DateTime end) =>
      (select(transactions)
            ..where((t) => t.profileId.equals(profileId) & t.date.isBiggerOrEqualValue(start) & t.date.isSmallerOrEqualValue(end))
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

  /// Watch all transactions for a profile (reactive stream)
  Stream<List<Transaction>> watchAllTransactions(int profileId) =>
      (select(transactions)
        ..where((t) => t.profileId.equals(profileId))
        ..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();

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

  /// Find a transaction that likely matches a debt creation
  /// Matches on accountId, amount, and approximate time
  Future<Transaction?> findDebtTransaction({
    required int accountId,
    required double amount,
    required DateTime date,
  }) async {
    // Look for transactions within 1 minute of debt creation
    final start = date.subtract(const Duration(minutes: 1));
    final end = date.add(const Duration(minutes: 1));
    
    return (select(transactions)
      ..where((t) => 
        t.accountId.equals(accountId) & 
        t.amount.equals(amount) & 
        t.date.isBiggerOrEqualValue(start) & 
        t.date.isSmallerOrEqualValue(end)
      )
      ..limit(1)
    ).getSingleOrNull();
  }

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

  /// Get monthly totals for income and expense for a profile
  Future<Map<String, double>> getMonthlySummary(int profileId, int year, int month) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

    final txs = await getTransactionsInRange(profileId, startDate, endDate);

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
  Stream<List<Transaction>> watchFilteredTransactions({
    required int profileId,
    required int limit,
    String? searchQuery,
    int? accountId,
    TransactionType? type,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    final query = select(transactions).join([
      leftOuterJoin(accounts, accounts.id.equalsExp(transactions.accountId)),
      leftOuterJoin(categories, categories.id.equalsExp(transactions.categoryId)),
    ]);

    query.where(transactions.profileId.equals(profileId));

    if (accountId != null) {
      query.where(transactions.accountId.equals(accountId) | transactions.toAccountId.equals(accountId));
    }

    if (type != null) {
      query.where(transactions.type.equals(type.index));
    }

    if (dateFrom != null) {
      query.where(transactions.date.isBiggerOrEqualValue(dateFrom));
    }

    if (dateTo != null) {
      query.where(transactions.date.isSmallerOrEqualValue(dateTo));
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final term = '%${searchQuery.toLowerCase()}%';
      query.where(
        transactions.title.lower().like(term) |
        transactions.note.lower().like(term) |
        transactions.amount.cast<String>().like(term) | 
        accounts.name.lower().like(term) |
        categories.name.lower().like(term)
      );
    }

    query.orderBy([OrderingTerm.desc(transactions.date)]);
    query.limit(limit);

    return query.map((row) => row.readTable(transactions)).watch();
  }

  /// Watch total amount for a type within date range (Optimized for Dashboard)
  Stream<double> watchTotalByType(int profileId, TransactionType type, DateTime start, DateTime end) {
    final amountSum = transactions.amount.sum();
    final query = selectOnly(transactions)
      ..addColumns([amountSum])
      ..where(transactions.profileId.equals(profileId))
      ..where(transactions.type.equals(type.index))
      ..where(transactions.date.isBiggerOrEqualValue(start))
      ..where(transactions.date.isSmallerOrEqualValue(end));
      
    return query.watchSingle().map((row) => row.read(amountSum) ?? 0);
  }

  /// Watch category totals for expenses (Optimized for Dashboard)
  Stream<List<CategoryTotalDTO>> watchCategoryExpenseTotals(int profileId, DateTime start, DateTime end) {
    final amountSum = transactions.amount.sum();
    
    final query = select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId))
    ])
      ..addColumns([categories.name, amountSum])
      ..where(transactions.profileId.equals(profileId))
      ..where(transactions.type.equals(TransactionType.expense.index))
      ..where(transactions.date.isBiggerOrEqualValue(start))
      ..where(transactions.date.isSmallerOrEqualValue(end))
      ..groupBy([transactions.categoryId]);
      
    query.orderBy([OrderingTerm.desc(amountSum)]);
    
    return query.watch().map((rows) {
      return rows.map((row) {
        return CategoryTotalDTO(
          name: row.read(categories.name)!,
          amount: row.read(amountSum) ?? 0,
        );
      }).toList();
    });
  }

  /// Watch transactions within date range (Optimized for CashFlow)
  Stream<List<Transaction>> watchTransactionsInRange(int profileId, DateTime start, DateTime end) =>
      (select(transactions)
            ..where((t) => t.profileId.equals(profileId) & 
                           t.date.isBiggerOrEqualValue(start) & 
                           t.date.isSmallerOrEqualValue(end))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .watch();

  /// Get most frequent transaction titles
  Future<List<String>> getMostFrequentTitles(int limit) {
    final count = transactions.id.count();
    final query = selectOnly(transactions)
      ..addColumns([transactions.title, count])
      ..where(transactions.title.isNotNull() & transactions.title.length.isBiggerThanValue(0))
      ..groupBy([transactions.title])
      ..orderBy([OrderingTerm.desc(count)])
      ..limit(limit);

    return query.map((row) => row.read(transactions.title)!).get();
  }

  /// Watch categories with usage count
  Stream<List<CategoryWithUsage>> watchCategoriesWithUsageCount(int profileId) {
    final usageCount = transactions.id.count();
    
    final query = select(categories).join([
      leftOuterJoin(transactions, transactions.categoryId.equalsExp(categories.id)),
    ])
      ..addColumns([usageCount])
      ..where(categories.profileId.equals(profileId) | categories.profileId.isNull())
      ..groupBy([categories.id])
      ..orderBy([OrderingTerm.asc(categories.sortOrder)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final category = row.readTable(categories);
        final count = row.read(usageCount) ?? 0;
        return CategoryWithUsage(category: category, usageCount: count);
      }).toList();
    });
  }
}

class CategoryTotalDTO {
  final String name;
  final double amount;
  
  CategoryTotalDTO({required this.name, required this.amount});
}

class CategoryWithUsage {
  final Category category;
  final int usageCount;
  
  CategoryWithUsage({required this.category, required this.usageCount});
}
