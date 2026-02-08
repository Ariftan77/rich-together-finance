import 'package:drift/drift.dart';
import 'goals.dart';
import 'accounts.dart';

/// Junction table for many-to-many relationship between Goals and Accounts
class GoalAccounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get goalId => integer().references(Goals, #id)();
  IntColumn get accountId => integer().references(Accounts, #id)();
  RealColumn get contributionAmount => real().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {goalId, accountId},
      ];
}
