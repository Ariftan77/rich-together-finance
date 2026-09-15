import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/database.dart';
import '../../../../core/database/daos/investment_dao.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/currency_exchange_providers.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/currency_picker_field.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/glass_input.dart';
import '../../domain/investment_math.dart';
import '../providers/investment_providers.dart';
import '../widgets/asset_type_selector.dart';
import '../widgets/investment_money_field.dart';
import '../widgets/investment_sell_dialog.dart';
import '../widgets/investment_wallet_field.dart';

/// Adds a new investment asset (with its opening snapshot) or edits an
/// existing one's identity.
///
/// Currency is fixed once created: every snapshot stores values in the asset's
/// currency, so changing it later would silently reinterpret the whole history.
class InvestmentAssetEntryScreen extends ConsumerStatefulWidget {
  final InvestmentAsset? asset;

  const InvestmentAssetEntryScreen({super.key, this.asset});

  @override
  ConsumerState<InvestmentAssetEntryScreen> createState() =>
      _InvestmentAssetEntryScreenState();
}

class _InvestmentAssetEntryScreenState
    extends ConsumerState<InvestmentAssetEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _noteController;
  final _valueController = TextEditingController();
  final _investedController = TextEditingController();

  AssetType _type = AssetType.gold;
  Currency _currency = Currency.idr;
  DateTime _date = InvestmentDao.dateOnly(DateTime.now());
  bool _isLoading = false;
  int? _walletId;

  /// True until the user edits "invested so far" themselves, so it keeps
  /// mirroring the current value the way most first entries want.
  bool _investedFollowsValue = true;

  bool get _isEdit => widget.asset != null;

  @override
  void initState() {
    super.initState();
    final asset = widget.asset;
    _nameController = TextEditingController(text: asset?.name ?? '');
    _noteController = TextEditingController(text: asset?.note ?? '');
    if (asset != null) {
      _type = asset.assetType;
      _currency = asset.currency;
    } else {
      _currency = ref.read(defaultCurrencyProvider);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    _valueController.dispose();
    _investedController.dispose();
    super.dispose();
  }

  double get _value =>
      Formatters.parseCurrency(_valueController.text, currency: _currency);

  double get _invested => _investedFollowsValue
      ? _value
      : Formatters.parseCurrency(_investedController.text, currency: _currency);

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
    if (!_formKey.currentState!.validate()) return;
    final trans = ref.read(translationsProvider);

    if (!_isEdit && _value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trans.errorInvalidAmount)),
      );
      return;
    }

    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) return;

    setState(() => _isLoading = true);
    try {
      final dao = ref.read(investmentDaoProvider);
      final now = DateTime.now();

      if (_isEdit) {
        await dao.updateAsset(
          widget.asset!.copyWith(
            name: _nameController.text.trim(),
            assetType: _type,
            note: drift.Value(
              _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
            ),
            updatedAt: now,
            isSynced: false,
          ),
        );
      } else {
        final assetId = await dao.createAsset(
          InvestmentAssetsCompanion.insert(
            profileId: profileId,
            name: _nameController.text.trim(),
            assetType: _type,
            currency: _currency,
            note: drift.Value(
              _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
            ),
            createdAt: now,
            updatedAt: now,
          ),
        );

        final baseCurrency = ref.read(defaultCurrencyProvider);
        await dao.saveSnapshot(
          InvestmentSnapshotsCompanion.insert(
            profileId: profileId,
            assetId: assetId,
            snapshotDate: _date,
            value: _value,
            // The opening balance is capital, not gain.
            contribution: drift.Value(_invested),
            fxRateToBase: drift.Value(fxRateAtSave(
              assetCurrency: _currency,
              baseCurrency: baseCurrency,
              rates: ref.read(todayRatesProvider),
            )),
            baseCurrency: baseCurrency,
            createdAt: now,
          ),
          walletAccountId: _walletId,
        );
      }

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markSold() async {
    final asset = widget.asset!;
    final view = ref
        .read(investmentSummaryProvider)
        .assets
        .where((v) => v.asset.id == asset.id)
        .firstOrNull;

    final sold = await showInvestmentSellDialog(
      context,
      asset: asset,
      currentValue: view?.latestValue ?? 0,
    );
    if (sold == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(translationsProvider).investmentSellDone)),
      );
      // true tells the detail screen underneath that the asset is gone.
      Navigator.pop(context, true);
    }
  }

  Future<void> _deleteAsset() async {
    final trans = ref.read(translationsProvider);
    final isLight = AppThemeProvider.isLightMode(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.themed3<Color>(
          context,
          defaultTheme: const Color(0xFF221D10),
          dark: const Color(0xFF1A1A1A),
          light: Colors.white,
        ),
        title: Text(
          trans.investmentDeleteAsset,
          style: TextStyle(color: AppColors.adaptiveText(context), fontSize: 17),
        ),
        content: Text(
          trans.investmentDeleteAssetConfirm,
          style: TextStyle(
            color: isLight ? const Color(0xFF64748B) : Colors.white70,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(trans.genericCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              trans.investmentDeleteConfirmAction,
              style: TextStyle(
                color: isLight ? AppColors.errorLight : AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(investmentDaoProvider).deleteAsset(widget.asset!.id);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final trans = ref.watch(translationsProvider);
    final isLight = AppThemeProvider.isLightMode(context);
    final textColor = AppColors.adaptiveText(context);
    final mutedColor = isLight ? const Color(0xFF64748B) : Colors.white70;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: AppColors.backgroundGradient(context),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: textColor),
            title: Text(
              _isEdit ? trans.investmentEditAssetTitle : trans.investmentAddAssetTitle,
              style: TextStyle(color: textColor),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlassInput(
                      controller: _nameController,
                      hintText: trans.investmentAssetNameHint,
                      prefixIcon: Icons.label_outline,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? trans.investmentAssetNameLabel
                          : null,
                    ),
                    const SizedBox(height: 20),

                    AssetTypeField(
                      value: _type,
                      onChanged: (v) => setState(() => _type = v),
                    ),
                    const SizedBox(height: 20),

                    Text(trans.investmentAssetCurrencyLabel,
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    if (_isEdit)
                      // Locked: snapshots hold values in this currency.
                      GlassCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        borderRadius: 12,
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline, size: 18, color: mutedColor),
                            const SizedBox(width: 12),
                            Text(
                              '${_currency.code} (${_currency.symbol})',
                              style: TextStyle(color: textColor, fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    else
                      CurrencyPickerField(
                        value: _currency,
                        onChanged: (c) => setState(() {
                          _currency = c;
                          _walletId = null;
                        }),
                      ),

                    if (!_isEdit) ...[
                      const SizedBox(height: 20),
                      Text(trans.investmentCurrentValueLabel,
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      InvestmentMoneyField(
                        controller: _valueController,
                        currency: _currency,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) {
                          if (_investedFollowsValue) setState(() {});
                        },
                      ),
                      const SizedBox(height: 20),

                      Text(trans.investmentInvestedSoFarLabel,
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      InvestmentMoneyField(
                        controller: _investedController,
                        currency: _currency,
                        hintText: _investedFollowsValue && _value > 0
                            ? Formatters.formatCurrency(_value,
                                currency: _currency,
                                showDecimal: ref.watch(showDecimalProvider))
                            : '0',
                        onChanged: (v) {
                          final touched = v.trim().isNotEmpty;
                          if (touched == _investedFollowsValue) {
                            setState(() => _investedFollowsValue = !touched);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        trans.investmentInvestedSoFarHint,
                        style: TextStyle(color: mutedColor, fontSize: 12),
                      ),
                      const SizedBox(height: 20),

                      InvestmentWalletField(
                        currency: _currency,
                        accountId: _walletId,
                        isWithdrawal: false,
                        onChanged: (id) => setState(() => _walletId = id),
                      ),
                      const SizedBox(height: 20),

                      Text(trans.investmentUpdateAsOf,
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickDate,
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          borderRadius: 12,
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  color: AppColors.primaryGold, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat.yMMMd(
                                        ref.watch(localeProvider).languageCode)
                                    .format(_date),
                                style: TextStyle(color: textColor, fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    GlassInput(
                      controller: _noteController,
                      hintText: trans.investmentNoteLabel,
                      prefixIcon: Icons.notes,
                      maxLines: 2,
                    ),

                    const SizedBox(height: 32),
                    GlassButton(
                      text: trans.investmentSaveButton,
                      onPressed: _isLoading ? () {} : _save,
                      isPrimary: true,
                      isFullWidth: true,
                      isLoading: _isLoading,
                    ),

                    if (_isEdit) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _markSold,
                        icon: Icon(Icons.sell_outlined,
                            size: 18, color: mutedColor),
                        label: Text(
                          trans.investmentSellAction,
                          style: TextStyle(color: mutedColor, fontSize: 13),
                        ),
                      ),
                      Center(
                        child: TextButton.icon(
                          onPressed: _deleteAsset,
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: isLight
                                ? AppColors.errorLight
                                : AppColors.error,
                          ),
                          label: Text(
                            trans.investmentDeleteAsset,
                            style: TextStyle(
                              color: isLight
                                  ? AppColors.errorLight
                                  : AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
