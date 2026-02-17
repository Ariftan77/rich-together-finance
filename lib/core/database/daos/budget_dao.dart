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

  /// Get all active budgets
  Future<List<Budget>> getAllBudgets() =>
      (select(budgets)..where((b) => b.isActive)).get();

  /// Get budget by category
  Future<Budget?> getBudgetByCategory(int categoryId) =>
      (select(budgets)
            ..where((b) => b.categoryId.equals(categoryId) & b.isActive))
          .getSingleOrNull();

  /// Get budgets by period
  Future<List<Budget>> getBudgetsByPeriod(BudgetPeriod period) =>
      (select(budgets)..where((b) => b.period.equals(period.index) & b.isActive)).get();

  /// Watch all budgets (reactive stream)
  Stream<List<Budget>> watchAllBudgets() {
    final query = select(budgets)..where((b) => b.isActive);
    
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
