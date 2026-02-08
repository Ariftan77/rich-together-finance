import 'package:drift/drift.dart';
import '../../../core/models/enums.dart';

/// Goals table definition
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  RealColumn get targetAmount => real()();
  IntColumn get targetCurrency => intEnum<Currency>()();
  DateTimeColumn get deadline => dateTime().nullable()();
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
  BoolColumn get isAchieved => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
