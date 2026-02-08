import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../transactions/presentation/screens/transaction_entry_screen.dart';

/// Widget displaying recent transactions
class RecentTransactionsWidget extends ConsumerWidget {
  final List<Transaction> transactions;
  
  const RecentTransactionsWidget({
    super.key,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (transactions.isEmpty) {
      return GlassCard(
        child: Container(
          height: 150,
          alignment: Alignment.center,
          child: Text(
            'No transactions yet',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    final accountsAsync = ref.watch(accountsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return accountsAsync.when(
      data: (accounts) => categoriesAsync.when(
        data: (categories) {
          final accountMap = {for (var a in accounts) a.id: a.name};
          final categoryMap = {for (var c in categories) c.id: c.name};

          return GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Transactions',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Navigate to transactions history
                          // The shell already has this tab, so we don't need to navigate
                        },
                        child: Text(
                          'View All',
                          style: TextStyle(
                            color: AppColors.primaryGold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...transactions.map((transaction) {
                    final accountName = accountMap[transaction.accountId] ?? 'Unknown';
                    final categoryName = transaction.categoryId != null
                        ? (categoryMap[transaction.categoryId] ?? 'Unknown')
                        : 'No Category';
                    
                    final isIncome = transaction.type == TransactionType.income;
                    final isExpense = transaction.type == TransactionType.expense;
                    
                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TransactionEntryScreen(
                              transactionId: transaction.id,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Icon
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: (isIncome
                                        ? AppColors.success
                                        : isExpense
                                            ? AppColors.error
                                            : AppColors.info)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isIncome
                                    ? Icons.arrow_downward
                                    : isExpense
                                        ? Icons.arrow_upward
                                        : Icons.swap_horiz,
                                color: isIncome
                                    ? AppColors.success
                                    : isExpense
                                        ? AppColors.error
                                        : AppColors.info,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    transaction.title ?? categoryName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        accountName,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        ' • ',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('MMM dd').format(transaction.date),
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Amount
                            Text(
                              '${isIncome ? '+' : isExpense ? '-' : ''} ${Formatters.formatCurrency(transaction.amount)}',
                              style: TextStyle(
                                color: isIncome
                                    ? AppColors.success
                                    : isExpense
                                        ? AppColors.error
                                        : Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }
}
