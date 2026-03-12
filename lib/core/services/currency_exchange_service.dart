import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/rate_result.dart';
import 'local_rate_store.dart';

/// Offline-first currency exchange rate service.
///
/// Fallback chain: Local DB → Supabase → open.er-api (170+ currencies) → Frankfurter (patched) → hardcoded.
/// All rates are USD-based: `1 USD = X foreign currency`.
/// Stores full rates JSON blob per day — not per-currency-pair rows.
class CurrencyExchangeService {
  final LocalRateStore _localStore;
  final Dio _dio;
  final SupabaseClient _supabase;

  static const _exchangeRateBase = 'https://open.er-api.com/v6';
  static const _frankfurterBase = 'https://api.frankfurter.app';
  static const _supabaseTable = 'exchange_rates';
  static const _weekendToleranceDays = 3;

  // In-memory cache — shared across all callers within the same app session.
  // Keyed by date string; cleared automatically when the date changes.
  RateResult? _memCache;
  String? _memCacheDate;

  // In-flight request coalescing — all concurrent callers for the same date
  // share a single Future so only one Supabase/API call is ever made.
  Future<RateResult>? _inFlightFuture;
  String? _inFlightDate;

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

  /// Get exchange rates for [date] (defaults to today UTC).
  ///
  /// Weekday chain (Mon–Fri):
  ///   Local exact → Supabase exact → API → [API failed: Local tolerance → Supabase tolerance → hardcoded]
  ///
  /// Weekend chain (Sat–Sun):
  ///   Local exact → Local tolerance → Supabase exact → Supabase tolerance → hardcoded
  Future<RateResult> getRates({String? date}) async {
    final requestedDate = date ?? _today();

    // In-memory cache hit — return immediately, no DB or network I/O
    if (_memCache != null && _memCacheDate == requestedDate) {
      debugPrint('[CurrencyExchangeService] requested=$requestedDate source=mem_cache total_ms=0');
      return _memCache!;
    }

    // Coalesce concurrent calls — if a fetch is already in-flight for today,
    // return the same Future so only one Supabase/API call is made.
    if (_inFlightFuture != null && _inFlightDate == requestedDate) {
      debugPrint('[CurrencyExchangeService] requested=$requestedDate source=coalesced');
      return _inFlightFuture!;
    }

    final future = _doGetRates(requestedDate);
    _inFlightFuture = future;
    _inFlightDate = requestedDate;
    try {
      return await future;
    } finally {
      if (_inFlightDate == requestedDate) {
        _inFlightFuture = null;
        _inFlightDate = null;
      }
    }
  }

