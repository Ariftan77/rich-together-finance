import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/goals.dart';
import '../tables/goal_accounts.dart';
import '../tables/goal_investments.dart';

part 'goal_dao.g.dart';

/// Data Access Object for Goal operations
@DriftAccessor(tables: [Goals, GoalAccounts, GoalInvestments])
class GoalDao extends DatabaseAccessor<AppDatabase> with _$GoalDaoMixin {
  GoalDao(super.db);

  /// Get all goals for a profile
  Future<List<Goal>> getAllGoals(int profileId) =>
      (select(goals)
            ..where((g) => g.profileId.equals(profileId))
            ..orderBy([(g) => OrderingTerm.asc(g.deadline)]))
          .get();

  /// Get active (not achieved) goals for a profile
  Future<List<Goal>> getActiveGoals(int profileId) =>
      (select(goals)
            ..where((g) => g.profileId.equals(profileId) & g.isAchieved.equals(false))
            ..orderBy([(g) => OrderingTerm.asc(g.deadline)]))
          .get();

  /// Get goal by ID
  Future<Goal?> getGoalById(int id) =>
      (select(goals)..where((g) => g.id.equals(id))).getSingleOrNull();

  /// Watch all goals for a profile (reactive stream)
  Stream<List<Goal>> watchAllGoals(int profileId) =>
      (select(goals)
            ..where((g) => g.profileId.equals(profileId))
            ..orderBy([(g) => OrderingTerm.asc(g.deadline)]))
          .watch();

  /// Watch active goals for a profile
  Stream<List<Goal>> watchActiveGoals(int profileId) {
    final query = select(goals)
          ..where((g) => g.profileId.equals(profileId) & g.isAchieved.equals(false))
          ..orderBy([(g) => OrderingTerm.asc(g.deadline)]);

    // Join with the link tables to trigger updates when accounts or
    // investments are linked/unlinked
    return query.join([
      leftOuterJoin(goalAccounts, goalAccounts.goalId.equalsExp(goals.id)),
      leftOuterJoin(goalInvestments, goalInvestments.goalId.equalsExp(goals.id)),
    ]).watch().map((rows) {
      return rows.map((row) => row.readTable(goals)).toSet().toList();
    });
  }

  /// Watch active goals together with their account and investment links.
  /// The watched join re-emits on changes to any of the three tables.
  Stream<List<GoalLinks>> watchActiveGoalsWithLinks(int profileId) {
    return watchActiveGoals(profileId).asyncMap((goalList) async {
      final ids = goalList.map((g) => g.id).toList();
      final accountRows = ids.isEmpty
          ? <GoalAccount>[]
          : await (select(goalAccounts)..where((ga) => ga.goalId.isIn(ids))).get();
      final investmentRows = ids.isEmpty
          ? <GoalInvestment>[]
          : await (select(goalInvestments)..where((gi) => gi.goalId.isIn(ids)))
              .get();
      return [
        for (final g in goalList)
          GoalLinks(
            goal: g,
            accounts: accountRows.where((ga) => ga.goalId == g.id).toList(),
            investments:
                investmentRows.where((gi) => gi.goalId == g.id).toList(),
          ),
      ];
    });
  }

  /// Create a new goal
  Future<int> createGoal(GoalsCompanion goal) =>
      into(goals).insert(goal);

  /// Update a goal
  Future<bool> updateGoal(Goal goal) =>
      update(goals).replace(goal);

  /// Mark goal as achieved
  Future<int> markGoalAchieved(int id) =>
      (update(goals)..where((g) => g.id.equals(id))).write(
        GoalsCompanion(
          isAchieved: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Delete a goal and its investment links
  Future<int> deleteGoal(int id) async {
    await (delete(goalInvestments)..where((gi) => gi.goalId.equals(id))).go();
    return (delete(goals)..where((g) => g.id.equals(id))).go();
  }

  // Goal-Account relationship methods

  /// Get accounts linked to a goal
  Future<List<GoalAccount>> getGoalAccounts(int goalId) =>
      (select(goalAccounts)..where((ga) => ga.goalId.equals(goalId))).get();

  /// Link account to goal
  Future<int> linkAccountToGoal(GoalAccountsCompanion link) =>
      into(goalAccounts).insert(link);

  /// Unlink account from goal
  Future<int> unlinkAccountFromGoal(int goalId, int accountId) =>
      (delete(goalAccounts)
            ..where((ga) => ga.goalId.equals(goalId) & ga.accountId.equals(accountId)))
          .go();

  /// Update contribution amount
  Future<int> updateContribution(int goalId, int accountId, double? amount) =>
      (update(goalAccounts)
            ..where((ga) => ga.goalId.equals(goalId) & ga.accountId.equals(accountId)))
          .write(GoalAccountsCompanion(contributionAmount: Value(amount)));

  // Goal-Investment relationship methods

  /// Get investment assets linked to a goal
  Future<List<GoalInvestment>> getGoalInvestments(int goalId) =>
      (select(goalInvestments)..where((gi) => gi.goalId.equals(goalId))).get();

  /// Replace the investment assets linked to a goal
  Future<void> setGoalInvestments(int goalId, Iterable<int> assetIds) =>
      transaction(() async {
        await (delete(goalInvestments)..where((gi) => gi.goalId.equals(goalId)))
            .go();
        for (final assetId in assetIds) {
          await into(goalInvestments).insert(GoalInvestmentsCompanion(
            goalId: Value(goalId),
            assetId: Value(assetId),
          ));
        }
      });
}

/// A goal plus the accounts and investment assets linked to it.
class GoalLinks {
  final Goal goal;
  final List<GoalAccount> accounts;
  final List<GoalInvestment> investments;

  const GoalLinks({
    required this.goal,
    required this.accounts,
    required this.investments,
  });
}
