import 'package:flutter_riverpod/flutter_riverpod.dart';

/// API configuration
class ApiConfig {
  // CoinGecko API (free, no key required for basic endpoints)
  static const String coingeckoBaseUrl = 'https://api.coingecko.com/api/v3';

  // Alpha Vantage for stocks (requires API key)
  static const String alphaVantageBaseUrl = 'https://www.alphavantage.co/query';
  static String? alphaVantageApiKey;
}

/// API configuration provider
final apiConfigProvider = Provider<ApiConfig>((ref) => ApiConfig());
