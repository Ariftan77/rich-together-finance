import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/category_icon_widget.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../transactions/presentation/screens/transaction_entry_screen.dart';
import '../../../debts/presentation/screens/debt_payment_view_screen.dart';

/// Widget displaying recent transactions
class RecentTransactionsWidget extends ConsumerWidget {
  final List<Transaction> transactions;
  
  const RecentTransactionsWidget({
    super.key,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

    if (transactions.isEmpty) {
        return GlassCard(
          child: Container(
            height: 150,
            alignment: Alignment.center,
            child: Text(
              ref.watch(translationsProvider).noTransactions,
              style: TextStyle(
                color: isLight
                    ? const Color(0xFF94A3B8)
                    : Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ),
        );
    }

    final accountsAsync = ref.watch(accountsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final showDecimal = ref.watch(showDecimalProvider);

    return accountsAsync.when(
      data: (accounts) => categoriesAsync.when(
        data: (categories) {
          final accountMap = {for (var a in accounts) a.id: a.name};
          final categoryMap = {for (var c in categories) c.id: c};

          return GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ref.watch(translationsProvider).recentTransactions,
                        style: TextStyle(
                          color: isLight ? AppColors.textPrimaryLight : Colors.white,
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
                          ref.watch(translationsProvider).viewAll,
                          style: const TextStyle(
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
                    final category = transaction.categoryId != null
                        ? categoryMap[transaction.categoryId]
                        : null;
                    final categoryName = category?.name ?? 'No Category';
                    
                    final isIncome = transaction.type == TransactionType.income;
                    final isExpense = transaction.type == TransactionType.expense;
                    final isAdjustmentIn = transaction.type == TransactionType.adjustmentIn;
                    final isAdjustmentOut = transaction.type == TransactionType.adjustmentOut;
                    final isAdjustment = isAdjustmentIn || isAdjustmentOut;
                    final isDebtIn = transaction.type == TransactionType.debtIn;
                    final isDebtOut = transaction.type == TransactionType.debtOut;
                    final isDebt = isDebtIn || isDebtOut;
                    final isDebtPaymentOut = transaction.type == TransactionType.debtPaymentOut;
                    final isDebtPaymentIn = transaction.type == TransactionType.debtPaymentIn;
                    final isDebtPayment = isDebtPaymentOut || isDebtPaymentIn;
                    
                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => (transaction.type == TransactionType.debtPaymentOut ||
                                    transaction.type == TransactionType.debtPaymentIn)
                                ? DebtPaymentViewScreen(transactionId: transaction.id)
                                : TransactionEntryScreen(
                                    transactionId: transaction.id,
                                    transactionType: transaction.type,
                                  ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isLight
                                  ? Colors.black.withValues(alpha: 0.08)
                                  : Colors.white.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Icon
                            Builder(builder: (context) {
                              final typeColor = isIncome
                                  ? AppColors.success
                                  : isExpense
                                      ? AppColors.error
                                      : isAdjustment
                                          ? Colors.amber
                                          : isDebtIn
                                              ? Colors.orange
                                              : isDebtOut
                                                  ? const Color(0xFF60A5FA)
                                                  : isDebtPaymentOut
                                                      ? AppColors.error
                                                      : isDebtPaymentIn
                                                          ? AppColors.success
                                                          : AppColors.info;
                              final useCategoryIcon = (isIncome || isExpense) &&
                                  category != null &&
                                  category.icon.isNotEmpty;
                              Color bgColor;
                              if (useCategoryIcon) {
                                final hex = category!.color;
                                if (hex == null || hex == 'transparent' || hex.isEmpty) {
                                  bgColor = Colors.transparent;
                                } else {
                                  final cleaned = hex.replaceFirst('#', '0xFF');
                                  bgColor = Color(int.tryParse(cleaned) ?? 0xFF808080).withValues(alpha: 0.25);
                                }
                              } else {
                                bgColor = typeColor.withValues(alpha: 0.2);
                              }
                              return Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: typeColor.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: useCategoryIcon
                                    ? Center(child: CategoryIconWidget(iconString: category!.icon, size: 18, color: typeColor))
                                    : Icon(
                                        isIncome
                                            ? Icons.arrow_downward
                                            : isExpense
                                                ? Icons.arrow_upward
                                                : isAdjustment
                                                    ? Icons.tune
                                                    : isDebt
                                                        ? Icons.people_outline
                                                        : isDebtPayment
                                                            ? Icons.handshake_outlined
                                                            : Icons.swap_horiz,
                                        color: typeColor,
                                        size: 20,
                                      ),
                              );
                            }),
                            const SizedBox(width: 12),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    transaction.title ?? categoryName,
                                    style: TextStyle(
                                      color: isLight ? AppColors.textPrimaryLight : Colors.white,
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
                                          color: isLight
                                              ? const Color(0xFF64748B)
                                              : Colors.white.withValues(alpha: 0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        ' • ',
                                        style: TextStyle(
                                          color: isLight
                                              ? const Color(0xFF64748B)
                                              : Colors.white.withValues(alpha: 0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('MMM dd', ref.watch(localeProvider).languageCode).format(transaction.date),
                                        style: TextStyle(
                                          color: isLight
                                              ? const Color(0xFF64748B)
                                              : Colors.white.withValues(alpha: 0.6),
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
                              '${isIncome || isAdjustmentIn || isDebtIn || isDebtPaymentIn ? '+' : isExpense || isAdjustmentOut || isDebtOut || isDebtPaymentOut ? '-' : ''} ${Formatters.formatCurrency(transaction.amount, showDecimal: showDecimal)}',
                              style: TextStyle(
                                color: isIncome
                                    ? AppColors.success
                                    : isExpense
                                        ? AppColors.error
                                        : isAdjustment
                                            ? Colors.amber
                                            : isDebtIn
                                                ? Colors.orange
                                                : isDebtOut
                                                    ? const Color(0xFF60A5FA)
                                                    : isDebtPaymentOut
                                                        ? AppColors.error
                                                        : isDebtPaymentIn
                                                            ? AppColors.success
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
