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

  /// Record a group payment (settle oldest debts first)
  Future<void> recordGroupPayment(
    int profileId,
    String personName,
    DebtType type,
    double paymentAmount,
  ) async {
    return transaction(() async {
      double remainingPayment = paymentAmount;
      final unsettledDebts = await (select(debts)
            ..where((d) =>
                d.profileId.equals(profileId) &
                d.personName.equals(personName) &
                d.type.equals(type.index) &
                d.isSettled.equals(false))
            ..orderBy([(d) => OrderingTerm.asc(d.createdAt)])) // oldest first
          .get();

      for (final debt in unsettledDebts) {
        if (remainingPayment <= 0) break;

        final debtRemaining = debt.amount - debt.paidAmount;
        final amountToApply = remainingPayment >= debtRemaining ? debtRemaining : remainingPayment;

        final newPaidAmount = debt.paidAmount + amountToApply;
        final isFullyPaid = newPaidAmount >= debt.amount;

        await (update(debts)..where((d) => d.id.equals(debt.id))).write(
          DebtsCompanion(
            paidAmount: Value(newPaidAmount),
            isSettled: Value(isFullyPaid),
            settledDate: isFullyPaid ? Value(DateTime.now()) : const Value.absent(),
            updatedAt: Value(DateTime.now()),
          ),
        );

        remainingPayment -= amountToApply;
      }
    });
  }

  /// Find the debt that corresponds to a creation transaction.
  /// Matches profile + name + type, then narrows by creationAccountId and
  /// creation date (within 2 minutes) for precision when multiple debts share
  /// the same person name.
  Future<Debt?> findDebtByNameAndType(
    int profileId,
    String personName,
    DebtType type, {
    int? accountId,
    DateTime? date,
  }) async {
    final results = await (select(debts)
          ..where((d) =>
              d.profileId.equals(profileId) &
              d.personName.equals(personName) &
              d.type.equals(type.index))
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
        .get();

    if (results.isEmpty) return null;

    // Most precise: match both account and creation time window
    if (accountId != null && date != null) {
      const window = Duration(minutes: 2);
      final precise = results.where((d) =>
          d.creationAccountId == accountId &&
          d.createdAt.difference(date).abs() <= window);
      if (precise.isNotEmpty) return precise.first;
    }

    // Fallback: account match only
    if (accountId != null) {
      final byAccount = results.where((d) => d.creationAccountId == accountId);
      if (byAccount.isNotEmpty) return byAccount.first;
    }

    // Last resort: most recently created with matching name + type
    return results.first;
  }

  /// Reverse a debt payment (e.g. when a settlement transaction is deleted).
  /// Finds the most-recently-updated debt matching [profileId] + [personName]
  /// and subtracts [amount] from its paidAmount.
  Future<void> reverseDebtPayment(int profileId, String personName, double amount) async {
    final matches = await (select(debts)
          ..where((d) => d.profileId.equals(profileId) & d.personName.equals(personName))
          ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)]))
        .get();
    if (matches.isEmpty) return;

    final debt = matches.first;
    final newPaidAmount = (debt.paidAmount - amount).clamp(0.0, debt.amount);
    final isNowFullyPaid = newPaidAmount >= debt.amount;

    await (update(debts)..where((d) => d.id.equals(debt.id))).write(
      DebtsCompanion(
        paidAmount: Value(newPaidAmount),
        isSettled: Value(isNowFullyPaid),
        settledDate: isNowFullyPaid ? Value(debt.settledDate) : const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Get distinct person names ordered by frequency (most used first)
  Future<List<String>> getFrequentPersonNames(int profileId, {int limit = 30}) async {
    final all = await (select(debts)
          ..where((d) => d.profileId.equals(profileId)))
        .get();
    final freq = <String, int>{};
    for (final d in all) {
      final name = d.personName.trim();
      if (name.isNotEmpty) freq[name] = (freq[name] ?? 0) + 1;
    }
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).toList();
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
