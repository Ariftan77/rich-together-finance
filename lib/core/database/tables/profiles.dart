import 'package:drift/drift.dart';

/// Profiles table - stores multiple user profiles per device
/// Each profile has isolated financial data
class Profiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get avatar => text().withDefault(const Constant('👤'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}
