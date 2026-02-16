import 'package:drift/drift.dart';
import 'goals.dart';
import 'accounts.dart';

/// Junction table for many-to-many relationship between Goals and Accounts
class GoalAccounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get goalId => integer().references(Goals, #id)();
  IntColumn get accountId => integer().references(Accounts, #id)();
  RealColumn get contributionAmount => real().nullable()();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {goalId, accountId},
      ];
}
