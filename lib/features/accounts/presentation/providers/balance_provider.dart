import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/database_providers.dart';

/// Provider to calculate current balance for each account
/// Returns a Map<int, double> where key is Account ID and value is Balance
final accountBalanceProvider = Provider<Map<int, double>>((ref) {
  final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? [];
  final transactions = ref.watch(transactionsStreamProvider).valueOrNull ?? [];

  final balances = <int, double>{};

  // Initialize with initial balances
  for (var account in accounts) {
    balances[account.id] = account.initialBalance;
  }

  // Apply transactions
  for (var trans in transactions) {
    final amount = trans.amount;
    final type = trans.type;

    // Source Account
    if (balances.containsKey(trans.accountId)) {
      if (type == TransactionType.income) {
        balances[trans.accountId] = balances[trans.accountId]! + amount;
      } else if (type == TransactionType.expense) {
        balances[trans.accountId] = balances[trans.accountId]! - amount;
      } else if (type == TransactionType.transfer) {
        balances[trans.accountId] = balances[trans.accountId]! - amount;
      }
    }

    // Destination Account (for Transfer)
    if (type == TransactionType.transfer && trans.toAccountId != null) {
      if (balances.containsKey(trans.toAccountId!)) {
        balances[trans.toAccountId!] = balances[trans.toAccountId!]! + (trans.destinationAmount ?? amount);
      }
    }
  }

  return balances;
});
