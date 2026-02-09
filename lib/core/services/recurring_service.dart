import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../database/daos/recurring_dao.dart';
import '../database/daos/transaction_dao.dart';
import '../providers/database_providers.dart';
// import '../models/enums.dart'; // Not needed if using DAO logic

final recurringServiceProvider = Provider<RecurringService>((ref) {
  return RecurringService(ref);
});

class RecurringService {
  final Ref _ref;

  RecurringService(this._ref);

  /// Checks for due recurring transactions and generates them
  Future<void> checkAndGenerateRecurringTransactions() async {
    final recurringDao = _ref.read(recurringDaoProvider);
    final transactionDao = _ref.read(transactionDaoProvider);

    // Get all recurring transactions due today or earlier
    final dueRecurring = await recurringDao.getDueRecurring();

    for (final recurring in dueRecurring) {
      await _processRecurringTransaction(recurring, recurringDao, transactionDao);
    }
  }

  Future<void> _processRecurringTransaction(
    RecurringData recurring,
    RecurringDao recurringDao,
    TransactionDao transactionDao,
  ) async {
    DateTime contextDate = recurring.nextDate;
    final now = DateTime.now();

    // Loop to catch up missed transactions
    while (contextDate.isBefore(now) || contextDate.isAtSameMomentAs(now)) {
      // 1. Create Transaction
      await transactionDao.insertTransaction(
        TransactionsCompanion(
          profileId: Value(recurring.profileId),
          accountId: Value(recurring.accountId),
          categoryId: recurring.categoryId != null ? Value(recurring.categoryId!) : const Value.absent(),
          toAccountId: recurring.toAccountId != null ? Value(recurring.toAccountId!) : const Value.absent(),
          type: Value(recurring.type),
          amount: Value(recurring.amount),
          date: Value(contextDate),
          note: Value(recurring.name), // Use recurring name as note
          recurringId: Value(recurring.id),
          createdAt: Value(DateTime.now()),
        ),
      );

      // 2. Calculate Next Date
      contextDate = recurringDao.calculateNextDate(contextDate, recurring.frequency);
      
      // Stop if end date passed
      if (recurring.endDate != null && contextDate.isAfter(recurring.endDate!)) {
        await recurringDao.deactivateRecurring(recurring.id);
        break;
      }
    }

    // 3. Update Recurring Entry with new Next Date
    await recurringDao.updateNextDate(recurring.id, contextDate);
  }
}
