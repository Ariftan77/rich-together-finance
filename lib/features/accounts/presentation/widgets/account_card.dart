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
    final currencySymbol = account.currency == Currency.idr ? 'Rp' : '\$';
    
    // Convert int type to Enum
    final accountType = account.type;

    return GlassCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getIconForType(accountType),
              color: AppColors.primaryGold,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
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
                '$currencySymbol ${Formatters.formatCurrency(balance, currency: account.currency, showDecimal: showDecimal)}', 
                style: AppTypography.textTheme.labelLarge?.copyWith(
                  color: AppColors.primaryGoldAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return Icons.wallet;
      case AccountType.bank:
        return Icons.account_balance;
      case AccountType.eWallet:
        return Icons.phone_android;
      case AccountType.investment:
        return Icons.trending_up;
    }
  }
}
