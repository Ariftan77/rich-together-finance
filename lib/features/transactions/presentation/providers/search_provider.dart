import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/currency_exchange_providers.dart';
import '../../../../core/services/currency_exchange_service.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';

final transactionSearchQueryProvider = StateProvider<String>((ref) => '');
final transactionTypeFilterProvider = StateProvider<List<TransactionType>?>((ref) => null);
final dateFromFilterProvider = StateProvider<DateTime?>((ref) => null);
final dateToFilterProvider = StateProvider<DateTime?>((ref) => null);
final transactionAccountFilterProvider = StateProvider<int?>((ref) => null);

final transactionLimitProvider = StateProvider<int>((ref) => 20);

final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// Watches the latest transaction date across all transactions for the active profile.
/// Used to allow month navigation into future months that have advance-recorded transactions.
final latestTransactionDateProvider = StreamProvider<DateTime?>((ref) {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return Stream.value(null);
  final dao = ref.watch(transactionDaoProvider);
  return dao.watchLatestTransactionDate(profileId);
});

/// Filtered transactions with amounts converted to the user's base currency.
/// Mirrors the dashboard pattern: pre-load accounts + rates once, then stream.
final convertedFilteredTransactionsProvider =
    StreamProvider.autoDispose<List<ConvertedTransaction>>((ref) async* {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) {
    yield [];
    return;
  }

  final query = ref.watch(transactionSearchQueryProvider);
  final types = ref.watch(transactionTypeFilterProvider);
  final customDateFrom = ref.watch(dateFromFilterProvider);
  final customDateTo = ref.watch(dateToFilterProvider);
  final accountId = ref.watch(transactionAccountFilterProvider);
  final limit = ref.watch(transactionLimitProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);
  final dao = ref.watch(transactionDaoProvider);
  final accountDao = ref.watch(accountDaoProvider);
  final baseCurrency = ref.watch(defaultCurrencyProvider);
  final rates = ref.watch(todayRatesProvider);

  // Use custom range if set, otherwise default to selected month
  final effectiveDateFrom = customDateFrom ?? DateTime(selectedMonth.year, selectedMonth.month, 1);
  final effectiveDateTo = customDateTo ?? DateTime(selectedMonth.year, selectedMonth.month + 1, 0, 23, 59, 59);

  // Pre-load accounts (including inactive, for old transactions) once
  final accounts = await accountDao.getAllAccountsIncludingInactive(profileId);
  final accountMap = {for (final a in accounts) a.id: a};

  await for (final transactions in dao.watchFilteredTransactions(
    profileId: profileId,
    limit: limit,
    searchQuery: query,
    accountId: accountId,
    types: types,
    dateFrom: effectiveDateFrom,
    dateTo: effectiveDateTo,
  )) {
    final converted = transactions.map((tx) {
      final account = accountMap[tx.accountId];
      final currency = account?.currency ?? baseCurrency;
      final convertedAmount = currency == baseCurrency
          ? tx.amount
          : CurrencyExchangeService.convertCurrency(
              tx.amount, currency.code, baseCurrency.code, rates);
      return ConvertedTransaction(
        transaction: tx,
        convertedAmount: convertedAmount,
        originalCurrency: currency,
      );
    }).toList();
    yield converted;
  }
});

final filteredTransactionsProvider = StreamProvider.autoDispose<List<Transaction>>((ref) {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) {
    return Stream.value([]);
  }
  
  final query = ref.watch(transactionSearchQueryProvider);
  final types = ref.watch(transactionTypeFilterProvider);
  final dateFrom = ref.watch(dateFromFilterProvider);
  final dateTo = ref.watch(dateToFilterProvider);
  final accountId = ref.watch(transactionAccountFilterProvider);
  final limit = ref.watch(transactionLimitProvider);
  final dao = ref.watch(transactionDaoProvider);

  return dao.watchFilteredTransactions(
    profileId: profileId,
    limit: limit,
    searchQuery: query,
    accountId: accountId,
    types: types,
    dateFrom: dateFrom,
    dateTo: dateTo,
  );
}, dependencies: [
  activeProfileIdProvider,
  transactionSearchQueryProvider,
  transactionTypeFilterProvider,
  dateFromFilterProvider,
  dateToFilterProvider,
  transactionAccountFilterProvider,
  transactionLimitProvider,
  transactionDaoProvider,
]);
