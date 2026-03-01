import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/debts.dart';
import '../../models/enums.dart';

part 'debt_dao.g.dart';

/// Data Access Object for Debt operations
@DriftAccessor(tables: [Debts])
class DebtDao extends DatabaseAccessor<AppDatabase> with _$DebtDaoMixin {
  DebtDao(super.db);

  /// Get all debts for a profile
  Future<List<Debt>> getAllDebts(int profileId) =>
      (select(debts)
            ..where((d) => d.profileId.equals(profileId))
            ..orderBy([(d) => OrderingTerm.asc(d.dueDate)]))
          .get();

  /// Get unsettled debts for a profile
  Future<List<Debt>> getUnsettledDebts(int profileId) =>
      (select(debts)
            ..where((d) => d.profileId.equals(profileId) & d.isSettled.equals(false))
            ..orderBy([(d) => OrderingTerm.asc(d.dueDate)]))
          .get();

  /// Get debts by type for a profile
  Future<List<Debt>> getDebtsByType(int profileId, DebtType type) =>
      (select(debts)
            ..where((d) => d.profileId.equals(profileId) & d.type.equals(type.index) & d.isSettled.equals(false))
            ..orderBy([(d) => OrderingTerm.asc(d.dueDate)]))
          .get();

  /// Get debt by ID
  Future<Debt?> getDebtById(int id) =>
      (select(debts)..where((d) => d.id.equals(id))).getSingleOrNull();

  /// Watch unsettled debts for a profile (reactive stream)
  Stream<List<Debt>> watchUnsettledDebts(int profileId) =>
      (select(debts)
            ..where((d) => d.profileId.equals(profileId) & d.isSettled.equals(false))
            ..orderBy([(d) => OrderingTerm.asc(d.dueDate)]))
          .watch();

  /// Watch debts by type for a profile
  Stream<List<Debt>> watchDebtsByType(int profileId, DebtType type) =>
      (select(debts)
            ..where((d) => d.profileId.equals(profileId) & d.type.equals(type.index) & d.isSettled.equals(false))
            ..orderBy([(d) => OrderingTerm.asc(d.dueDate)]))
          .watch();

  /// Create a new debt
  Future<int> createDebt(DebtsCompanion debt) {
    return into(debts).insert(debt);
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
  Future<double> getTotalPayable(int profileId) async {
    final payables = await getDebtsByType(profileId, DebtType.payable);
    return payables.fold<double>(0.0, (sum, debt) => sum + (debt.amount - debt.paidAmount));
  }

  /// Calculate total receivable (Owed to me) - remaining amount
  Future<double> getTotalReceivable(int profileId) async {
    final receivables = await getDebtsByType(profileId, DebtType.receivable);
    return receivables.fold<double>(0.0, (sum, debt) => sum + (debt.amount - debt.paidAmount));
  }
}
