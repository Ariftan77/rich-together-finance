import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/utils/color_utils.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/category_icon_widget.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../debts/presentation/screens/debt_entry_screen.dart';
import '../../../debts/presentation/screens/debt_payment_view_screen.dart';
import '../screens/transaction_entry_screen.dart';

/// A single transaction row used by the transaction history list and the
/// full-history search screen. Tapping opens the matching editor/viewer.
///
/// [showFullDate] swaps the "time • category" subtitle for
/// "date • time • category" — search results span years, so the day matters.
class TransactionListItem extends ConsumerWidget {
  final Transaction transaction;
  final Category? category;
  final Account? account;
  final bool showFullDate;

  const TransactionListItem({
    super.key,
    required this.transaction,
    this.category,
    this.account,
    this.showFullDate = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight = AppThemeProvider.isLightMode(context);
    final showDecimal = ref.watch(showDecimalProvider);
    final hideCategoryIcon = ref.watch(hideCategoryIconProvider);
    final trans = ref.watch(translationsProvider);
    final isExpense = transaction.type == TransactionType.expense;
    final isIncome = transaction.type == TransactionType.income;
    final isAdjustmentIn = transaction.type == TransactionType.adjustmentIn;
    final isAdjustmentOut = transaction.type == TransactionType.adjustmentOut;
    final isDebtIn = transaction.type == TransactionType.debtIn;
    final isDebtOut = transaction.type == TransactionType.debtOut;
    final isDebtPaymentOut = transaction.type == TransactionType.debtPaymentOut;
    final isDebtPaymentIn = transaction.type == TransactionType.debtPaymentIn;

    // Localized transaction type name
    String localizedTypeName(TransactionType type) {
      switch (type) {
        case TransactionType.income: return trans.entryTypeIncome;
        case TransactionType.expense: return trans.entryTypeExpense;
        case TransactionType.transfer: return trans.entryTypeTransfer;
        case TransactionType.adjustmentIn: return trans.entryTypeAdjustmentIn;
        case TransactionType.adjustmentOut: return trans.entryTypeAdjustmentOut;
        case TransactionType.debtIn: return trans.entryTypeDebtIn;
        case TransactionType.debtOut: return trans.entryTypeDebtOut;
        case TransactionType.debtPaymentOut: return trans.entryTypeDebtPaymentOut;
        case TransactionType.debtPaymentIn: return trans.entryTypeDebtPaymentIn;
      }
    }

    final color = isExpense
        ? const Color(0xFFFB7185)
        : isIncome
            ? const Color(0xFF34D399)
            : (isAdjustmentIn || isAdjustmentOut)
                ? Colors.amber
                : isDebtIn
                    ? Colors.orange   // borrowed (I owe) — matches overview orange
                    : isDebtOut
                        ? const Color(0xFF60A5FA) // lent (owed to me) — matches overview blue
                        : isDebtPaymentOut
                            ? const Color(0xFFFB7185) // debt payment out — red (money leaving)
                            : isDebtPaymentIn
                                ? const Color(0xFF34D399) // debt payment in — green (money returning)
                                : const Color(0xFF60A5FA);
    final prefix = isExpense || isAdjustmentOut || isDebtOut || isDebtPaymentOut ? '-' : (isIncome || isAdjustmentIn || isDebtIn || isDebtPaymentIn ? '+' : '');
    
    // Data is now passed in, no need for Futures

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: () async {
          if (isDebtIn || isDebtOut) {
            // Debt creation transactions — open the debt record they belong to.
            final navigator = Navigator.of(context);

            // Precise path: follow the debtId link straight to the record.
            if (transaction.debtId != null) {
              final debt = await ref.read(debtDaoProvider).getDebtById(transaction.debtId!);
              if (!context.mounted) return;
              if (debt != null) {
                navigator.push(
                  MaterialPageRoute(
                    builder: (context) => DebtEntryScreen(debt: debt),
                  ),
                );
                return;
              }
            }

            // Legacy fallback for rows the v22 backfill could not link:
            // parse the person name from title "Debt: <name>" and match on
            // name + type + account/amount/date.
            final title = transaction.title ?? '';
            final personName = title.startsWith('Debt: ')
                ? title.substring(6).trim()
                : title.trim();

            final debtType = isDebtIn ? DebtType.payable : DebtType.receivable;
            final profileId = ref.read(activeProfileIdProvider);

            if (profileId != null && personName.isNotEmpty) {
              final debt = await ref.read(debtDaoProvider).findDebtByNameAndType(
                profileId,
                personName,
                debtType,
                accountId: transaction.accountId,
                date: transaction.date,
                amount: transaction.amount,
              );
              if (!context.mounted) return;
              if (debt != null) {
                navigator.push(
                  MaterialPageRoute(
                    builder: (context) => DebtEntryScreen(debt: debt),
                  ),
                );
                return;
              }
            }
            // Fallback: debt record not found — open normal transaction editor.
            navigator.push(
              MaterialPageRoute(
                builder: (context) => (transaction.type == TransactionType.debtPaymentOut ||
                        transaction.type == TransactionType.debtPaymentIn)
                    ? DebtPaymentViewScreen(transactionId: transaction.id)
                    : TransactionEntryScreen(transactionId: transaction.id, transactionType: transaction.type),
              ),
            );
          } else {
            // Navigate to edit page
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => (transaction.type == TransactionType.debtPaymentOut ||
                        transaction.type == TransactionType.debtPaymentIn)
                    ? DebtPaymentViewScreen(transactionId: transaction.id)
                    : TransactionEntryScreen(transactionId: transaction.id, transactionType: transaction.type),
              ),
            );
          }
        },
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
          children: [
            // Icon with colored background — dropped entirely when the
            // "hide category icon" setting is on (text starts at the edge).
            if (!hideCategoryIcon) ...[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isIncome || isExpense) && category != null
                      ? _categoryBgColor(category!.color)
                      : color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: (isIncome || isExpense) && category != null && category!.icon.isNotEmpty
                    ? Center(child: CategoryIconWidget(iconString: category!.icon, size: 20, color: color))
                    : Icon(_getIcon(transaction.type), color: color, size: 24),
              ),
              const SizedBox(width: 16),
            ],
            // Transaction details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Transaction title (or fallback to type)
                  Text(
                    transaction.title != null && transaction.title!.isNotEmpty 
                      ? transaction.title! 
                      : localizedTypeName(transaction.type),
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: isLight ? AppColors.textPrimaryLight : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Time and category
                  Builder(
                    builder: (context) {
                      final categoryName = category?.name ?? localizedTypeName(transaction.type);
                      final timeStr = _formatTime(transaction.date);
                      final prefixStr = showFullDate
                          ? '${DateFormat('d MMM yyyy').format(transaction.date)} • '
                          : '';
                      return Text(
                        '$prefixStr$timeStr • $categoryName',
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Amount and Account
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Builder(
                  builder: (context) {
                    final currencySymbol = account?.currency.code ?? 'IDR';
                    return Text(
                      '$currencySymbol $prefix${Formatters.formatCurrency(transaction.amount, showDecimal: showDecimal)}',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Builder(
                  builder: (context) {
                    final accountName = account?.name ?? trans.loading;
                    return Text(
                      accountName,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Color _categoryBgColor(String? hex) =>
      parseHexColor(hex).withValues(alpha: 0.25);

  IconData _getIcon(TransactionType type) {
    switch (type) {
      case TransactionType.income: return Icons.arrow_downward;
      case TransactionType.expense: return Icons.arrow_upward;
      case TransactionType.transfer: return Icons.swap_horiz;
      case TransactionType.adjustmentIn: return Icons.tune;
      case TransactionType.adjustmentOut: return Icons.tune;
      case TransactionType.debtIn: return Icons.people_outline;
      case TransactionType.debtOut: return Icons.people_outline;
      case TransactionType.debtPaymentOut:
      case TransactionType.debtPaymentIn:
        return Icons.handshake_outlined;
    }
  }
}
