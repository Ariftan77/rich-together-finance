import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/debts.dart';
import '../../models/enums.dart';

part 'debt_dao.g.dart';

/// Data Access Object for Debt operations
@DriftAccessor(tables: [Debts])
class DebtDao extends DatabaseAccessor<AppDatabase> with _$DebtDaoMixin {
  DebtDao(super.db);

  /// Get all debts
  Future<List<Debt>> getAllDebts() =>
      (select(debts)..orderBy([(d) => OrderingTerm.asc(d.dueDate)])).get();

  /// Get unsettled debts
  Future<List<Debt>> getUnsettledDebts() =>
      (select(debts)
            ..where((d) => d.isSettled.equals(false))
            ..orderBy([(d) => OrderingTerm.asc(d.dueDate)]))
          .get();

  /// Get debts by type
  Future<List<Debt>> getDebtsByType(DebtType type) =>
      (select(debts)
            ..where((d) => d.type.equals(type.index) & d.isSettled.equals(false))
            ..orderBy([(d) => OrderingTerm.asc(d.dueDate)]))
          .get();

  /// Get debt by ID
  Future<Debt?> getDebtById(int id) =>
      (select(debts)..where((d) => d.id.equals(id))).getSingleOrNull();

  /// Watch unsettled debts (reactive stream)
  Stream<List<Debt>> watchUnsettledDebts() =>
      (select(debts)
            ..where((d) => d.isSettled.equals(false))
            ..orderBy([(d) => OrderingTerm.asc(d.dueDate)]))
          .watch();

  /// Watch debts by type
  Stream<List<Debt>> watchDebtsByType(DebtType type) =>
      (select(debts)
            ..where((d) => d.type.equals(type.index) & d.isSettled.equals(false))
            ..orderBy([(d) => OrderingTerm.asc(d.dueDate)]))
          .watch();

  /// Create a new debt
  Future<int> createDebt(DebtsCompanion debt) =>
      into(debts).insert(debt);

  /// Update a debt
  Future<bool> updateDebt(Debt debt) =>
      update(debts).replace(debt);

  /// Settle a debt
  Future<int> settleDebt(int id, int settledAccountId) =>
      (update(debts)..where((d) => d.id.equals(id))).write(
        DebtsCompanion(
          isSettled: const Value(true),
          settledDate: Value(DateTime.now()),
          settledAccountId: Value(settledAccountId),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Delete a debt
  Future<int> deleteDebt(int id) =>
      (delete(debts)..where((d) => d.id.equals(id))).go();

  /// Calculate total payable (I owe)
  Future<double> getTotalPayable() async {
    final payables = await getDebtsByType(DebtType.payable);
    return payables.fold<double>(0.0, (sum, debt) => sum + debt.amount);
  }

  /// Calculate total receivable (Owed to me)
  Future<double> getTotalReceivable() async {
    final receivables = await getDebtsByType(DebtType.receivable);
    return receivables.fold<double>(0.0, (sum, debt) => sum + debt.amount);
  }
}
