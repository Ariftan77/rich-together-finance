import 'package:drift/drift.dart';
import '../../../core/models/enums.dart';
import 'profiles.dart';

/// Budgets table definition
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id)();
  TextColumn get name => text().nullable()();
  RealColumn get amount => real()();
  IntColumn get currency => intEnum<Currency>().withDefault(const Constant(0))();
  IntColumn get period => intEnum<BudgetPeriod>()();
  DateTimeColumn get startDate => dateTime()();
  TextColumn get icon => text().nullable()();
  TextColumn get iconColor => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}
