import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/recurring_service.dart';
import '../services/remote_config_service.dart';
import '../services/notification_service.dart';
import '../services/iap_service.dart';
import '../services/premium_auth_service.dart';
import 'currency_exchange_providers.dart';

/// Provider to handle app initialization tasks
final appInitProvider = FutureProvider<void>((ref) async {
  final totalSw = Stopwatch()..start();
  debugPrint('⏱️ [appInit] started');

  // ── Phase 1: deferred startup services ──────────────────────────────────
  // Supabase is initialized in main() before runApp() — see main.dart.
  // Run the remaining deferred services in parallel; none depend on each other.
  try {
    int rcMs = 0, notifMs = 0, iapMs = 0, premMs = 0;
    final parallelSw = Stopwatch()..start();
    await Future.wait([
      () async { final s = Stopwatch()..start(); await RemoteConfigService().init(); rcMs = s.elapsedMilliseconds; }(),
      () async { final s = Stopwatch()..start(); await NotificationService().init(); notifMs = s.elapsedMilliseconds; }(),
      () async { final s = Stopwatch()..start(); await IapService().init(); iapMs = s.elapsedMilliseconds; }(),
      () async { final s = Stopwatch()..start(); await PremiumAuthService().init(); premMs = s.elapsedMilliseconds; }(),
    ]);
    debugPrint('⏱️ [appInit] parallel group done: ${parallelSw.elapsedMilliseconds}ms');
    debugPrint('⏱️   ├─ RemoteConfig: ${rcMs}ms');
    debugPrint('⏱️   ├─ Notifications: ${notifMs}ms');
    debugPrint('⏱️   ├─ IAP: ${iapMs}ms');
    debugPrint('⏱️   └─ PremiumAuth: ${premMs}ms');
  } catch (e) {
    // A network failure in Phase 1 must not crash the provider — the app
    // can operate offline without RemoteConfig / Notifications / IAP.
    debugPrint('⚠️ [appInit] Phase 1 error (non-fatal): $e');
  }

  // ── Phase 2: data layer (original logic, unchanged) ──────────────────────
  // Fetch real exchange rates (seeds local DB on first launch)
  final currencyExchangeService = ref.read(currencyExchangeServiceProvider);
  final ratesSw = Stopwatch()..start();
  await currencyExchangeService.getRates();
  debugPrint('⏱️ [appInit] getRates(): ${ratesSw.elapsedMilliseconds}ms');

  // Check for recurring transactions
  final recurringService = ref.read(recurringServiceProvider);
  final recurringSw = Stopwatch()..start();
  await recurringService.checkAndGenerateRecurringTransactions();
  debugPrint('⏱️ [appInit] checkAndGenerateRecurringTransactions(): ${recurringSw.elapsedMilliseconds}ms');

  debugPrint('⏱️ [appInit] total: ${totalSw.elapsedMilliseconds}ms');
});
