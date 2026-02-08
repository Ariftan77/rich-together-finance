import 'package:drift/drift.dart';
import '../../../core/models/enums.dart';

/// Categories table definition
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get type => intEnum<CategoryType>()();
  TextColumn get icon => text()();
  TextColumn get color => text().nullable()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  IntColumn get parentId => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
