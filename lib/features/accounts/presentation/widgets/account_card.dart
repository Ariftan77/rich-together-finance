import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';

import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/utils/formatters.dart';

class AccountCard extends ConsumerWidget {
  final Account account;
  final double balance; // Calculated balance
  final VoidCallback onTap;

  const AccountCard({
    super.key,
    required this.account,
    required this.balance, // Required now
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showDecimal = ref.watch(showDecimalProvider);
    final currencySymbol = account.currency.symbol;
    final accountType = account.type;
    final isLight = AppThemeProvider.isLightMode(context);

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${account.name} (${account.currency.code})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isLight ? AppColors.textPrimaryLight : Colors.white,
                  ),
                ),
                Text(
                  accountType.displayName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isLight ? const Color(0xFF64748B) : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${balance < 0 ? '-' : ''}$currencySymbol ${Formatters.formatCurrency(balance.abs(), currency: account.currency, showDecimal: showDecimal)}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: account.type.isCreditCard && balance < 0
                      ? AppColors.error
                      : AppColors.primaryGoldAccent,
                ),
              ),
              if (account.type.isCreditCard && balance < 0) ...[
                Text(
                  'Outstanding',
                  style: TextStyle(
                    color: AppColors.error.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
                if (account.paymentDueDay != null)
                  Builder(builder: (context) {
                    final now = DateTime.now();
                    final dueDay = account.paymentDueDay!;
                    final DateTime dueDate;
                    if (now.day <= dueDay) {
                      dueDate = DateTime(now.year, now.month, dueDay);
                    } else {
                      // Roll to next month
                      final nextMonth = DateTime(now.year, now.month + 1, 1);
                      dueDate = DateTime(nextMonth.year, nextMonth.month, dueDay);
                    }
                    final monthNames = [
                      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
                    ];
                    final label = 'Due ${monthNames[dueDate.month - 1]} ${dueDate.day}';
                    return Text(
                      label,
                      style: TextStyle(
                        color: AppColors.primaryGold.withValues(alpha: 0.9),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }),
              ],
            ],
          ),
        ],
      ),
    );
  }

}
