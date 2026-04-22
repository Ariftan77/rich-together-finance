import 'package:drift/drift.dart';
import 'budgets.dart';
import 'categories.dart';

/// Junction table for many-to-many relationship between Budgets and Categories
class BudgetCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get budgetId => integer().references(Budgets, #id)();
  IntColumn get categoryId => integer().references(Categories, #id)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {budgetId, categoryId},
      ];
}
