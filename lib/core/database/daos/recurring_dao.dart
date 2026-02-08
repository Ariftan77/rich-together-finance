import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/recurring.dart';
import '../../models/enums.dart';

part 'recurring_dao.g.dart';

/// Data Access Object for Recurring Transaction operations
@DriftAccessor(tables: [Recurring])
class RecurringDao extends DatabaseAccessor<AppDatabase> with _$RecurringDaoMixin {
  RecurringDao(super.db);

  /// Get all active recurring transactions
  Future<List<RecurringData>> getAllRecurring() =>
      (select(recurring)..where((r) => r.isActive)).get();

  /// Get recurring transactions due today or earlier
  Future<List<RecurringData>> getDueRecurring() =>
      (select(recurring)
            ..where((r) => r.isActive & r.nextDate.isSmallerOrEqualValue(DateTime.now())))
          .get();

  /// Get recurring by ID
  Future<RecurringData?> getRecurringById(int id) =>
      (select(recurring)..where((r) => r.id.equals(id))).getSingleOrNull();

  /// Watch all active recurring (reactive stream)
  Stream<List<RecurringData>> watchAllRecurring() =>
      (select(recurring)..where((r) => r.isActive)).watch();

  /// Create a new recurring transaction
  Future<int> createRecurring(RecurringCompanion recurringData) =>
      into(recurring).insert(recurringData);

  /// Update a recurring transaction
  Future<bool> updateRecurring(RecurringData recurringData) =>
      update(recurring).replace(recurringData);

  /// Update next date after creating transaction
  Future<int> updateNextDate(int id, DateTime nextDate) =>
      (update(recurring)..where((r) => r.id.equals(id)))
          .write(RecurringCompanion(nextDate: Value(nextDate)));

  /// Deactivate a recurring transaction
  Future<int> deactivateRecurring(int id) =>
      (update(recurring)..where((r) => r.id.equals(id)))
          .write(const RecurringCompanion(isActive: Value(false)));

  /// Delete a recurring transaction
  Future<int> deleteRecurring(int id) =>
      (delete(recurring)..where((r) => r.id.equals(id))).go();

  /// Calculate next date based on frequency
  DateTime calculateNextDate(DateTime current, RecurringFrequency frequency) {
    switch (frequency) {
      case RecurringFrequency.daily:
        return current.add(const Duration(days: 1));
      case RecurringFrequency.weekly:
        return current.add(const Duration(days: 7));
      case RecurringFrequency.monthly:
        return DateTime(current.year, current.month + 1, current.day);
      case RecurringFrequency.yearly:
        return DateTime(current.year + 1, current.month, current.day);
    }
  }
}
