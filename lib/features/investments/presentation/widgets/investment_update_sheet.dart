import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/database.dart';
import '../../../../core/database/daos/investment_dao.dart';
import '../../../../core/providers/currency_exchange_providers.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/glass_segmented_control.dart';
import '../../domain/investment_math.dart';
import 'asset_type_display.dart';
import 'investment_money_field.dart';
import 'investment_wallet_field.dart';

/// One "Update values" session: pick a date, confirm every asset's value, and
/// write one snapshot per asset.
///
/// Values are pre-filled with what the user last entered, so re-confirming an
/// unchanged asset is a no-op they do not have to retype — and the asset still
/// gets a row, which is what keeps the timeline's points aligned.
///
/// [withdraw] opens every asset with the money field already set to
/// "Withdrawn".
Future<bool?> showInvestmentUpdateSheet(
  BuildContext context, {
  required List<InvestmentAssetView> views,
  bool withdraw = false,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _InvestmentUpdateSheet(views: views, withdraw: withdraw),
  );
}

class _InvestmentUpdateSheet extends ConsumerStatefulWidget {
  final List<InvestmentAssetView> views;
  final bool withdraw;

  const _InvestmentUpdateSheet({required this.views, required this.withdraw});

  @override
  ConsumerState<_InvestmentUpdateSheet> createState() =>
      _InvestmentUpdateSheetState();
}

