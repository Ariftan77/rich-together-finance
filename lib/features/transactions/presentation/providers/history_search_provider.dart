import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/profile_provider.dart';

/// Providers backing the full-history search screen.
///
/// Kept separate from `search_provider.dart` on purpose: the transactions tab
/// filters a single month, this one searches every transaction ever recorded.
/// Sharing state would make one screen silently reconfigure the other.
///
/// All of them are `autoDispose` so the screen always opens blank.

/// Page size — how many rows are added each time the user reaches the bottom.
const int historySearchPageSize = 50;

final historySearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');
final historySearchDateFromProvider = StateProvider.autoDispose<DateTime?>((ref) => null);
final historySearchDateToProvider = StateProvider.autoDispose<DateTime?>((ref) => null);
final historySearchLimitProvider =
    StateProvider.autoDispose<int>((ref) => historySearchPageSize);

/// True once the user has typed something or picked a date range — until then
/// the screen shows its hint instead of running a query.
final historySearchIsActiveProvider = Provider.autoDispose<bool>((ref) {
  final query = ref.watch(historySearchQueryProvider).trim();
  final from = ref.watch(historySearchDateFromProvider);
  final to = ref.watch(historySearchDateToProvider);
  return query.isNotEmpty || from != null || to != null;
});

/// Accounts of the active profile, including deactivated ones — old
/// transactions often point at a wallet the user has since archived.
final historySearchAccountMapProvider =
    FutureProvider.autoDispose<Map<int, Account>>((ref) async {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return const {};
  final accounts =
      await ref.watch(accountDaoProvider).getAllAccountsIncludingInactive(profileId);
  return {for (final a in accounts) a.id: a};
});

/// Search results, newest first, capped at [historySearchLimitProvider].
///
/// Emits an empty list while the search is inactive so the screen never runs
/// an unbounded query on first open.
final historySearchResultsProvider =
    StreamProvider.autoDispose<List<Transaction>>((ref) {
  if (!ref.watch(historySearchIsActiveProvider)) return Stream.value(const []);

  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return Stream.value(const []);

  final query = ref.watch(historySearchQueryProvider).trim();
  final dateFrom = ref.watch(historySearchDateFromProvider);
  final dateTo = ref.watch(historySearchDateToProvider);
  final limit = ref.watch(historySearchLimitProvider);

  return ref.watch(transactionDaoProvider).watchFilteredTransactions(
        profileId: profileId,
        limit: limit,
        searchQuery: query.isEmpty ? null : query,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
});

/// Whether another page might exist — the query returned a full page.
final historySearchHasMoreProvider = Provider.autoDispose<bool>((ref) {
  final results = ref.watch(historySearchResultsProvider).valueOrNull;
  if (results == null) return false;
  return results.length >= ref.watch(historySearchLimitProvider);
});
