import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/recurring_service.dart';

/// Provider to handle app initialization tasks
final appInitProvider = FutureProvider<void>((ref) async {
  // Check for recurring transactions
  final recurringService = ref.read(recurringServiceProvider);
  await recurringService.checkAndGenerateRecurringTransactions();
});
