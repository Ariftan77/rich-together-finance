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
