import 'package:drift/drift.dart';
import '../../../core/models/enums.dart';
import 'accounts.dart';
import 'categories.dart';
import 'profiles.dart';

/// Recurring transactions table definition
class Recurring extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get type => intEnum<TransactionType>()();
  RealColumn get amount => real()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  IntColumn get toAccountId => integer().nullable().references(Accounts, #id)();
  IntColumn get frequency => intEnum<RecurringFrequency>()();
  DateTimeColumn get nextDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}

