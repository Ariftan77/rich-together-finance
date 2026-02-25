import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/recurring_service.dart';
import 'currency_exchange_providers.dart';

/// Provider to handle app initialization tasks
final appInitProvider = FutureProvider<void>((ref) async {
  // Fetch real exchange rates (seeds local DB on first launch)
  final currencyExchangeService = ref.read(currencyExchangeServiceProvider);
  await currencyExchangeService.getRates();

  // Check for recurring transactions
  final recurringService = ref.read(recurringServiceProvider);
  await recurringService.checkAndGenerateRecurringTransactions();
});
