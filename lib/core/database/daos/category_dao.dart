import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/categories.dart';
import '../../models/enums.dart';

part 'category_dao.g.dart';

/// Data Access Object for Category operations
@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase> with _$CategoryDaoMixin {
  CategoryDao(super.db);

  /// Get all categories
  Future<List<Category>> getAllCategories() =>
      (select(categories)..orderBy([(c) => OrderingTerm.asc(c.sortOrder)])).get();

  /// Get categories by type (income/expense)
  Future<List<Category>> getCategoriesByType(CategoryType type) =>
      (select(categories)
            ..where((c) => c.type.equals(type.index))
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
          .get();

  /// Get category by ID
  Future<Category?> getCategoryById(int id) =>
      (select(categories)..where((c) => c.id.equals(id))).getSingleOrNull();

  /// Watch all categories (reactive stream)
  Stream<List<Category>> watchAllCategories() =>
      (select(categories)..orderBy([(c) => OrderingTerm.asc(c.sortOrder)])).watch();

  /// Watch categories by type
  Stream<List<Category>> watchCategoriesByType(CategoryType type) =>
      (select(categories)
            ..where((c) => c.type.equals(type.index))
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
          .watch();

  /// Create a new category
  Future<int> createCategory(CategoriesCompanion category) =>
      into(categories).insert(category);

  /// Update a category
  Future<bool> updateCategory(Category category) =>
      update(categories).replace(category);

  /// Delete a category (only if not system)
  Future<int> deleteCategory(int id) =>
      (delete(categories)..where((c) => c.id.equals(id))).go();
}
