import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/rate_result.dart';
import 'local_rate_store.dart';

/// Offline-first currency exchange rate service.
///
/// Fallback chain: Local DB → Supabase → Frankfurter API.
/// All rates are USD-based: `1 USD = X foreign currency`.
/// Stores full rates JSON blob per day — not per-currency-pair rows.
class CurrencyExchangeService {
  final LocalRateStore _localStore;
  final Dio _dio;
  final SupabaseClient _supabase;

  static const _frankfurterBase = 'https://api.frankfurter.app';
  static const _supabaseTable = 'exchange_rates';
  static const _weekendToleranceDays = 3;

  CurrencyExchangeService({
    required LocalRateStore localStore,
    required Dio dio,
    required SupabaseClient supabase,
  })  : _localStore = localStore,
        _dio = dio,
        _supabase = supabase;

  // ---------------------------------------------------------------------------
  // getRates — today's rates via full fallback chain
  // ---------------------------------------------------------------------------

  /// Get exchange rates for [date] (defaults to today).
  ///
  /// Checks Local DB → Supabase → Frankfurter API.
  /// Weekend/holiday handling: if the latest stored record is within 3 days,
  /// return it without any network call.
  Future<RateResult> getRates({String? date}) async {
    final requestedDate = date ?? _today();

    // 1. Check local DB
    final local = await _localStore.get(requestedDate);
    if (local != null) {
      _log(requestedDate, local);
      return local;
    }

    // 1b. Weekend/holiday tolerance — check if latest local record is recent enough
    final latestLocal = await _localStore.getLatest();
    if (latestLocal != null && _isWithinDays(latestLocal.rateDate, requestedDate, _weekendToleranceDays)) {
      final result = latestLocal.copyWith(isExactDate: false);
      _log(requestedDate, result);
      return result;
    }

    // 2. Check Supabase
    final supabaseResult = await _fetchFromSupabase(requestedDate);
    if (supabaseResult != null) {
      await _safeLocalWrite(supabaseResult.copyWith(source: 'local'));
      _log(requestedDate, supabaseResult);
      return supabaseResult;
    }

    // 2b. Weekend/holiday tolerance — check latest Supabase record
    final latestSupabase = await _fetchLatestFromSupabase();
    if (latestSupabase != null && _isWithinDays(latestSupabase.rateDate, requestedDate, _weekendToleranceDays)) {
      final result = latestSupabase.copyWith(isExactDate: false);
      await _safeLocalWrite(result.copyWith(source: 'local'));
      _log(requestedDate, result);
      return result;
    }

    // 3. Fetch from Frankfurter API (latest rates only)
    final apiResult = await _fetchFromApi();

    // Write back down the chain: API → Supabase → local
    await _safeSupabaseWrite(apiResult);
    await _safeLocalWrite(apiResult.copyWith(source: 'local'));

    _log(requestedDate, apiResult);
    return apiResult;
  }

  // ---------------------------------------------------------------------------
  // getRatesForDate — historical date lookup (never calls API)
  // ---------------------------------------------------------------------------

  /// Get rates for a specific historical [date].
  ///
  /// Checks local DB → Supabase for exact match, then falls back to the
  /// closest older date. Never calls Frankfurter API for historical dates.
  Future<RateResult> getRatesForDate(String date) async {
    // 1. Exact match in local DB
    final localExact = await _localStore.get(date);
    if (localExact != null) {
      _log(date, localExact);
      return localExact;
    }

    // 2. Exact match in Supabase
    final supabaseExact = await _fetchFromSupabase(date);
    if (supabaseExact != null) {
      await _safeLocalWrite(supabaseExact.copyWith(source: 'local'));
      _log(date, supabaseExact);
      return supabaseExact;
    }

    // 3. Closest older date from local DB
    final localClosest = await _localStore.getClosestBefore(date);
    if (localClosest != null) {
      final result = localClosest.copyWith(isExactDate: false);
      _log(date, result);
      return result;
    }

    // 4. Closest older date from Supabase
    final supabaseClosest = await _fetchClosestBeforeFromSupabase(date);
    if (supabaseClosest != null) {
      final result = supabaseClosest.copyWith(isExactDate: false);
      await _safeLocalWrite(result.copyWith(source: 'local'));
      _log(date, result);
      return result;
    }

    // 5. Last resort — oldest record available (local first, then Supabase)
    final localOldest = await _localStore.getOldest();
    if (localOldest != null) {
      final result = localOldest.copyWith(isExactDate: false);
      _log(date, result);
      return result;
    }

    final supabaseOldest = await _fetchOldestFromSupabase();
    if (supabaseOldest != null) {
      final result = supabaseOldest.copyWith(isExactDate: false);
      await _safeLocalWrite(result.copyWith(source: 'local'));
      _log(date, result);
      return result;
    }

    throw ExchangeRateException(
      'No exchange rate data available for date $date or any fallback date. '
      'Ensure the app has been online at least once to seed initial rates.',
    );
  }

  // ---------------------------------------------------------------------------
  // convertCurrency — pure arithmetic, no I/O
  // ---------------------------------------------------------------------------

