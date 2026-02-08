import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dio HTTP client provider for API calls
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Accept': 'application/json',
    },
  ));

  // Add logging in debug mode
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
  ));

  return dio;
});

/// API configuration
class ApiConfig {
  // CoinGecko API (free, no key required for basic endpoints)
  static const String coingeckoBaseUrl = 'https://api.coingecko.com/api/v3';

  // Alpha Vantage for stocks (requires API key)
  static const String alphaVantageBaseUrl = 'https://www.alphavantage.co/query';
  static String? alphaVantageApiKey;

  // ExchangeRate-API for currency conversion
  static const String exchangeRateBaseUrl = 'https://v6.exchangerate-api.com/v6';
  static String? exchangeRateApiKey;
}

/// API configuration provider
final apiConfigProvider = Provider<ApiConfig>((ref) => ApiConfig());