class _InvestmentUpdateSheetState
    extends ConsumerState<_InvestmentUpdateSheet> {
  final _valueControllers = <int, TextEditingController>{};
  final _contributionControllers = <int, TextEditingController>{};
  final _contributionOpen = <int>{};
  /// Assets whose contribution is money taken out rather than put in. The
  /// amount field only accepts positive numbers, so direction is a toggle.
  final _withdrawing = <int>{};
  final _walletIds = <int, int>{};

  DateTime _date = InvestmentDao.dateOnly(DateTime.now());
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final showDecimal = ref.read(showDecimalProvider);
    for (final view in widget.views) {
      _valueControllers[view.asset.id] = TextEditingController(
        text: Formatters.formatCurrency(
          view.latestValue,
          currency: view.asset.currency,
          showDecimal: showDecimal,
        ),
      );
      _contributionControllers[view.asset.id] = TextEditingController();
      if (widget.withdraw) {
        _contributionOpen.add(view.asset.id);
        _withdrawing.add(view.asset.id);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _valueControllers.values) {
      c.dispose();
    }
    for (final c in _contributionControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final isLight = AppThemeProvider.isLightMode(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: (isLight ? ThemeData.light() : ThemeData.dark()).copyWith(
          colorScheme: isLight
              ? const ColorScheme.light(
                  primary: AppColors.primaryGoldTextLight,
                  surface: Colors.white,
                )
              : const ColorScheme.dark(
                  primary: AppColors.primaryGold,
                  surface: Color(0xFF221D10),
                ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _date = InvestmentDao.dateOnly(picked));
    }
  }

  Future<void> _save() async {
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) return;

    final trans = ref.read(translationsProvider);
    final baseCurrency = ref.read(defaultCurrencyProvider);
    final rates = ref.read(todayRatesProvider);
    final now = DateTime.now();

    final entries =
        <({InvestmentSnapshotsCompanion snapshot, int? walletAccountId})>[];
    for (final view in widget.views) {
      final asset = view.asset;
      final valueText = _valueControllers[asset.id]!.text;
      if (valueText.trim().isEmpty) continue;

      final value = Formatters.parseCurrency(valueText, currency: asset.currency);
      final amount = Formatters.parseCurrency(
        _contributionControllers[asset.id]!.text,
        currency: asset.currency,
      );
      final contribution =
          _withdrawing.contains(asset.id) ? -amount : amount;

      entries.add((
        walletAccountId: _walletIds[asset.id],
        snapshot: InvestmentSnapshotsCompanion.insert(
          profileId: profileId,
          assetId: asset.id,
          snapshotDate: _date,
          value: value,
          contribution: drift.Value(contribution),
          fxRateToBase: drift.Value(fxRateAtSave(
            assetCurrency: asset.currency,
            baseCurrency: baseCurrency,
            rates: rates,
          )),
          baseCurrency: baseCurrency,
          createdAt: now,
        ),
      ));
    }

    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trans.investmentUpdateNothingEntered)),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(investmentDaoProvider).saveSnapshotSession(entries);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trans = ref.watch(translationsProvider);
    final locale = ref.watch(localeProvider).languageCode;
    final isLight = AppThemeProvider.isLightMode(context);

    final textColor = AppColors.adaptiveText(context);
    final mutedColor = isLight ? const Color(0xFF64748B) : Colors.white60;
    final goldColor =
        isLight ? AppColors.primaryGoldTextLight : AppColors.primaryGold;
    final sheetColor = AppColors.themed3<Color>(
      context,
      defaultTheme: const Color(0xFF221D10),
      dark: const Color(0xFF141414),
      light: Colors.white,
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: sheetColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  trans.investmentUpdateTitle,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: mutedColor),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Date — back-dating is allowed, so a value remembered from last
          // month lands on the right point of the timeline.
          GestureDetector(
            onTap: _pickDate,
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              borderRadius: 12,
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: AppColors.primaryGold, size: 18),
                  const SizedBox(width: 10),
                  Text('${trans.investmentUpdateAsOf}  ',
                      style: TextStyle(color: mutedColor, fontSize: 13)),
                  Expanded(
                    child: Text(
                      DateFormat.yMMMd(locale).format(_date),
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(Icons.edit_calendar, color: mutedColor, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.views.length,
              itemBuilder: (context, index) {
                final view = widget.views[index];
                final asset = view.asset;
                final isOpen = _contributionOpen.contains(asset.id);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(assetTypeIcon(asset.assetType),
                              size: 16, color: mutedColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              asset.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InvestmentMoneyField(
                        controller: _valueControllers[asset.id]!,
                        currency: asset.currency,
                        hintText: trans.investmentUpdateValueLabel,
                        textInputAction: index == widget.views.length - 1
                            ? TextInputAction.done
                            : TextInputAction.next,
                      ),
                      const SizedBox(height: 6),
                      if (!isOpen)
                        // Collapsed by default: most updates are a re-valuation
                        // with no money moving in or out.
                        TextButton.icon(
                          onPressed: () => setState(
                              () => _contributionOpen.add(asset.id)),
                          icon: Icon(Icons.add_circle_outline,
                              size: 16, color: goldColor),
                          label: Text(
                            trans.investmentUpdateContributionLabel,
                            style: TextStyle(
                              color: goldColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size(0, 34),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor:
                                goldColor.withValues(alpha: isLight ? 0.06 : 0.08),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: goldColor.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        )
                      else ...[
                        Text(
                          trans.investmentUpdateContributionLabel,
                          style: TextStyle(color: mutedColor, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        GlassSegmentedControl<bool>(
                          value: _withdrawing.contains(asset.id),
                          options: const [false, true],
                          labels: [
                            trans.investmentContributionAdded,
                            trans.investmentContributionWithdrawn,
                          ],
                          onChanged: (withdraw) => setState(() => withdraw
                              ? _withdrawing.add(asset.id)
                              : _withdrawing.remove(asset.id)),
                        ),
                        const SizedBox(height: 8),
                        InvestmentMoneyField(
                          controller: _contributionControllers[asset.id]!,
                          currency: asset.currency,
                          hintText: '0',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trans.investmentUpdateContributionHint,
                          style: TextStyle(color: mutedColor, fontSize: 11),
                        ),
                        const SizedBox(height: 12),
                        InvestmentWalletField(
                          currency: asset.currency,
                          accountId: _walletIds[asset.id],
                          isWithdrawal: _withdrawing.contains(asset.id),
                          onChanged: (id) => setState(() => id == null
                              ? _walletIds.remove(asset.id)
                              : _walletIds[asset.id] = id),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),
          GlassButton(
            text: trans.investmentSaveButton,
            onPressed: _isSaving ? () {} : _save,
            isPrimary: true,
            isFullWidth: true,
            isLoading: _isSaving,
          ),
        ],
      ),
    );
  }
}
