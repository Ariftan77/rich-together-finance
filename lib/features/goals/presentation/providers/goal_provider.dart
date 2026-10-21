import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database.dart';
import '../../../../core/database/daos/goal_dao.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/currency_exchange_providers.dart';
import '../../../../core/services/currency_exchange_service.dart';
import '../../../accounts/presentation/providers/balance_provider.dart';
import '../../../investments/presentation/providers/investment_providers.dart';

class GoalAccountBalance {
  final GoalAccount goalAccount;
  final Account account;
  final double originalAmount;
  final double convertedAmount;
  final double exchangeRate;

  GoalAccountBalance({
    required this.goalAccount,
    required this.account,
    required this.originalAmount,
    required this.convertedAmount,
    required this.exchangeRate,
  });
}

class GoalInvestmentBalance {
  final GoalInvestment goalInvestment;
  final InvestmentAsset asset;
  final double originalAmount;
  final double convertedAmount;
  final double exchangeRate;

  GoalInvestmentBalance({
    required this.goalInvestment,
    required this.asset,
    required this.originalAmount,
    required this.convertedAmount,
    required this.exchangeRate,
  });
}

class GoalWithProgress {
  final Goal goal;
  final double currentAmount;
  final double progress;
  final double? monthlyNeeded;
  final List<GoalAccountBalance> accountBalances;
  final List<GoalInvestmentBalance> investmentBalances;

  GoalWithProgress({
    required this.goal,
    required this.currentAmount,
    required this.progress,
    this.monthlyNeeded,
    required this.accountBalances,
    this.investmentBalances = const [],
  });
}

/// Active goals with their account and investment link rows. Re-emits when a
/// goal or any of its links changes. Kept separate from the balance math so
/// that balance updates never restart these database reads.
final _goalLinksProvider =
    StreamProvider.autoDispose<List<GoalLinks>>((ref) {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return Stream.value([]);
  return ref.watch(goalDaoProvider).watchActiveGoalsWithLinks(profileId);
});

/// Goals with progress, combining links with live balances, investment values
/// and today's rates. Synchronous: whenever any input changes, the totals are
/// recomputed from the latest values with no awaits in between.
final goalsWithProgressProvider =
    Provider.autoDispose<AsyncValue<List<GoalWithProgress>>>((ref) {
  final linksAsync = ref.watch(_goalLinksProvider);
  final balances = ref.watch(accountBalanceProvider);
  final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? [];
  final accountsMap = {for (var a in accounts) a.id: a};
  final rates = ref.watch(todayRatesProvider);
  // Latest value per investment asset, in the asset's own currency
  final investmentViews = {
    for (final v in ref.watch(investmentSummaryProvider).assets) v.asset.id: v,
  };

  return linksAsync.whenData((links) {
    final result = <GoalWithProgress>[];

    for (final link in links) {
      final goal = link.goal;
      final goalAccounts = link.accounts;
      double currentAmount = 0;
      final List<GoalAccountBalance> accountBalances = [];

      for (final ga in goalAccounts) {
        final account = accountsMap[ga.accountId];
        if (account == null) continue;

        double balance;
        if (ga.contributionAmount != null) {
          balance = ga.contributionAmount!;
        } else {
          balance = balances[ga.accountId] ?? 0;
        }

        double convertedAmount = balance;
        double rate = 1.0;

        // Convert to goal's target currency if different
        if (account.currency != goal.targetCurrency) {
          rate = CurrencyExchangeService.convertCurrency(
            1.0,
            account.currency.code,
            goal.targetCurrency.code,
            rates,
          );
          convertedAmount = balance * rate;
        }

        currentAmount += convertedAmount;

        accountBalances.add(GoalAccountBalance(
          goalAccount: ga,
          account: account,
          originalAmount: balance,
          convertedAmount: convertedAmount,
          exchangeRate: rate,
        ));
      }

      final goalInvestments = link.investments;
      final List<GoalInvestmentBalance> investmentBalances = [];

      for (final gi in goalInvestments) {
        final view = investmentViews[gi.assetId];
        if (view == null) continue; // archived or deleted asset

        final asset = view.asset;
        final value = view.latestValue;
        double convertedAmount = value;
        double rate = 1.0;

        // Convert to goal's target currency if different
        if (asset.currency != goal.targetCurrency) {
          rate = CurrencyExchangeService.convertCurrency(
            1.0,
            asset.currency.code,
            goal.targetCurrency.code,
            rates,
          );
          convertedAmount = value * rate;
        }

        currentAmount += convertedAmount;

        investmentBalances.add(GoalInvestmentBalance(
          goalInvestment: gi,
          asset: asset,
          originalAmount: value,
          convertedAmount: convertedAmount,
          exchangeRate: rate,
        ));
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
        accountBalances: accountBalances,
        investmentBalances: investmentBalances,
      ));
    }

    return result;
  });
});