  /// Convert [amount] from [from] currency to [to] currency using USD-based [rates].
  ///
  /// Handles three cases:
  /// - USD → X: `amount * rates[X]`
  /// - X → USD: `amount / rates[X]`
  /// - X → Y (cross rate): `(amount / rates[from]) * rates[to]`
  static double convertCurrency(
    double amount,
    String from,
    String to,
    Map<String, double> rates,
  ) {
    if (from == to) return amount;

    final fromUpper = from.toUpperCase();
    final toUpper = to.toUpperCase();

    if (fromUpper == 'USD') {
      final toRate = rates[toUpper];
      if (toRate == null) throw ExchangeRateException('No rate found for $toUpper');
      return amount * toRate;
    }

    if (toUpper == 'USD') {
      final fromRate = rates[fromUpper];
      if (fromRate == null) throw ExchangeRateException('No rate found for $fromUpper');
      return amount / fromRate;
    }

    // Cross rate via USD
    final fromRate = rates[fromUpper];
    final toRate = rates[toUpper];
    if (fromRate == null) throw ExchangeRateException('No rate found for $fromUpper');
    if (toRate == null) throw ExchangeRateException('No rate found for $toUpper');
    return (amount / fromRate) * toRate;
  }

  // ---------------------------------------------------------------------------
  // Frankfurter API
  // ---------------------------------------------------------------------------

  Future<RateResult> _fetchFromApi() async {
    try {
      final response = await _dio.get('$_frankfurterBase/latest?base=USD');

      if (response.statusCode != 200) {
        throw ExchangeRateException(
          'Frankfurter API returned status ${response.statusCode}',
        );
      }

      final data = response.data as Map<String, dynamic>;
      final rawRates = (data['rates'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble()));

      return RateResult(
        rateDate: data['date'] as String,
        baseCurrency: 'USD',
        rates: rawRates,
        isExactDate: true,
        source: 'api',
      );
    } on DioException catch (e) {
      throw ExchangeRateException(
        'Failed to fetch rates from Frankfurter API: ${e.message}',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Supabase helpers
  // ---------------------------------------------------------------------------

  Future<RateResult?> _fetchFromSupabase(String date) async {
    try {
      final response = await _supabase
          .from(_supabaseTable)
          .select()
          .eq('rate_date', date)
          .eq('base_currency', 'USD')
          .maybeSingle();

      if (response == null) return null;
      return RateResult.fromRow(response, source: 'supabase', isExactDate: true);
    } catch (e) {
      developer.log('Supabase read failed: $e', name: 'CurrencyExchangeService');
      return null;
    }
  }

  Future<RateResult?> _fetchLatestFromSupabase() async {
    try {
      final response = await _supabase
          .from(_supabaseTable)
          .select()
          .eq('base_currency', 'USD')
          .order('rate_date', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return RateResult.fromRow(response, source: 'supabase', isExactDate: true);
    } catch (e) {
      developer.log('Supabase latest read failed: $e', name: 'CurrencyExchangeService');
      return null;
    }
  }

  Future<RateResult?> _fetchClosestBeforeFromSupabase(String date) async {
    try {
      final response = await _supabase
          .from(_supabaseTable)
          .select()
          .eq('base_currency', 'USD')
          .lte('rate_date', date)
          .order('rate_date', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return RateResult.fromRow(response, source: 'supabase', isExactDate: response['rate_date'] == date);
    } catch (e) {
      developer.log('Supabase closest-before read failed: $e', name: 'CurrencyExchangeService');
      return null;
    }
  }

  Future<RateResult?> _fetchOldestFromSupabase() async {
    try {
      final response = await _supabase
          .from(_supabaseTable)
          .select()
          .eq('base_currency', 'USD')
          .order('rate_date', ascending: true)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return RateResult.fromRow(response, source: 'supabase', isExactDate: true);
    } catch (e) {
      developer.log('Supabase oldest read failed: $e', name: 'CurrencyExchangeService');
      return null;
    }
  }

  Future<void> _safeSupabaseWrite(RateResult result) async {
    try {
      await _supabase.from(_supabaseTable).upsert(
        {
          'rate_date': result.rateDate,
          'base_currency': result.baseCurrency,
          'rates': result.rates,
          'fetched_at': DateTime.now().toUtc().toIso8601String(),
          'source': 'frankfurter',
        },
        onConflict: 'rate_date,base_currency',
      );
    } catch (e) {
      developer.log('Supabase write failed (non-fatal): $e', name: 'CurrencyExchangeService');
    }
  }

  // ---------------------------------------------------------------------------
  // Local DB helpers
  // ---------------------------------------------------------------------------

  Future<void> _safeLocalWrite(RateResult result) async {
    try {
      await _localStore.set(result);
    } catch (e) {
      developer.log('Local DB write failed (non-fatal): $e', name: 'CurrencyExchangeService');
    }
  }

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Returns true if [storedDate] is within [days] of [targetDate].
  bool _isWithinDays(String storedDate, String targetDate, int days) {
    final stored = DateTime.parse(storedDate);
    final target = DateTime.parse(targetDate);
    return target.difference(stored).inDays.abs() <= days;
  }

  void _log(String requestedDate, RateResult result) {
    developer.log(
      'requested_date=$requestedDate '
      'returned_date=${result.rateDate} '
      'is_exact_date=${result.isExactDate} '
      'source=${result.source} '
      'base_currency=${result.baseCurrency}',
      name: 'CurrencyExchangeService',
    );
  }
}

/// Custom exception for exchange rate errors.
class ExchangeRateException implements Exception {
  final String message;
  const ExchangeRateException(this.message);

  @override
  String toString() => 'ExchangeRateException: $message';
}
