import 'package:drift/drift.dart';
import '../../../core/models/enums.dart';
import 'profiles.dart';

/// Accounts table definition
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get type => intEnum<AccountType>()();
  IntColumn get currency => intEnum<Currency>()();
  RealColumn get initialBalance => real().withDefault(const Constant(0))();
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}

