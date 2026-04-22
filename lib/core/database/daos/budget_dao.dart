import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/budgets.dart';
import '../tables/budget_categories.dart';
import '../tables/categories.dart';
import '../../models/enums.dart';

part 'budget_dao.g.dart';

/// A budget combined with its linked categories, and a derived display name.
class BudgetWithCategories {
  final Budget budget;
  final List<Category> categories;

  const BudgetWithCategories({
    required this.budget,
    required this.categories,
  });

  /// Derives a human-readable name for this budget.
  ///
  /// Priority:
  /// 1. The budget's own [budget.name] if set.
  /// 2. Single category → that category's name.
  /// 3. Two categories → "Cat A & Cat B".
  /// 4. Three or more → "Cat A + N more".
  /// 5. No categories → "Unnamed Budget".
  String get displayName {
    if (budget.name != null && budget.name!.trim().isNotEmpty) {
      return budget.name!.trim();
    }
    if (categories.isEmpty) return 'Unnamed Budget';
    if (categories.length == 1) return categories.first.name;
    if (categories.length == 2) {
      return '${categories[0].name} & ${categories[1].name}';
    }
    return '${categories[0].name} + ${categories.length - 1} more';
  }
}

/// Data Access Object for Budget operations
@DriftAccessor(tables: [Budgets, BudgetCategories, Categories])
class BudgetDao extends DatabaseAccessor<AppDatabase> with _$BudgetDaoMixin {
  BudgetDao(super.db);

  // ---------------------------------------------------------------------------
  // Budget CRUD
  // ---------------------------------------------------------------------------

  /// Get all active budgets for a profile
  Future<List<Budget>> getAllBudgets(int profileId) =>
      (select(budgets)..where((b) => b.profileId.equals(profileId) & b.isActive)).get();

  /// Get budgets by period for a profile
  Future<List<Budget>> getBudgetsByPeriod(int profileId, BudgetPeriod period) =>
      (select(budgets)..where((b) => b.profileId.equals(profileId) & b.period.equals(period.index) & b.isActive)).get();

  /// Watch all budgets for a profile (reactive stream).
  ///
  /// Also left-joins [budgetCategories] so that the stream re-fires whenever
  /// category links change.
  Stream<List<Budget>> watchAllBudgets(int profileId) {
    final query = select(budgets)..where((b) => b.profileId.equals(profileId) & b.isActive);

    return query.join([
      leftOuterJoin(budgetCategories, budgetCategories.budgetId.equalsExp(budgets.id)),
    ]).watch().map((rows) {
      return rows.map((row) => row.readTable(budgets)).toSet().toList();
    });
  }

  /// Create a new budget and return the newly inserted row's id.
  Future<int> createBudget(BudgetsCompanion budget) =>
      into(budgets).insert(budget);

  /// Update a budget
  Future<bool> updateBudget(Budget budget) =>
      update(budgets).replace(budget);

  /// Deactivate a budget (soft-delete)
  Future<int> deactivateBudget(int id) =>
      (update(budgets)..where((b) => b.id.equals(id)))
          .write(const BudgetsCompanion(isActive: Value(false)));

  /// Hard-delete a budget (and its category links via cascade or manually)
  Future<int> deleteBudget(int id) async {
    await unlinkAllCategoriesFromBudget(id);
    return (delete(budgets)..where((b) => b.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------------
  // Budget ↔ Category junction
  // ---------------------------------------------------------------------------

  /// Link a single category to a budget.
  Future<void> linkCategoryToBudget(int budgetId, int categoryId) =>
      into(budgetCategories).insert(
        BudgetCategoriesCompanion(
          budgetId: Value(budgetId),
          categoryId: Value(categoryId),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  /// Remove all category links for a budget.
  Future<void> unlinkAllCategoriesFromBudget(int budgetId) =>
      (delete(budgetCategories)..where((bc) => bc.budgetId.equals(budgetId))).go();

  /// Get the linked category IDs for a specific budget.
  Future<List<int>> getLinkedCategoryIds(int budgetId) async {
    final rows = await (select(budgetCategories)
          ..where((bc) => bc.budgetId.equals(budgetId)))
        .get();
    return rows.map((r) => r.categoryId).toList();
  }

  // ---------------------------------------------------------------------------
  // Combined budget + categories
  // ---------------------------------------------------------------------------

  /// Watch all active budgets for a profile together with their linked categories.
  Stream<List<BudgetWithCategories>> watchAllBudgetsWithCategories(int profileId) {
    // Re-use the plain budget stream as a trigger and enrich asynchronously.
    return watchAllBudgets(profileId).asyncMap((budgetList) async {
      if (budgetList.isEmpty) return <BudgetWithCategories>[];

      // Fetch all categories once (small table, safe to load entirely).
      final allCategories = await (select(categories)).get();
      final categoryById = {for (final c in allCategories) c.id: c};

      // Fetch all budget_categories links for this profile's budgets at once.
      final budgetIds = budgetList.map((b) => b.id).toList();
      final links = await (select(budgetCategories)
            ..where((bc) => bc.budgetId.isIn(budgetIds)))
          .get();

      // Group links by budgetId.
      final Map<int, List<int>> catIdsByBudget = {};
      for (final link in links) {
        catIdsByBudget.putIfAbsent(link.budgetId, () => []).add(link.categoryId);
      }

      return budgetList.map((budget) {
        final catIds = catIdsByBudget[budget.id] ?? [];
        final cats = catIds
            .map((id) => categoryById[id])
            .whereType<Category>()
            .toList();
        return BudgetWithCategories(budget: budget, categories: cats);
      }).toList();
    });
  }
}
