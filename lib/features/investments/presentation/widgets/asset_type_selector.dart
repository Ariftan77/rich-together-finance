import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import 'asset_type_display.dart';

/// Asset type field that opens a bottom-sheet picker, styled like the category
/// field on the transaction entry screen.
class AssetTypeField extends ConsumerWidget {
  final AssetType value;
  final ValueChanged<AssetType> onChanged;

  const AssetTypeField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trans = ref.watch(translationsProvider);
    final isLight = AppThemeProvider.isLightMode(context);
    final goldColor =
        isLight ? AppColors.primaryGoldTextLight : AppColors.primaryGold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            trans.investmentAssetTypeLabel.toUpperCase(),
            style: TextStyle(
              color: isLight
                  ? const Color(0xFF64748B)
                  : Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
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
                child: _AssetTypeSheet(selected: value, onSelected: onChanged),
              ),
            );
          },
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: goldColor.withValues(alpha: isLight ? 0.12 : 0.15),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(assetTypeIcon(value), size: 16, color: goldColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    assetTypeLabel(trans, value),
                    style: TextStyle(
                      color: isLight ? AppColors.textPrimaryLight : Colors.white,
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(
                  Icons.expand_more,
                  color: isLight
                      ? const Color(0xFFCBD5E1)
                      : Colors.white.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AssetTypeSheet extends ConsumerWidget {
  final AssetType selected;
  final ValueChanged<AssetType> onSelected;

  const _AssetTypeSheet({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trans = ref.watch(translationsProvider);
    final themeMode = AppThemeProvider.of(context);
    final isLight = AppThemeProvider.isLightMode(context);
    final isDefault = themeMode == AppThemeMode.defaultTheme;
    final textColor = isLight ? AppColors.textPrimaryLight : Colors.white;
    final goldColor =
        isLight ? AppColors.primaryGoldTextLight : AppColors.primaryGold;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: isDefault
            ? const Color(0xFF1A1A2E)
            : isLight
                ? const Color(0xFFF8FAFC)
                : const Color(0xFF0A0A0A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    trans.investmentSelectAssetType,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isLight
                        ? const Color(0xFF64748B)
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              children: [
                for (final type in AssetType.values)
                  _buildItem(context, trans, type, isLight, textColor, goldColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    AppTranslations trans,
    AssetType type,
    bool isLight,
    Color textColor,
    Color goldColor,
  ) {
    final isSelected = type == selected;
    final itemColor = isSelected ? goldColor : textColor;

    return GestureDetector(
      onTap: () {
        onSelected(type);
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGold.withValues(alpha: 0.15)
              : isLight
                  ? Colors.black.withValues(alpha: 0.04)
                  : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryGold
                : isLight
                    ? Colors.black.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.15),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: goldColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(assetTypeIcon(type), size: 11, color: itemColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                assetTypeLabel(trans, type),
                style: TextStyle(
                  color: itemColor,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: goldColor,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}
