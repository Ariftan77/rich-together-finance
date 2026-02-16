import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/recurring_service.dart';
import 'service_providers.dart';

/// Provider to handle app initialization tasks
final appInitProvider = FutureProvider<void>((ref) async {
  // Seed default exchange rates (ensures baseline rates exist in cache)
  final exchangeService = ref.read(exchangeRateServiceProvider);
  await exchangeService.seedDefaultRates();

  // Check for recurring transactions
  final recurringService = ref.read(recurringServiceProvider);
  await recurringService.checkAndGenerateRecurringTransactions();
});
