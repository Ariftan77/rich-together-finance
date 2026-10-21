import 'package:flutter/material.dart';
import '../../core/localization/app_translations.dart';
import '../../core/models/enums.dart';
import '../../features/investments/domain/investment_math.dart';
import '../../features/investments/presentation/widgets/asset_type_display.dart';
import '../theme/app_theme_mode.dart';
import '../theme/colors.dart';
import '../theme/theme_provider_widget.dart';
import '../utils/formatters.dart';
import 'glass_card.dart';

/// A tappable field that opens a multi-select investment asset picker modal.
/// Mirrors [MultiAccountPickerField]: selected chips above the trigger.
class MultiInvestmentPickerField extends StatelessWidget {
  final List<InvestmentAssetView> assets;
  final Set<int> selectedIds;
  final ValueChanged<Set<int>> onChanged;
  final bool showDecimal;
  final AppTranslations trans;

  const MultiInvestmentPickerField({
    super.key,
    required this.assets,
    required this.selectedIds,
    required this.onChanged,
    required this.trans,
    this.showDecimal = false,
  });

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

    final selected =
        assets.where((v) => selectedIds.contains(v.asset.id)).toList();
    final hasSelection = selected.isNotEmpty;

    final String displayText;
    if (!hasSelection) {
      displayText = trans.goalSelectInvestments;
    } else if (selected.length == 1) {
      displayText = selected.first.asset.name;
    } else {
      displayText = '${selected.length} ${trans.goalInvestmentsSelected}';
    }

    final Color mutedColor =
        isLight ? const Color(0xFF94A3B8) : Colors.white54;
    final Color textColor = isLight ? AppColors.textPrimaryLight : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasSelection) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selected.map((view) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primaryGold.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(assetTypeIcon(view.asset.assetType),
                        color: AppColors.primaryGold, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      view.asset.name,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => onChanged(
                          Set<int>.from(selectedIds)..remove(view.asset.id)),
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        Icons.close,
                        color: isLight
                            ? const Color(0xFF64748B)
                            : Colors.white.withValues(alpha: 0.6),
                        size: 14,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
        GestureDetector(
          onTap: () => _showPicker(context),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            borderRadius: 12,
            child: Row(
              children: [
                Icon(
                  Icons.trending_up,
                  color: hasSelection ? AppColors.primaryGold : mutedColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      color: hasSelection ? textColor : mutedColor,
                      fontSize: 14,
                      fontWeight:
                          hasSelection ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasSelection) ...[
                  GestureDetector(
                    onTap: () => onChanged({}),
                    behavior: HitTestBehavior.opaque,
                    child: Icon(
                      Icons.close,
                      color: isLight
                          ? const Color(0xFF94A3B8)
                          : AppColors.textSecondary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(
                  Icons.expand_more,
                  color: isLight
                      ? AppColors.textSecondaryLight
                      : AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MultiInvestmentPickerSheet(
        assets: assets,
        selected: selectedIds,
        onChanged: onChanged,
        showDecimal: showDecimal,
        trans: trans,
      ),
    );
  }
}

class _MultiInvestmentPickerSheet extends StatefulWidget {
  final List<InvestmentAssetView> assets;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;
  final bool showDecimal;
  final AppTranslations trans;

  const _MultiInvestmentPickerSheet({
    required this.assets,
    required this.selected,
    required this.onChanged,
    required this.trans,
    this.showDecimal = false,
  });

  @override
  State<_MultiInvestmentPickerSheet> createState() =>
      _MultiInvestmentPickerSheetState();
}

class _MultiInvestmentPickerSheetState
    extends State<_MultiInvestmentPickerSheet> {
  late Set<int> _current;

  @override
  void initState() {
    super.initState();
    _current = Set.from(widget.selected);
  }

  void _toggle(int assetId) {
    setState(() {
      if (!_current.remove(assetId)) _current.add(assetId);
    });
    widget.onChanged(Set.from(_current));
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;

    final Color bgColor = isDefault
        ? const Color(0xFF1A1A2E)
        : isLight
            ? const Color(0xFFF8FAFC)
            : const Color(0xFF0A0A0A);
    final Color borderColor = isLight
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.1);
    final Color primaryColor =
        isLight ? AppColors.textPrimaryLight : AppColors.textPrimary;
    final Color secondaryColor =
        isLight ? AppColors.textSecondaryLight : AppColors.textSecondary;
    final Color checkboxBorderColor =
        isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.3);
    final trans = widget.trans;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    trans.goalSelectInvestments,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (_current.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() => _current.clear());
                      widget.onChanged({});
                    },
                    child: Text(
                      trans.goalClearAll,
                      style: const TextStyle(
                          color: AppColors.primaryGold, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: borderColor, height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: widget.assets.length,
              itemBuilder: (context, index) {
                final view = widget.assets[index];
                final asset = view.asset;
                final isSelected = _current.contains(asset.id);

                return InkWell(
                  onTap: () => _toggle(asset.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    color: isSelected
                        ? AppColors.primaryGold.withValues(alpha: 0.1)
                        : Colors.transparent,
                    child: Row(
                      children: [
                        Icon(
                          assetTypeIcon(asset.assetType),
                          color: isSelected
                              ? AppColors.primaryGold
                              : secondaryColor,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                asset.name,
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${asset.currency.code} ${Formatters.formatCurrency(view.latestValue, currency: asset.currency, showDecimal: widget.showDecimal)} Â· ${assetTypeLabel(trans, asset.assetType)}',
                                style: TextStyle(
                                  color: secondaryColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryGold
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryGold
                                  : checkboxBorderColor,
                              width: 1.5,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  color: Colors.black, size: 16)
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
