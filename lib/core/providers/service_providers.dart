import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/exchange_rate_service.dart';
import 'database_providers.dart';

// Dio provider
final dioProvider = Provider<Dio>((ref) {
  return Dio();
});

// Exchange Rate Service Provider
final exchangeRateServiceProvider = Provider<ExchangeRateService>((ref) {
  final db = ref.watch(databaseProvider);
  final dio = ref.watch(dioProvider);
  // Optional: Get API key from environment or config
  return ExchangeRateService(dio, db); // apiKey: 'YOUR_API_KEY'
});
