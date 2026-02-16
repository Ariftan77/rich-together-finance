import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../accounts/presentation/providers/balance_provider.dart';

class GoalWithProgress {
  final Goal goal;
  final double currentAmount;
  final double progress;
  final double? monthlyNeeded;
  final List<GoalAccount> linkedAccounts;

  GoalWithProgress({
    required this.goal,
    required this.currentAmount,
    required this.progress,
    this.monthlyNeeded,
    required this.linkedAccounts,
  });
}

final goalsWithProgressProvider =
    StreamProvider.autoDispose<List<GoalWithProgress>>((ref) async* {
  final goalDao = ref.watch(goalDaoProvider);
  final exchangeService = ref.watch(exchangeRateServiceProvider);
  final goalsStream = goalDao.watchActiveGoals();

  // Watch transactions & accounts so balances recalculate reactively
  ref.watch(transactionsStreamProvider);
  ref.watch(accountsStreamProvider);

  await for (final goals in goalsStream) {
    if (goals.isEmpty) {
      yield [];
      continue;
    }

    final balances = ref.read(accountBalanceProvider);
    final accounts = ref.read(accountsStreamProvider).valueOrNull ?? [];
    final accountsMap = {for (var a in accounts) a.id: a};
    final result = <GoalWithProgress>[];

    for (final goal in goals) {
      final goalAccounts = await goalDao.getGoalAccounts(goal.id);
      double currentAmount = 0;

      for (final ga in goalAccounts) {
        final account = accountsMap[ga.accountId];
        if (account == null) continue;

        double balance;
        if (ga.contributionAmount != null) {
          balance = ga.contributionAmount!;
        } else {
          balance = balances[ga.accountId] ?? 0;
        }

        // Convert to goal's target currency if different
        if (account.currency != goal.targetCurrency) {
          final converted = await exchangeService.convert(
            balance,
            account.currency,
            goal.targetCurrency,
          );
          currentAmount += converted ?? balance;
        } else {
          currentAmount += balance;
        }
      }

      double? monthlyNeeded;
      if (goal.deadline != null) {
        final remaining = goal.targetAmount - currentAmount;
        if (remaining > 0) {
          final monthsLeft =
              goal.deadline!.difference(DateTime.now()).inDays / 30.0;
          if (monthsLeft > 0) {
            monthlyNeeded = remaining / monthsLeft;
          }
        }
      }

      result.add(GoalWithProgress(
        goal: goal,
        currentAmount: currentAmount,
        progress:
            goal.targetAmount > 0 ? currentAmount / goal.targetAmount : 0,
        monthlyNeeded: monthlyNeeded,
        linkedAccounts: goalAccounts,
      ));
    }

    yield result;
  }
});
