import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/budgets.dart';
import '../tables/categories.dart';
import '../../models/enums.dart';

part 'budget_dao.g.dart';

/// Data Access Object for Budget operations
@DriftAccessor(tables: [Budgets, Categories])
class BudgetDao extends DatabaseAccessor<AppDatabase> with _$BudgetDaoMixin {
  BudgetDao(super.db);

  /// Get all active budgets for a profile
  Future<List<Budget>> getAllBudgets(int profileId) =>
      (select(budgets)..where((b) => b.profileId.equals(profileId) & b.isActive)).get();

  /// Get budget by category for a profile
  Future<Budget?> getBudgetByCategory(int profileId, int categoryId) =>
      (select(budgets)
            ..where((b) => b.profileId.equals(profileId) & b.categoryId.equals(categoryId) & b.isActive))
          .getSingleOrNull();

  /// Get budgets by period for a profile
  Future<List<Budget>> getBudgetsByPeriod(int profileId, BudgetPeriod period) =>
      (select(budgets)..where((b) => b.profileId.equals(profileId) & b.period.equals(period.index) & b.isActive)).get();

  /// Watch all budgets for a profile (reactive stream)
  Stream<List<Budget>> watchAllBudgets(int profileId) {
    final query = select(budgets)..where((b) => b.profileId.equals(profileId) & b.isActive);

    // Join with categories to trigger updates when category details change
    return query.join([
      innerJoin(categories, categories.id.equalsExp(budgets.categoryId))
    ]).watch().map((rows) {
      return rows.map((row) => row.readTable(budgets)).toList();
    });
  }

  /// Create a new budget
  Future<int> createBudget(BudgetsCompanion budget) =>
      into(budgets).insert(budget);

  /// Update a budget
  Future<bool> updateBudget(Budget budget) =>
      update(budgets).replace(budget);

  /// Deactivate a budget
  Future<int> deactivateBudget(int id) =>
      (update(budgets)..where((b) => b.id.equals(id)))
          .write(const BudgetsCompanion(isActive: Value(false)));

  /// Delete a budget
  Future<int> deleteBudget(int id) =>
      (delete(budgets)..where((b) => b.id.equals(id))).go();
}
