import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
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
                  style: AppTypography.textTheme.titleMedium,
                ),
                Text(
                  accountType.displayName,
                  style: AppTypography.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${balance < 0 ? '-' : ''}$currencySymbol ${Formatters.formatCurrency(balance.abs(), currency: account.currency, showDecimal: showDecimal)}',
                style: AppTypography.textTheme.labelLarge?.copyWith(
                  color: account.type.isCreditCard && balance < 0
                      ? AppColors.error
                      : AppColors.primaryGoldAccent,
                ),
              ),
              if (account.type.isCreditCard && balance < 0)
                Text(
                  'Outstanding',
                  style: TextStyle(
                    color: AppColors.error.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

}
