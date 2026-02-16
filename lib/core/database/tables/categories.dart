import 'package:drift/drift.dart';
import '../../../core/models/enums.dart';
import 'profiles.dart';

/// Categories table definition
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().nullable().references(Profiles, #id)();  // null for system categories
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get type => intEnum<CategoryType>()();
  TextColumn get icon => text()();
  TextColumn get color => text().nullable()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  IntColumn get parentId => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}

