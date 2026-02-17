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
  Future<int> createDebt(DebtsCompanion debt, int creationAccountId) {
    return into(debts).insert(debt.copyWith(creationAccountId: Value(creationAccountId)));
  }

  /// Update a debt
  Future<bool> updateDebt(Debt debt) =>
      update(debts).replace(debt);

  /// Settle a debt (Full payment)
  Future<int> settleDebt(int id, int settledAccountId) async {
    final debt = await getDebtById(id);
    if (debt == null) return 0;
    
    return (update(debts)..where((d) => d.id.equals(id))).write(
      DebtsCompanion(
        isSettled: const Value(true),
        settledDate: Value(DateTime.now()),
        settledAccountId: Value(settledAccountId),
        updatedAt: Value(DateTime.now()),
        paidAmount: Value(debt.amount), // Set to full amount
      ),
    );
  }
      
  /// Record a partial payment
  Future<int> recordPayment(int id, double amount) async {
    final debt = await getDebtById(id);
    if (debt == null) return 0;
    
    final newPaidAmount = debt.paidAmount + amount;
    final isFullyPaid = newPaidAmount >= debt.amount;
    
    return (update(debts)..where((d) => d.id.equals(id))).write(
      DebtsCompanion(
        paidAmount: Value(newPaidAmount),
        isSettled: Value(isFullyPaid),
        settledDate: isFullyPaid ? Value(DateTime.now()) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Delete a debt
  Future<int> deleteDebt(int id) =>
      (delete(debts)..where((d) => d.id.equals(id))).go();

  /// Calculate total payable (I owe) - remaining amount
  Future<double> getTotalPayable() async {
    final payables = await getDebtsByType(DebtType.payable);
    return payables.fold<double>(0.0, (sum, debt) => sum + (debt.amount - debt.paidAmount));
  }

  /// Calculate total receivable (Owed to me) - remaining amount
  Future<double> getTotalReceivable() async {
    final receivables = await getDebtsByType(DebtType.receivable);
    return receivables.fold<double>(0.0, (sum, debt) => sum + (debt.amount - debt.paidAmount));
  }
}
