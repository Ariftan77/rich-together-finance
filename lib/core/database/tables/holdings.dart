import 'package:drift/drift.dart';
import '../../../core/models/enums.dart';
import 'accounts.dart';
import 'profiles.dart';

/// Holdings table definition for investment assets
class Holdings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id)();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get assetType => intEnum<AssetType>()();
  TextColumn get ticker => text().withLength(min: 1, max: 20)();
  TextColumn get exchange => text().nullable()();
  RealColumn get quantity => real()();
  RealColumn get averageBuyPrice => real()();
  IntColumn get currency => intEnum<Currency>()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {profileId, accountId, assetType, ticker},
      ];
}

