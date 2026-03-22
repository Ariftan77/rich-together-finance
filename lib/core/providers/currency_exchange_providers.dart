import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/stores/drift_rate_store.dart';
import '../services/currency_exchange_service.dart';
import '../services/local_rate_store.dart';
import 'database_providers.dart';
import 'service_providers.dart';

/// Local rate store backed by Drift / SQLite.
final localRateStoreProvider = Provider<LocalRateStore>((ref) {
  final db = ref.watch(databaseProvider);
  return DriftRateStore(db);
});

/// Offline-first currency exchange service.
///
/// Uses: Local DB → Supabase → Frankfurter API fallback chain.
final currencyExchangeServiceProvider = Provider<CurrencyExchangeService>((ref) {
  final localStore = ref.watch(localRateStoreProvider);
  final dio = ref.watch(dioProvider);
  final supabase = Supabase.instance.client;

  return CurrencyExchangeService(
    localStore: localStore,
    dio: dio,
    supabase: supabase,
  );
});

/// Today's exchange rates — returns hardcoded rates instantly (sync, no I/O),
/// then updates state with real rates once the background fetch completes.
///
/// All providers that need today's rates should watch this instead of
/// awaiting [CurrencyExchangeService.getRates()] directly.
class TodayRatesNotifier extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() {
    final now = DateTime.now().toUtc();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    // Fire-and-forget — fetch real rates in background and update state
    Future.microtask(_fetchReal);
    return CurrencyExchangeService.getHardcodedRates(today).rates;
  }

  Future<void> _fetchReal() async {
    try {
      final service = ref.read(currencyExchangeServiceProvider);
      final real = await service.getRates();
      if (real.source != 'hardcoded') {
        state = real.rates;
      }
    } catch (_) {
      // keep hardcoded rates on failure
    }
  }
}

final todayRatesProvider =
    NotifierProvider<TodayRatesNotifier, Map<String, double>>(
  TodayRatesNotifier.new,
);
