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

  /// Get transactions by category within date range, optionally filtered by profile
  Future<List<Transaction>> getTransactionsByCategoryAndDate(int categoryId, DateTime start, DateTime end, {int? profileId}) =>
      (select(transactions)
            ..where((t) {
              var condition = t.categoryId.equals(categoryId) &
                           t.date.isBiggerOrEqualValue(start) &
                           t.date.isSmallerOrEqualValue(end);
              if (profileId != null) {
                condition = condition & t.profileId.equals(profileId);
              }
              return condition;
            })
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
  Future<int> insertTransaction(TransactionsCompanion transaction) async {
    final id = await into(transactions).insert(transaction);
    if (transaction.date.present) {
      final date = transaction.date.value;
      if (transaction.accountId.present) {
        await _updateAccountActivity(transaction.accountId.value, date);
      }
      if (transaction.toAccountId.present && transaction.toAccountId.value != null) {
        await _updateAccountActivity(transaction.toAccountId.value!, date);
      }
    }
    return id;
  }

  /// Get transaction by ID
  Future<Transaction?> getTransactionById(int id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Update a transaction by ID with companion
  Future<int> updateTransaction(int id, TransactionsCompanion transaction) async {
    final result = await (update(transactions)..where((t) => t.id.equals(id))).write(transaction);
    if (transaction.date.present) {
      final date = transaction.date.value;
      if (transaction.accountId.present) {
        await _updateAccountActivity(transaction.accountId.value, date);
      }
      if (transaction.toAccountId.present && transaction.toAccountId.value != null) {
        await _updateAccountActivity(transaction.toAccountId.value!, date);
      }
    }
    return result;
  }

  /// Delete a transaction
  Future<int> deleteTransaction(int id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  Future<void> _updateAccountActivity(int accountId, DateTime date) async {
    final account = await (select(accounts)..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (account != null) {
      // Only update if new date is newer than current, or if current is null
      if (account.lastActivityDate == null || date.isAfter(account.lastActivityDate!)) {
        await (update(accounts)..where((a) => a.id.equals(accountId)))
            .write(AccountsCompanion(lastActivityDate: Value(date)));
      }
    }
  }

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
          case TransactionType.adjustmentIn:
            balance += tx.amount;
            break;
          case TransactionType.adjustmentOut:
            balance -= tx.amount;
            break;
          case TransactionType.debtIn:
            balance += tx.amount;
            break;
          case TransactionType.debtOut:
            balance -= tx.amount;
            break;
          case TransactionType.debtPaymentOut:
            balance -= tx.amount;
            break;
          case TransactionType.debtPaymentIn:
            balance += tx.amount;
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
    List<TransactionType>? types,
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

    if (types != null && types.isNotEmpty) {
      query.where(transactions.type.isIn(types.map((t) => t.index).toList()));
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

  /// Watch the latest (max) transaction date for a profile — used to determine upper bound for month navigation
  Stream<DateTime?> watchLatestTransactionDate(int profileId) {
    final maxDate = transactions.date.max();
    final query = selectOnly(transactions)
      ..addColumns([maxDate])
      ..where(transactions.profileId.equals(profileId));
    return query.watchSingle().map((row) => row.read(maxDate));
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

  /// Get most frequent transaction titles filtered by transaction type and profile
  Future<List<String>> getMostFrequentTitlesByType(TransactionType type, int limit, {int? profileId}) {
    final count = transactions.id.count();
    var condition = transactions.title.isNotNull() &
        transactions.title.length.isBiggerThanValue(0) &
        transactions.type.equalsValue(type);
    if (profileId != null) {
      condition = condition & transactions.profileId.equals(profileId);
    }
    final query = selectOnly(transactions)
      ..addColumns([transactions.title, count])
      ..where(condition)
      ..groupBy([transactions.title])
      ..orderBy([OrderingTerm.desc(count)])
      ..limit(limit);

    return query.map((row) => row.read(transactions.title)!).get();
  }

  /// Get the most frequently used account ID for a given title and type
  Future<int?> getMostUsedAccountForTitle(String title, TransactionType type, {int? profileId}) async {
    final count = transactions.id.count();
    var condition = transactions.title.equals(title) &
        transactions.type.equalsValue(type);
    if (profileId != null) {
      condition = condition & transactions.profileId.equals(profileId);
    }
    final query = selectOnly(transactions)
      ..addColumns([transactions.accountId, count])
      ..where(condition)
      ..groupBy([transactions.accountId])
      ..orderBy([OrderingTerm.desc(count)])
      ..limit(1);

    final rows = await query.get();
    if (rows.isEmpty) return null;
    return rows.first.read(transactions.accountId);
  }

  /// Get the most frequently used category ID for a given title and type
  Future<int?> getMostUsedCategoryForTitle(String title, TransactionType type, {int? profileId}) async {
    final count = transactions.id.count();
    var condition = transactions.title.equals(title) &
        transactions.type.equalsValue(type) &
        transactions.categoryId.isNotNull();
    if (profileId != null) {
      condition = condition & transactions.profileId.equals(profileId);
    }
    final query = selectOnly(transactions)
      ..addColumns([transactions.categoryId, count])
      ..where(condition)
      ..groupBy([transactions.categoryId])
      ..orderBy([OrderingTerm.desc(count)])
      ..limit(1);

    final rows = await query.get();
    if (rows.isEmpty) return null;
    return rows.first.read(transactions.categoryId);
  }

  // ---------------------------------------------------------------------------
  // Batch balance helpers
  // ---------------------------------------------------------------------------

  /// Returns a stream that emits a map of accountId → net transaction delta
  /// (i.e. sum of signed amounts) for every account in the given profile.
  ///
  /// The SQL aggregates in one round-trip using a CASE expression:
  ///   • +amount for types that add to the account balance (income, adjustmentIn,
  ///     debtIn, debtPaymentIn, and transfer-destination rows)
  ///   • −amount for types that subtract (expense, adjustmentOut, debtOut,
  ///     debtPaymentOut, and transfer-source rows)
  ///
  /// Callers must still add `account.initialBalance` to each value because that
  /// is stored on the Account row, not in the transactions table.
  ///
  /// Transfer destination amounts use `COALESCE(destination_amount, amount)` so
  /// cross-currency transfers are handled correctly (mirrors calculateAccountBalance).
  Stream<Map<int, double>> watchAllAccountBalanceDeltas(int profileId) {
    // Types that ADD to the source account (accountId column):
    //   income=0, adjustmentIn=3, debtIn=5, debtPaymentIn=8
    // Types that SUBTRACT from the source account (accountId column):
    //   expense=1, transfer=2, adjustmentOut=4, debtOut=6, debtPaymentOut=7
    //
    // We emit two rows per transfer: one for the source account (negative) via
    // the accountId GROUP, and one for the destination account (positive) via a
    // UNION on toAccountId.  Both are then summed by a wrapping GROUP BY.
    const sql = '''
      SELECT account_id, SUM(signed_amount) AS delta
      FROM (
        -- Source-account legs (all transaction types)
        SELECT
          account_id,
          CASE
            WHEN "type" IN (0, 3, 5, 8) THEN  amount
            ELSE                              -amount
          END AS signed_amount
        FROM transactions
        WHERE profile_id = ? AND deleted_at IS NULL

        UNION ALL

        -- Destination-account legs (transfers only, using destinationAmount when present)
        SELECT
          to_account_id AS account_id,
          COALESCE(destination_amount, amount) AS signed_amount
        FROM transactions
        WHERE profile_id = ? AND "type" = 2 AND to_account_id IS NOT NULL AND deleted_at IS NULL
      )
      GROUP BY account_id
    ''';

    return customSelect(sql, variables: [
      Variable.withInt(profileId),
      Variable.withInt(profileId),
    ], readsFrom: {transactions}).watch().map((rows) {
      final map = <int, double>{};
      for (final row in rows) {
        map[row.read<int>('account_id')] = row.read<double>('delta');
      }
      return map;
    });
  }

  /// One-shot (non-streaming) version of [watchAllAccountBalanceDeltas].
  /// Use this when you need a single fetch rather than a reactive stream.
  Future<Map<int, double>> getAllAccountBalanceDeltas(int profileId) async {
    const sql = '''
      SELECT account_id, SUM(signed_amount) AS delta
      FROM (
        SELECT
          account_id,
          CASE
            WHEN "type" IN (0, 3, 5, 8) THEN  amount
            ELSE                              -amount
          END AS signed_amount
        FROM transactions
        WHERE profile_id = ? AND deleted_at IS NULL

        UNION ALL

        SELECT
          to_account_id AS account_id,
          COALESCE(destination_amount, amount) AS signed_amount
        FROM transactions
        WHERE profile_id = ? AND "type" = 2 AND to_account_id IS NOT NULL AND deleted_at IS NULL
      )
      GROUP BY account_id
    ''';

    final rows = await customSelect(sql, variables: [
      Variable.withInt(profileId),
      Variable.withInt(profileId),
    ], readsFrom: {transactions}).get();

    final map = <int, double>{};
    for (final row in rows) {
      map[row.read<int>('account_id')] = row.read<double>('delta');
    }
    return map;
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
