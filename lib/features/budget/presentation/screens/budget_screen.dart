import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/fab_button.dart';
import '../providers/budget_provider.dart';
import 'budget_entry_screen.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsWithSpendingProvider);
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: Colors.transparent, // Handled by DashboardShell
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Budgets',
                    style: AppTypography.textTheme.headlineMedium,
                  ),
                  // Header add button
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const BudgetEntryScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: budgetsAsync.when(
                data: (budgets) {
                  if (budgets.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.pie_chart_outline, size: 64, color: Colors.white54),
                          const SizedBox(height: 16),
                          Text(
                            'No budgets yet',
                            style: AppTypography.textTheme.bodyLarge?.copyWith(color: Colors.white54),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap + to create a budget',
                            style: AppTypography.textTheme.bodyMedium?.copyWith(color: Colors.white30),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: budgets.length,
                    itemBuilder: (context, index) {
                      final item = budgets[index];
                      final isOverBudget = item.progress > 1.0;
                      final progressColor = isOverBudget ? Colors.red : (item.progress > 0.8 ? Colors.orange : AppColors.primaryGold);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BudgetEntryScreen(budget: item.budget),
                              ),
                            );
                          },
                          child: GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: item.categoryColor.isNotEmpty 
                                          ? Color(int.parse(item.categoryColor.replaceFirst('#', '0xFF'))) 
                                          : Colors.grey,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(item.categoryIcon, style: const TextStyle(fontSize: 20)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.categoryName,
                                            style: AppTypography.textTheme.titleMedium,
                                          ),
                                          Text(
                                            isOverBudget 
                                              ? 'Over by ${currencyFormatter.format(item.spentAmount - item.budget.amount)}'
                                              : '${currencyFormatter.format(item.remainingAmount)} remaining',
                                            style: AppTypography.textTheme.bodySmall?.copyWith(
                                              color: isOverBudget ? Colors.redAccent : Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          currencyFormatter.format(item.budget.amount),
                                          style: AppTypography.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          'Limit',
                                          style: AppTypography.textTheme.bodySmall?.copyWith(color: Colors.white54),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: item.progress.clamp(0.0, 1.0),
                                    backgroundColor: Colors.white10,
                                    color: progressColor,
                                    minHeight: 8,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${(item.progress * 100).toStringAsFixed(1)}%',
                                      style: AppTypography.textTheme.bodySmall?.copyWith(color: progressColor),
                                    ),
                                    Text(
                                      'Spent: ${currencyFormatter.format(item.spentAmount)}',
                                      style: AppTypography.textTheme.bodySmall?.copyWith(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
