import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/enums.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../transactions/presentation/widgets/account_selector.dart';

/// Optional wallet a contribution moves through.
///
/// Only wallets in the asset's [currency] are offered: the transaction amount
/// is the contribution as typed, so a different currency would move the wrong
/// amount of money.
class InvestmentWalletField extends ConsumerWidget {
  final Currency currency;
  final int? accountId;
  final ValueChanged<int?> onChanged;

  /// Picks the hint under the field: money leaving the wallet or entering it.
  final bool isWithdrawal;

  const InvestmentWalletField({
    super.key,
    required this.currency,
    required this.accountId,
    required this.onChanged,
    required this.isWithdrawal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trans = ref.watch(translationsProvider);
    final isLight = AppThemeProvider.isLightMode(context);
    final wallets = (ref.watch(accountsStreamProvider).valueOrNull ?? [])
        .where((a) => a.currency == currency)
        .toList();
    final selected = wallets.where((a) => a.id == accountId).firstOrNull;

    final mutedColor = isLight
        ? const Color(0xFF64748B)
        : Colors.white.withValues(alpha: 0.6);
    final hintColor = isLight
        ? const Color(0xFF94A3B8)
        : Colors.white.withValues(alpha: 0.4);
    final chevronColor = isLight
        ? const Color(0xFFCBD5E1)
        : Colors.white.withValues(alpha: 0.3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            trans.investmentWalletLabel.toUpperCase(),
            style: TextStyle(
              color: mutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        GestureDetector(
          onTap: wallets.isEmpty
              ? null
              : () {
                  FocusScope.of(context).unfocus();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (modalContext) => Padding(
                      padding: EdgeInsets.only(
                        bottom: math.max(
                          MediaQuery.of(modalContext).viewInsets.bottom,
                          MediaQuery.of(modalContext).viewPadding.bottom,
                        ),
                      ),
                      child: AccountSelector(
                        accounts: wallets,
                        selectedAccountId: accountId,
                        showDecimal: ref.read(showDecimalProvider),
                        onAccountSelected: onChanged,
                      ),
                    ),
                  );
                },
          child: Container(
            height: 56,
            padding: const EdgeInsets.only(left: 16, right: 4),
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.black.withValues(alpha: 0.04)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.primaryGold.withValues(alpha: 0.8),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selected?.name ??
                        (wallets.isEmpty
                            ? trans.investmentWalletNoneInCurrency(currency.code)
                            : trans.investmentWalletNone),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected != null
                          ? (isLight ? AppColors.textPrimaryLight : Colors.white)
                          : hintColor,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (selected != null)
                  IconButton(
                    icon: Icon(Icons.close, color: mutedColor, size: 20),
                    onPressed: () => onChanged(null),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(Icons.expand_more, color: chevronColor),
                  ),
              ],
            ),
          ),
        ),
        if (selected != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              isWithdrawal
                  ? trans.investmentWalletWithdrawnHint
                  : trans.investmentWalletAddedHint,
              style: TextStyle(color: mutedColor, fontSize: 11),
            ),
          ),
        ],
      ],
    );
  }
}
