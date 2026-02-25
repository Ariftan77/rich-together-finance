import 'dart:convert';

/// Result of an exchange rate lookup.
///
/// All rates are USD-based: `1 USD = X foreign currency`.
/// [source] indicates where the data came from in the fallback chain.
class RateResult {
  final String rateDate;
  final String baseCurrency;
  final Map<String, double> rates;
  final bool isExactDate;
  final String source; // 'local', 'supabase', 'api'

  const RateResult({
    required this.rateDate,
    this.baseCurrency = 'USD',
    required this.rates,
    required this.isExactDate,
    required this.source,
  });

  /// Create from a Supabase row or local DB row where rates is already decoded.
  factory RateResult.fromRow(Map<String, dynamic> row, {required String source, bool isExactDate = true}) {
    final dynamic rawRates = row['rates'];
    final Map<String, double> parsedRates;
    if (rawRates is String) {
      final decoded = jsonDecode(rawRates) as Map<String, dynamic>;
      parsedRates = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } else if (rawRates is Map) {
      parsedRates = (rawRates as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble()));
    } else {
      parsedRates = {};
    }

    return RateResult(
      rateDate: row['rate_date'] as String,
      baseCurrency: row['base_currency'] as String? ?? 'USD',
      rates: parsedRates,
      isExactDate: isExactDate,
      source: source,
    );
  }

  /// Serialize rates to JSON string for local DB storage.
  String get ratesJson => jsonEncode(rates);

  /// Copy with a different source or isExactDate flag.
  RateResult copyWith({String? source, bool? isExactDate}) {
    return RateResult(
      rateDate: rateDate,
      baseCurrency: baseCurrency,
      rates: rates,
      isExactDate: isExactDate ?? this.isExactDate,
      source: source ?? this.source,
    );
  }

  @override
  String toString() =>
      'RateResult(date: $rateDate, base: $baseCurrency, source: $source, exact: $isExactDate, currencies: ${rates.length})';
}
