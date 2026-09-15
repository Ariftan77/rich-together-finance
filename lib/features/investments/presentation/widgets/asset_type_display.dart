import 'package:flutter/material.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/models/enums.dart';

/// Localized label for an asset type. `AssetTypeX.displayName` in
/// `core/models/enums.dart` is English-only, so user-facing text comes from
/// here instead.
String assetTypeLabel(AppTranslations trans, AssetType type) {
  switch (type) {
    case AssetType.stock:
      return trans.investmentAssetTypeStock;
    case AssetType.crypto:
      return trans.investmentAssetTypeCrypto;
    case AssetType.gold:
      return trans.investmentAssetTypeGold;
    case AssetType.silver:
      return trans.investmentAssetTypeSilver;
    case AssetType.etf:
      return trans.investmentAssetTypeEtf;
    case AssetType.mutualFund:
      return trans.investmentAssetTypeMutualFund;
    case AssetType.property:
      return trans.investmentAssetTypeProperty;
    case AssetType.bond:
      return trans.investmentAssetTypeBond;
    case AssetType.other:
      return trans.investmentAssetTypeOther;
  }
}

IconData assetTypeIcon(AssetType type) {
  switch (type) {
    case AssetType.stock:
      return Icons.show_chart;
    case AssetType.crypto:
      return Icons.currency_bitcoin;
    case AssetType.gold:
      return Icons.workspaces;
    case AssetType.silver:
      return Icons.circle_outlined;
    case AssetType.etf:
      return Icons.stacked_line_chart;
    case AssetType.mutualFund:
      return Icons.pie_chart_outline;
    case AssetType.property:
      return Icons.home_work_outlined;
    case AssetType.bond:
      return Icons.account_balance_outlined;
    case AssetType.other:
      return Icons.savings_outlined;
  }
}