  Future<RateResult> _doGetRates(String requestedDate) async {
    final isWeekend = _isWeekend(requestedDate);
    final totalSw = Stopwatch()..start();
    final steps = <String>[];

    int _ms(Stopwatch sw) { sw.stop(); return sw.elapsedMilliseconds; }

    // 1. Exact match in local DB (always checked first)
    var sw = Stopwatch()..start();
    final local = await _localStore.get(requestedDate);
    steps.add('local_exact:${_ms(sw)}ms(${local != null ? 'hit' : 'miss'})');
    if (local != null) {
      final patched = _patchMissingRates(local, requestedDate);
      _cacheResult(requestedDate, patched);
      _log(requestedDate, patched, totalSw: totalSw, steps: steps);
      return patched;
    }

    // 1b. Weekend tolerance — only on Sat/Sun, skip on weekdays so we always try the API
    if (isWeekend) {
      sw = Stopwatch()..start();
      final latestLocal = await _localStore.getLatest();
      if (latestLocal != null && _isWithinDays(latestLocal.rateDate, requestedDate, _weekendToleranceDays)) {
        steps.add('local_tolerance:${_ms(sw)}ms(hit:${latestLocal.rateDate})');
        final patched = _patchMissingRates(latestLocal.copyWith(isExactDate: false), requestedDate);
        _cacheResult(requestedDate, patched);
        _log(requestedDate, patched, totalSw: totalSw, steps: steps);
        return patched;
      }
      steps.add('local_tolerance:${_ms(sw)}ms(miss)');
    }

    // 2. Exact match in Supabase
    sw = Stopwatch()..start();
    final supabaseResult = await _fetchFromSupabase(requestedDate);
    steps.add('supabase_exact:${_ms(sw)}ms(${supabaseResult != null ? 'hit' : 'miss'})');
    if (supabaseResult != null) {
      final patched = _patchMissingRates(supabaseResult, requestedDate);
      await _safeLocalWrite(patched.copyWith(source: 'local'));
      _cacheResult(requestedDate, patched);
      _log(requestedDate, patched, totalSw: totalSw, steps: steps);
      return patched;
    }

    // 2b. Weekend tolerance from Supabase — only on Sat/Sun
    if (isWeekend) {
      sw = Stopwatch()..start();
      final latestSupabase = await _fetchLatestFromSupabase();
      if (latestSupabase != null && _isWithinDays(latestSupabase.rateDate, requestedDate, _weekendToleranceDays)) {
        steps.add('supabase_latest:${_ms(sw)}ms(hit:${latestSupabase.rateDate})');
        final patched = _patchMissingRates(latestSupabase.copyWith(isExactDate: false), requestedDate);
        await _safeLocalWrite(patched.copyWith(source: 'local'));
        _cacheResult(requestedDate, patched);
        _log(requestedDate, patched, totalSw: totalSw, steps: steps);
        return patched;
      }
      steps.add('supabase_latest:${_ms(sw)}ms(miss)');
      // Weekend and no stored data close enough — fall through to hardcoded
      final hardcodedResult = _getHardcodedRates(requestedDate);
      _cacheResult(requestedDate, hardcodedResult);
      _log(requestedDate, hardcodedResult, totalSw: totalSw, steps: steps);
      return hardcodedResult;
    }

    // 3. Weekday: fetch from open.er-api (170+ currencies)
    try {
      sw = Stopwatch()..start();
      final apiResult = await _fetchFromOpenER();
      steps.add('open_er:${_ms(sw)}ms(hit)');
      await _safeSupabaseWrite(apiResult);
      await _safeLocalWrite(apiResult.copyWith(source: 'local'));
      _cacheResult(requestedDate, apiResult);
      _log(requestedDate, apiResult, totalSw: totalSw, steps: steps);
      return apiResult;
    } catch (e) {
      steps.add('open_er:${_ms(sw)}ms(fail)');
      developer.log('open.er-api failed: $e', name: 'CurrencyExchangeService');
    }

    // 4. Weekday: fallback to Frankfurter (32 currencies; patch missing from hardcoded)
    try {
      sw = Stopwatch()..start();
      final frankfurterResult = await _fetchFromFrankfurter();
      steps.add('frankfurter:${_ms(sw)}ms(hit)');
      final patched = _patchMissingRates(frankfurterResult, requestedDate);
      await _safeSupabaseWrite(patched);
      await _safeLocalWrite(patched.copyWith(source: 'local'));
      _cacheResult(requestedDate, patched);
      _log(requestedDate, patched, totalSw: totalSw, steps: steps);
      return patched;
    } catch (e) {
      steps.add('frankfurter:${_ms(sw)}ms(fail)');
      developer.log('Both APIs failed: $e', name: 'CurrencyExchangeService');
    }

    // 5. Weekday API failure: fall back to most recent stored data within tolerance
    sw = Stopwatch()..start();
    final latestLocal = await _localStore.getLatest();
    if (latestLocal != null && _isWithinDays(latestLocal.rateDate, requestedDate, _weekendToleranceDays)) {
      steps.add('local_tolerance_fallback:${_ms(sw)}ms(hit:${latestLocal.rateDate})');
      final patched = _patchMissingRates(latestLocal.copyWith(isExactDate: false), requestedDate);
      _cacheResult(requestedDate, patched);
      _log(requestedDate, patched, totalSw: totalSw, steps: steps);
      return patched;
    }
    steps.add('local_tolerance_fallback:${_ms(sw)}ms(miss)');

    sw = Stopwatch()..start();
    final latestSupabase = await _fetchLatestFromSupabase();
    if (latestSupabase != null && _isWithinDays(latestSupabase.rateDate, requestedDate, _weekendToleranceDays)) {
      steps.add('supabase_latest_fallback:${_ms(sw)}ms(hit:${latestSupabase.rateDate})');
      final patched = _patchMissingRates(latestSupabase.copyWith(isExactDate: false), requestedDate);
      await _safeLocalWrite(patched.copyWith(source: 'local'));
      _cacheResult(requestedDate, patched);
      _log(requestedDate, patched, totalSw: totalSw, steps: steps);
      return patched;
    }
    steps.add('supabase_latest_fallback:${_ms(sw)}ms(miss)');

    // 6. Last resort: hardcoded
    final hardcodedResult = _getHardcodedRates(requestedDate);
    _cacheResult(requestedDate, hardcodedResult);
    _log(requestedDate, hardcodedResult, totalSw: totalSw, steps: steps);
    return hardcodedResult;
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

    developer.log(
      'No exchange rate data available for date $date or any fallback date. '
      'Falling back to hardcoded rates.',
      name: 'CurrencyExchangeService'
    );
    final hardcodedResult = _getHardcodedRates(date);
    _log(date, hardcodedResult);
    return hardcodedResult;
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

  Future<RateResult> _fetchFromOpenER() async {
    try {
      final response = await _dio.get('$_exchangeRateBase/latest/USD').timeout(const Duration(seconds: 3));

      if (response.statusCode != 200) {
        throw ExchangeRateException('open.er-api returned status ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;
      if (data['result'] != 'success') {
        throw ExchangeRateException('open.er-api error: ${data['error-type']}');
      }

      final rawRates = (data['rates'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble()));

      final updateUnix = data['time_last_update_unix'] as int?;
      final rateDate = updateUnix != null ? _utcDateFromUnix(updateUnix) : _today();

      return RateResult(
        rateDate: rateDate,
        baseCurrency: 'USD',
        rates: rawRates,
        isExactDate: true,
        source: 'api',
      );
    } on DioException catch (e) {
      throw ExchangeRateException('open.er-api fetch failed: ${e.message}');
    } catch (e) {
      throw ExchangeRateException('open.er-api unexpected error: $e');
    }
  }

  Future<RateResult> _fetchFromFrankfurter() async {
    try {
      final response = await _dio.get('$_frankfurterBase/latest?base=USD').timeout(const Duration(seconds: 3));

      if (response.statusCode != 200) {
        throw ExchangeRateException('Frankfurter returned status ${response.statusCode}');
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
      throw ExchangeRateException('Frankfurter fetch failed: ${e.message}');
    } catch (e) {
      throw ExchangeRateException('Frankfurter unexpected error: $e');
    }
  }

  /// Patches currencies missing from [result] (e.g. SAR, KHR, VND not in Frankfurter)
  /// with hardcoded fallback values.
  RateResult _patchMissingRates(RateResult result, String date) {
    final hardcoded = _getHardcodedRates(date).rates;
    final patched = Map<String, double>.from(result.rates);
    for (final entry in hardcoded.entries) {
      patched.putIfAbsent(entry.key, () => entry.value);
    }
    return RateResult(
      rateDate: result.rateDate,
      baseCurrency: result.baseCurrency,
      rates: patched,
      isExactDate: result.isExactDate,
      source: result.source,
    );
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
          'source': result.source,
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
  // Hardcoded Fallback
  // ---------------------------------------------------------------------------

  RateResult _getHardcodedRates(String date) {
    return RateResult(
      rateDate: date,
      baseCurrency: 'USD',
      rates: {
        'USD': 1.0,
        'IDR': 16800.0,
        'SGD': 1.35,
        'MYR': 4.75,
        'THB': 36.50,
        'SAR': 3.75,
        'JPY': 149.0,
        'CNY': 7.24,
        'KRW': 1320.0,
        'AUD': 1.53,
        'KHR': 4100.0,
        'VND': 24800.0,
        'PHP': 55.80,
        'EUR': 0.92,
      },
      isExactDate: false,
      source: 'hardcoded',
    );
  }

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  String _today() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _utcDateFromUnix(int unixSeconds) {
    final dt = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000, isUtc: true);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// Returns true if [date] falls on Saturday or Sunday (UTC).
  bool _isWeekend(String date) {
    final weekday = DateTime.parse(date).toUtc().weekday;
    return weekday == DateTime.saturday || weekday == DateTime.sunday;
  }

  /// Returns true if [storedDate] is within [days] of [targetDate].
  bool _isWithinDays(String storedDate, String targetDate, int days) {
    final stored = DateTime.parse(storedDate);
    final target = DateTime.parse(targetDate);
    return target.difference(stored).inDays.abs() <= days;
  }

  void _cacheResult(String date, RateResult result) {
    _memCache = result;
    _memCacheDate = date;
  }

  void _log(String requestedDate, RateResult result, {Stopwatch? totalSw, List<String>? steps}) {
    totalSw?.stop();
    final stepStr = steps != null && steps.isNotEmpty ? ' | ${steps.join(' → ')}' : '';
    debugPrint(
      '[CurrencyExchangeService] '
      'requested=$requestedDate '
      'returned=${result.rateDate} '
      'source=${result.source}'
      '${totalSw != null ? ' total_ms=${totalSw.elapsedMilliseconds}' : ''}'
      '$stepStr',
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
