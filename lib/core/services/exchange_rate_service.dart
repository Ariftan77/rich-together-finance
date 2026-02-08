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

  /// Get exchange rate (from cache or fetch)
  Future<double?> getRate(Currency from, Currency to) async {
    if (from == to) return 1.0;

    final cached = await getCachedRate(from, to);
    if (cached != null) return cached;

    return fetchRate(from, to);
  }

  /// Convert amount from one currency to another
  Future<double?> convert(double amount, Currency from, Currency to) async {
    final rate = await getRate(from, to);
    if (rate == null) return null;
    return amount * rate;
  }

  /// Seed default exchange rates (IDR-based, approximate)
  Future<void> seedDefaultRates() async {
    // Approximate rates - will be updated by API
    const defaultRates = {
      (Currency.usd, Currency.idr): 15500.0,
      (Currency.sgd, Currency.idr): 11500.0,
      (Currency.usd, Currency.sgd): 1.35,
    };

    for (final entry in defaultRates.entries) {
      final (from, to) = entry.key;
      final rate = entry.value;

      await cacheRate(from, to, rate);
      await cacheRate(to, from, 1 / rate);
    }
  }
}
