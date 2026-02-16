import 'package:drift/drift.dart';
import '../../../core/models/enums.dart';
import 'categories.dart';
import 'profiles.dart';

/// Budgets table definition
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id)();
  IntColumn get categoryId => integer().references(Categories, #id)();
  RealColumn get amount => real()();
  IntColumn get period => intEnum<BudgetPeriod>()();
  DateTimeColumn get startDate => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {profileId, categoryId, period},
      ];
}

