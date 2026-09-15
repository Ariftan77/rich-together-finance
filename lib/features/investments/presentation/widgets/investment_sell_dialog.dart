import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database.dart';
import '../../../../core/database/daos/investment_dao.dart';
import '../../../../core/providers/currency_exchange_providers.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/investment_math.dart';
import 'investment_money_field.dart';
import 'investment_wallet_field.dart';

/// Marks an asset as sold.
///
/// Writes a final snapshot of zero value with the proceeds recorded as a
/// negative contribution, then archives the asset. Modelling the sale as a
/// withdrawal is what keeps the gain earned before it in the chart — simply
/// deleting the asset would erase that history.
Future<bool?> showInvestmentSellDialog(
  BuildContext context, {
  required InvestmentAsset asset,
  required double currentValue,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _InvestmentSellDialog(
      asset: asset,
      currentValue: currentValue,
    ),
  );
}

class _InvestmentSellDialog extends ConsumerStatefulWidget {
  final InvestmentAsset asset;
  final double currentValue;

  const _InvestmentSellDialog({
    required this.asset,
    required this.currentValue,
  });

  @override
  ConsumerState<_InvestmentSellDialog> createState() =>
      _InvestmentSellDialogState();
}

class _InvestmentSellDialogState extends ConsumerState<_InvestmentSellDialog> {
  late final TextEditingController _proceedsController;
  bool _isSaving = false;
  int? _walletId;

  @override
  void initState() {
    super.initState();
    // Defaults to the last known value — usually close to what was received.
    _proceedsController = TextEditingController(
      text: widget.currentValue > 0
          ? Formatters.formatCurrency(
              widget.currentValue,
              currency: widget.asset.currency,
              showDecimal: ref.read(showDecimalProvider),
            )
          : '',
    );
  }

  @override
  void dispose() {
    _proceedsController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) return;

    final proceeds = Formatters.parseCurrency(
      _proceedsController.text,
      currency: widget.asset.currency,
    );

    setState(() => _isSaving = true);
    try {
      final dao = ref.read(investmentDaoProvider);
      final baseCurrency = ref.read(defaultCurrencyProvider);
      final now = DateTime.now();

      await dao.saveSnapshot(
        InvestmentSnapshotsCompanion.insert(
          profileId: profileId,
          assetId: widget.asset.id,
          snapshotDate: InvestmentDao.dateOnly(now),
          value: 0,
          // Negative contribution = capital taken back out.
          contribution: drift.Value(-proceeds),
          fxRateToBase: drift.Value(fxRateAtSave(
            assetCurrency: widget.asset.currency,
            baseCurrency: baseCurrency,
            rates: ref.read(todayRatesProvider),
          )),
          baseCurrency: baseCurrency,
          createdAt: now,
        ),
        // Proceeds land in the wallet as an investmentIn transaction.
        walletAccountId: _walletId,
      );
      await dao.setAssetArchived(widget.asset.id, true);

      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trans = ref.watch(translationsProvider);
    final isLight = AppThemeProvider.isLightMode(context);
    final textColor = AppColors.adaptiveText(context);
    final mutedColor = isLight ? const Color(0xFF64748B) : Colors.white60;

    return AlertDialog(
      // The wallet field makes the content tall enough to clash with the
      // keyboard on small phones.
      scrollable: true,
      backgroundColor: AppColors.themed3<Color>(
        context,
        defaultTheme: const Color(0xFF221D10),
        dark: const Color(0xFF1A1A1A),
        light: Colors.white,
      ),
      title: Text(
        trans.investmentSellTitle,
        style: TextStyle(color: textColor, fontSize: 17),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.asset.name,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            trans.investmentSellProceedsLabel,
            style: TextStyle(color: mutedColor, fontSize: 12),
          ),
          const SizedBox(height: 8),
          InvestmentMoneyField(
            controller: _proceedsController,
            currency: widget.asset.currency,
            autofocus: true,
          ),
          const SizedBox(height: 12),
          Text(
            trans.investmentSellHint,
            style: TextStyle(color: mutedColor, fontSize: 11),
          ),
          const SizedBox(height: 16),
          InvestmentWalletField(
            currency: widget.asset.currency,
            accountId: _walletId,
            isWithdrawal: true,
            onChanged: (id) => setState(() => _walletId = id),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(
            trans.genericCancel,
            style: TextStyle(color: mutedColor),
          ),
        ),
        TextButton(
          onPressed: _isSaving ? null : _confirm,
          child: Text(
            trans.investmentSellAction,
            style: TextStyle(
              color: isLight
                  ? AppColors.primaryGoldTextLight
                  : AppColors.primaryGold,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
