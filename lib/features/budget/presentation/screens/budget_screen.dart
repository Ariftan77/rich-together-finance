import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/theme/colors.dart';

import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/category_icon_widget.dart';
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
                              color: isLight ? const Color(0xFF94A3B8) : Colors.white30,
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

                      // Resolve the display icon: user-chosen → single-cat icon → null.
                      final displayIcon = item.displayIcon;

                      // Avatar background color: use first category color when available.
                      final avatarBgColor = item.categories.isNotEmpty &&
                              item.categories.first.color != null
                          ? Color(int.parse(
                              item.categories.first.color!
                                  .replaceFirst('#', '0xFF')))
                          : AppColors.primaryGold;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BudgetEntryScreen(
                                    budgetWithSpending: item),
                              ),
                            );
                          },
                          onLongPress: item.linkedCategoryCount > 1
                              ? () => _showCategoryBreakdownDialog(
                                    context,
                                    ref,
                                    item,
                                    isLight,
                                    themeMode,
                                    baseCurrency,
                                    showDecimal,
                                    trans,
                                  )
                              : null,
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
                                        color: avatarBgColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: displayIcon != null
                                          ? CategoryIconWidget(
                                              iconString: displayIcon,
                                              size: 16,
                                              color: Colors.black,
                                            )
                                          : const Icon(
                                              Icons.category_outlined,
                                              color: Colors.black,
                                              size: 20,
                                            ),
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

  void _showCategoryBreakdownDialog(
    BuildContext context,
    WidgetRef ref,
    BudgetWithSpending item,
    bool isLight,
    AppThemeMode themeMode,
    dynamic baseCurrency,
    bool showDecimal,
    dynamic trans,
  ) {
    final isDefault = themeMode == AppThemeMode.defaultTheme;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: isDefault
            ? const Color(0xFF2D2416)
            : isLight
                ? const Color(0xFFF8FAFC)
                : const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: budget icon + name
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: item.displayIcon != null
                        ? CategoryIconWidget(
                            iconString: item.displayIcon!,
                            size: 20,
                            color: AppColors.primaryGold,
                          )
                        : const Icon(
                            Icons.category_outlined,
                            color: AppColors.primaryGold,
                            size: 20,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.categoryName,
                      style: TextStyle(
                        color: isLight ? AppColors.textPrimaryLight : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Subtitle label
              Text(
                'Spent per category',
                style: TextStyle(
                  color: isLight
                      ? const Color(0xFF94A3B8)
                      : Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Divider(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.1),
                height: 1,
              ),
              const SizedBox(height: 16),
              // Per-category rows
              ...item.categories.map((cat) {
                final catSpent = item.spentByCategory[cat.id] ?? 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      // Category icon
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: cat.color != null
                              ? Color(int.parse(
                                      cat.color!.replaceFirst('#', '0xFF')))
                                  .withValues(alpha: 0.2)
                              : AppColors.primaryGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: CategoryIconWidget(
                          iconString: cat.icon,
                          size: 16,
                          color: cat.color != null
                              ? Color(int.parse(
                                  cat.color!.replaceFirst('#', '0xFF')))
                              : AppColors.primaryGold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Category name
                      Expanded(
                        child: Text(
                          cat.name,
                          style: TextStyle(
                            color: isLight
                                ? AppColors.textPrimaryLight
                                : Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Spent amount
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            Formatters.formatCurrency(
                              catSpent,
                              currency: item.budget.currency,
                              showDecimal: showDecimal,
                            ),
                            style: TextStyle(
                              color: catSpent > 0
                                  ? (isLight
                                      ? AppColors.textPrimaryLight
                                      : Colors.white)
                                  : (isLight
                                      ? const Color(0xFF94A3B8)
                                      : Colors.white38),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'of ${Formatters.formatCurrency(item.budget.amount, currency: item.budget.currency, showDecimal: showDecimal)}',
                            style: TextStyle(
                              color: isLight
                                  ? const Color(0xFF94A3B8)
                                  : Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 4),
              // Close button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    trans.close,
                    style: TextStyle(
                      color: isLight
                          ? const Color(0xFF64748B)
                          : Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
