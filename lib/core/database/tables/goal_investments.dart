import 'package:drift/drift.dart';
import 'goals.dart';
import 'investment_assets.dart';

/// Junction table for many-to-many relationship between Goals and
/// snapshot-tracked investment assets. The asset's latest value counts toward
/// the goal, converted into the goal's currency at today's rate.
class GoalInvestments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get goalId => integer().references(Goals, #id)();
  IntColumn get assetId => integer().references(InvestmentAssets, #id)();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {goalId, assetId},
      ];
}
