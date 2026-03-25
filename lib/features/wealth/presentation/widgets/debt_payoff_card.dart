import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/currency_exchange_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/services/currency_exchange_service.dart';
import '../../../../shared/theme/colors.dart';

import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_card.dart';

class DebtPayoffCard extends ConsumerWidget {
  const DebtPayoffCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(debtsStreamProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final rates = ref.watch(todayRatesProvider);
    final showDecimal = ref.watch(showDecimalProvider);
    final trans = ref.watch(translationsProvider);
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;

    return debtsAsync.when(
      data: (allDebts) {
        final payableDebts = allDebts
            .where((d) => d.type == DebtType.payable && !d.isSettled)
            .toList();
        final receivableDebts = allDebts
            .where((d) => d.type == DebtType.receivable && !d.isSettled)
            .toList();

        if (payableDebts.isEmpty && receivableDebts.isEmpty) {
          return const SizedBox.shrink();
        }

        // Convert helpers
        double convertRemaining(Debt d) {
          final remaining = d.amount - d.paidAmount;
          if (remaining <= 0) return 0;
          if (d.currency == baseCurrency) return remaining;
          return CurrencyExchangeService.convertCurrency(
              remaining, d.currency.code, baseCurrency.code, rates);
        }

        double convertTotal(Debt d) {
          if (d.currency == baseCurrency) return d.amount;
          return CurrencyExchangeService.convertCurrency(
              d.amount, d.currency.code, baseCurrency.code, rates);
        }

        double sumConverted(List<Debt> list) =>
            list.fold(0.0, (sum, d) => sum + convertRemaining(d));

        _DebtSectionData buildSection(List<Debt> debts) {
          final today = DateTime.now();
          final todayDate = DateTime(today.year, today.month, today.day);
          final overdue = <Debt>[];
          final dueSoon = <Debt>[];
          final noDeadline = <Debt>[];

          for (final d in debts) {
            if (d.dueDate == null) {
              noDeadline.add(d);
            } else {
              final due = DateTime(d.dueDate!.year, d.dueDate!.month, d.dueDate!.day);
              if (due.isBefore(todayDate)) {
                overdue.add(d);
              } else {
                final daysLeft = due.difference(todayDate).inDays;
                if (daysLeft <= 30) {
                  dueSoon.add(d);
                } else {
                  noDeadline.add(d);
                }
              }
            }
          }

          final totalRemaining = sumConverted(debts);
          final totalOriginal = debts.fold(0.0, (sum, d) => sum + convertTotal(d));
          final totalPaid = totalOriginal - totalRemaining;
          final progress = totalOriginal > 0
              ? (totalPaid / totalOriginal).clamp(0.0, 1.0)
              : 0.0;

          final datedDebts = debts
              .where((d) => d.dueDate != null)
              .toList()
            ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

          return _DebtSectionData(
            totalRemaining: totalRemaining,
            totalPaid: totalPaid,
            progress: progress,
            overdue: overdue,
            dueSoon: dueSoon,
            noDeadline: noDeadline,
            earliestDue: datedDebts.isNotEmpty ? datedDebts.first.dueDate : null,
            sumConverted: sumConverted,
          );
        }

        final textColor = isLight ? AppColors.textPrimaryLight : Colors.white;
        final subtextColor = isLight
            ? const Color(0xFF64748B)
            : Colors.white.withValues(alpha: 0.55);
        final dividerColor = isLight
            ? Colors.black.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.1);

        return GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trans.debtPayoffTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),

              // I Owe section
              if (payableDebts.isNotEmpty) ...[
                _DebtSection(
                  label: trans.debtPayable,
                  data: buildSection(payableDebts),
                  amountColor: isLight ? AppColors.errorLight : AppColors.error,
                  progressColor: isLight ? AppColors.errorLight : AppColors.error,
                  baseCurrency: baseCurrency,
                  showDecimal: showDecimal,
                  isLight: isLight,
                  subtextColor: subtextColor,
                  overdueLabel: trans.debtPayoffOverdue,
                  dueSoonLabel: trans.debtPayoffDueSoon,
                  noDeadlineLabel: trans.debtPayoffNoDeadline,
                  nextDueLabel: trans.debtPayoffNextDue,
                  paidLabel: trans.debtPayoffPaid,
                ),
              ],

              // Divider between sections
              if (payableDebts.isNotEmpty && receivableDebts.isNotEmpty) ...[
                const SizedBox(height: 14),
                Divider(height: 1, thickness: 1, color: dividerColor),
                const SizedBox(height: 14),
              ],

              // Owed to Me section
              if (receivableDebts.isNotEmpty) ...[
                _DebtSection(
                  label: trans.debtReceivable,
                  data: buildSection(receivableDebts),
                  amountColor: isLight ? AppColors.successLight : AppColors.success,
                  progressColor: isLight ? AppColors.successLight : AppColors.success,
                  baseCurrency: baseCurrency,
                  showDecimal: showDecimal,
                  isLight: isLight,
                  subtextColor: subtextColor,
                  overdueLabel: trans.debtPayoffOverdue,
                  dueSoonLabel: trans.debtPayoffDueSoon,
                  noDeadlineLabel: trans.debtPayoffNoDeadline,
                  nextDueLabel: trans.debtPayoffNextDue,
                  paidLabel: trans.debtPayoffCollected,
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ---------------------------------------------------------------------------
// Data holder
// ---------------------------------------------------------------------------

class _DebtSectionData {
  final double totalRemaining;
  final double totalPaid;
  final double progress;
  final List<Debt> overdue;
  final List<Debt> dueSoon;
  final List<Debt> noDeadline;
  final DateTime? earliestDue;
  final double Function(List<Debt>) sumConverted;

  _DebtSectionData({
    required this.totalRemaining,
    required this.totalPaid,
    required this.progress,
    required this.overdue,
    required this.dueSoon,
    required this.noDeadline,
    required this.earliestDue,
    required this.sumConverted,
  });
}

// ---------------------------------------------------------------------------
// Section widget (reused for both payable and receivable)
// ---------------------------------------------------------------------------

class _DebtSection extends StatelessWidget {
  final String label;
  final _DebtSectionData data;
  final Color amountColor;
  final Color progressColor;
  final Currency baseCurrency;
  final bool showDecimal;
  final bool isLight;
  final Color subtextColor;
  final String overdueLabel;
  final String dueSoonLabel;
  final String noDeadlineLabel;
  final String nextDueLabel;
  final String paidLabel; // "paid" or "collected"

  const _DebtSection({
    required this.label,
    required this.data,
    required this.amountColor,
    required this.progressColor,
    required this.baseCurrency,
    required this.showDecimal,
    required this.isLight,
    required this.subtextColor,
    required this.overdueLabel,
    required this.dueSoonLabel,
    required this.noDeadlineLabel,
    required this.nextDueLabel,
    required this.paidLabel,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isLight ? AppColors.textPrimaryLight : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label row + next due date
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: amountColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (data.earliestDue != null)
              Text(
                '$nextDueLabel: ${DateFormat.yMMMd().format(data.earliestDue!)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: subtextColor,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Total remaining
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${baseCurrency.symbol} ${Formatters.formatCurrency(data.totalRemaining, showDecimal: showDecimal)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: amountColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'remaining',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: subtextColor,
              ),
            ),
          ],
        ),

        // Paid/collected label
        Text(
          '${baseCurrency.symbol} ${Formatters.formatCurrency(data.totalPaid, showDecimal: showDecimal)} $paidLabel',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: subtextColor,
          ),
        ),

        const SizedBox(height: 10),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: data.progress,
            minHeight: 6,
            backgroundColor: isLight
                ? Colors.black.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),

        const SizedBox(height: 14),

        // Urgency breakdown
        _UrgencyRow(
          color: isLight ? AppColors.errorLight : AppColors.error,
          label: overdueLabel,
          count: data.overdue.length,
          amount: data.sumConverted(data.overdue),
          baseCurrency: baseCurrency,
          showDecimal: showDecimal,
          isLight: isLight,
        ),
        const SizedBox(height: 6),
        _UrgencyRow(
          color: Colors.amber,
          label: dueSoonLabel,
          count: data.dueSoon.length,
          amount: data.sumConverted(data.dueSoon),
          baseCurrency: baseCurrency,
          showDecimal: showDecimal,
          isLight: isLight,
        ),
        const SizedBox(height: 6),
        _UrgencyRow(
          color: isLight ? AppColors.successLight : AppColors.success,
          label: noDeadlineLabel,
          count: data.noDeadline.length,
          amount: data.sumConverted(data.noDeadline),
          baseCurrency: baseCurrency,
          showDecimal: showDecimal,
          isLight: isLight,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Urgency row
// ---------------------------------------------------------------------------

class _UrgencyRow extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final double amount;
  final Currency baseCurrency;
  final bool showDecimal;
  final bool isLight;

  const _UrgencyRow({
    required this.color,
    required this.label,
    required this.count,
    required this.amount,
    required this.baseCurrency,
    required this.showDecimal,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    final subtextColor = isLight
        ? const Color(0xFF64748B)
        : Colors.white.withValues(alpha: 0.55);

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: count > 0 ? color : color.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label: $count',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: count > 0
                  ? (isLight ? AppColors.textPrimaryLight : Colors.white.withValues(alpha: 0.85))
                  : subtextColor,
            ),
          ),
        ),
        if (count > 0)
          Text(
            '${baseCurrency.symbol} ${Formatters.formatCurrency(amount, showDecimal: showDecimal)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}
