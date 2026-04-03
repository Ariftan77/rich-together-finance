import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/profile_provider.dart';

// ---------------------------------------------------------------------------
// Internal streaming provider
// ---------------------------------------------------------------------------

/// Internal stream that emits accountId → balance (initialBalance + net delta)
/// using a single SQL GROUP BY round-trip per emission.  Kept private so
/// callers always go through [accountBalanceProvider].
final _accountBalanceStreamProvider = StreamProvider.autoDispose<Map<int, double>>((ref) {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return Stream.value({});

  final accountDao = ref.watch(accountDaoProvider);
  final transactionDao = ref.watch(transactionDaoProvider);

  // Re-emit whenever accounts change (initialBalance, additions, removals).
  final accountsStream = accountDao.watchAllAccounts(profileId);
  // Per-account transaction delta: one SQL GROUP BY query, reactive.
  final deltasStream = transactionDao.watchAllAccountBalanceDeltas(profileId);

  return accountsStream.asyncExpand((accounts) {
    return deltasStream.map((deltas) {
      final balances = <int, double>{};
      for (final account in accounts) {
        final delta = deltas[account.id] ?? 0.0;
        balances[account.id] = account.initialBalance + delta;
      }
      return balances;
    });
  });
});

// ---------------------------------------------------------------------------
// Public provider — same type as before (Map<int, double>)
// ---------------------------------------------------------------------------

/// Provider to calculate current balance for each account.
/// Returns a Map<int, double> where key is Account ID and value is the
/// running balance (initialBalance + net transaction delta).
///
/// Return type is intentionally the same as the original Provider<Map<int, double>>
/// so all existing callers remain unaffected.  The computation now comes from a
/// SQL GROUP BY query ([TransactionDao.watchAllAccountBalanceDeltas]) rather than
/// iterating all transactions in Dart.
final accountBalanceProvider = Provider.autoDispose<Map<int, double>>((ref) {
  return ref.watch(_accountBalanceStreamProvider).valueOrNull ?? {};
});
