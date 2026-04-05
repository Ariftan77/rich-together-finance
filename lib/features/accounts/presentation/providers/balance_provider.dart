import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/profile_provider.dart';

// ---------------------------------------------------------------------------
// Internal streaming provider
// ---------------------------------------------------------------------------

/// Internal stream that emits accountId → balance (initialBalance + net delta)
/// using a single SQL GROUP BY round-trip per emission.  Kept private so
/// callers always go through [accountBalanceProvider].
///
/// Uses a [StreamController] to combine [accountsStream] and [deltasStream]
/// without [asyncExpand], which would cancel and re-subscribe the inner stream
/// (deltasStream) on every outer (accounts) emission — producing a transient
/// empty-map gap that caused the zero-balance flash.
final _accountBalanceStreamProvider = StreamProvider.autoDispose<Map<int, double>>((ref) {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return Stream.value({});

  final accountDao = ref.watch(accountDaoProvider);
  final transactionDao = ref.watch(transactionDaoProvider);

  // Re-emit whenever accounts change (initialBalance, additions, removals).
  final accountsStream = accountDao.watchAllAccounts(profileId);
  // Per-account transaction delta: one SQL GROUP BY query, reactive.
  final deltasStream = transactionDao.watchAllAccountBalanceDeltas(profileId);

  // We combine both streams with a StreamController so that:
  //  - neither subscription is torn down when the other emits, and
  //  - a new combined value is produced whenever either stream emits.
  final controller = StreamController<Map<int, double>>();

  List<dynamic>? latestAccounts;
  Map<int, double>? latestDeltas;

  void emit() {
    if (latestAccounts == null || latestDeltas == null) return;
    final balances = <int, double>{};
    for (final account in latestAccounts!) {
      final delta = latestDeltas![account.id] ?? 0.0;
      balances[account.id] = account.initialBalance + delta;
    }
    if (!controller.isClosed) controller.add(balances);
  }

  final accountsSub = accountsStream.listen(
    (accounts) {
      latestAccounts = accounts;
      emit();
    },
    onError: controller.addError,
  );

  final deltasSub = deltasStream.listen(
    (deltas) {
      latestDeltas = deltas;
      emit();
    },
    onError: controller.addError,
  );

  ref.onDispose(() {
    accountsSub.cancel();
    deltasSub.cancel();
    controller.close();
  });

  return controller.stream;
});

// ---------------------------------------------------------------------------
// Public stream alias — lets widgets watch loading state directly
// ---------------------------------------------------------------------------

/// Exposed stream variant for widgets that need reactive loading state.
/// Alias for the internal [_accountBalanceStreamProvider].
final accountBalanceStreamProvider = _accountBalanceStreamProvider;

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
