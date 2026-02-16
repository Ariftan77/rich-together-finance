import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../models/enums.dart';

/// Service for fetching and caching exchange rates
class ExchangeRateService {
  final Dio _dio;
  final AppDatabase _db;
  final String? _apiKey;

  ExchangeRateService(this._dio, this._db, {String? apiKey}) : _apiKey = apiKey;

  /// Get cached exchange rate
  Future<double?> getCachedRate(Currency from, Currency to) async {
    final cached = await (_db.select(_db.exchangeRates)
          ..where((r) => r.fromCurrency.equals(from.index) & r.toCurrency.equals(to.index)))
        .getSingleOrNull();

    if (cached == null) return null;

    // Consider stale if older than 1 hour
    final staleThreshold = DateTime.now().subtract(const Duration(hours: 1));
    if (cached.updatedAt.isBefore(staleThreshold)) return null;

    return cached.rate;
  }

  /// Cache an exchange rate
  Future<void> cacheRate(Currency from, Currency to, double rate) async {
    await _db.into(_db.exchangeRates).insertOnConflictUpdate(
      ExchangeRatesCompanion.insert(
        fromCurrency: from,
        toCurrency: to,
        rate: rate,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Fetch exchange rate from API
  Future<double?> fetchRate(Currency from, Currency to) async {
    if (_apiKey == null) return null;

    try {
      final response = await _dio.get(
        'https://v6.exchangerate-api.com/v6/$_apiKey/pair/${from.code}/${to.code}',
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['result'] == 'success') {
          final rate = (data['conversion_rate'] as num).toDouble();
          await cacheRate(from, to, rate);
          // Also cache the inverse
          await cacheRate(to, from, 1 / rate);
          return rate;
        }
      }
    } catch (e) {
      return getCachedRate(from, to);
    }
    return null;
  }

  /// Get any cached rate, ignoring staleness (last resort fallback)
  Future<double?> getStaleCachedRate(Currency from, Currency to) async {
    final cached = await (_db.select(_db.exchangeRates)
          ..where((r) => r.fromCurrency.equals(from.index) & r.toCurrency.equals(to.index)))
        .getSingleOrNull();
    return cached?.rate;
  }

  /// Get exchange rate (from cache or fetch, falls back to stale cache)
  Future<double?> getRate(Currency from, Currency to) async {
    if (from == to) return 1.0;

    // 1. Try fresh cached rate
    final cached = await getCachedRate(from, to);
    if (cached != null) return cached;

    // 2. Try fetching from API
    final fetched = await fetchRate(from, to);
    if (fetched != null) return fetched;

    // 3. Fall back to stale cached rate (better than nothing)
    return getStaleCachedRate(from, to);
  }

  /// Convert amount from one currency to another
  Future<double?> convert(double amount, Currency from, Currency to) async {
    final rate = await getRate(from, to);
    if (rate == null) return null;
    return amount * rate;
  }

  /// Seed default exchange rates (only if no rate exists for the pair)
  Future<void> seedDefaultRates() async {
    const defaultRates = {
      (Currency.usd, Currency.idr): 15500.0,
      (Currency.sgd, Currency.idr): 11500.0,
      (Currency.usd, Currency.sgd): 1.35,
    };

    for (final entry in defaultRates.entries) {
      final (from, to) = entry.key;
      final rate = entry.value;

      // Only seed if no rate exists at all (don't overwrite API-fetched rates)
      final existing = await getStaleCachedRate(from, to);
      if (existing == null) {
        await cacheRate(from, to, rate);
        await cacheRate(to, from, 1 / rate);
      }
    }
  }
}
