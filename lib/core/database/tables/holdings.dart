import 'package:drift/drift.dart';
import '../../../core/models/enums.dart';
import 'accounts.dart';

/// Holdings table definition for investment assets
class Holdings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get assetType => intEnum<AssetType>()();
  TextColumn get ticker => text().withLength(min: 1, max: 20)();
  TextColumn get exchange => text().nullable()();
  RealColumn get quantity => real()();
  RealColumn get averageBuyPrice => real()();
  IntColumn get currency => intEnum<Currency>()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {accountId, assetType, ticker},
      ];
}
