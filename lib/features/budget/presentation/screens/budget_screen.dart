import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/theme/colors.dart';

import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../providers/budget_provider.dart';
import 'budget_entry_screen.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final budgetsAsync = ref.watch(budgetsWithSpendingProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final showDecimal = ref.watch(showDecimalProvider);
    final trans = ref.watch(translationsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent, // Handled by DashboardShell
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                trans.budgetTitle,
                style: Theme.of(context).textTheme.headlineMedium,
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
                          Icon(
                            Icons.pie_chart_outline,
                            size: 64,
                            color: isLight ? const Color(0xFF94A3B8) : Colors.white54,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            trans.budgetNoBudgets,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: isLight ? const Color(0xFF94A3B8) : Colors.white54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            trans.budgetNoBudgetsHint,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isLight ? const Color(0xFFCBD5E1) : Colors.white30,
                            ),
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
                      final progressColor = item.progress > 0.9 ? Colors.red : (item.progress > 0.5 ? Colors.orange : AppColors.success);

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
                                      decoration: const BoxDecoration(
                                        color: AppColors.primaryGold,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.category_outlined, color: Colors.black, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.categoryName,
                                            style: Theme.of(context).textTheme.titleMedium,
                                          ),
                                          Text(
                                            isOverBudget
                                              ? '${trans.budgetExceeded} ${Formatters.formatCurrency(item.spentAmount - item.budget.amount, currency: baseCurrency, showDecimal: showDecimal)}'
                                              : '${trans.budgetRemaining} ${Formatters.formatCurrency(item.remainingAmount, currency: baseCurrency, showDecimal: showDecimal)}',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: isOverBudget
                                                  ? Colors.redAccent
                                                  : (isLight ? const Color(0xFF64748B) : Colors.white70),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          Formatters.formatCurrency(item.budget.amount, currency: baseCurrency, showDecimal: showDecimal),
                                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          trans.budgetAmount,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: isLight ? const Color(0xFF94A3B8) : Colors.white54,
                                          ),
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
                                    backgroundColor: isLight
                                        ? Colors.black.withValues(alpha: 0.08)
                                        : Colors.white10,
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
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: progressColor),
                                    ),
                                    Text(
                                      '${trans.budgetSpent}: ${Formatters.formatCurrency(item.spentAmount, currency: baseCurrency, showDecimal: showDecimal)}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: isLight ? const Color(0xFF64748B) : Colors.white70,
                                      ),
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
                error: (err, stack) => Center(child: Text('${trans.error}: $err', style: const TextStyle(color: Colors.red))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
