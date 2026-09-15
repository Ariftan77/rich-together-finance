import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../domain/investment_math.dart';
import '../providers/investment_providers.dart';
import '../widgets/asset_type_display.dart';
import '../widgets/investment_chart_section.dart';
import '../widgets/investment_sell_dialog.dart';
import '../widgets/investment_summary_header.dart';
import '../widgets/investment_update_sheet.dart';
import 'investment_asset_entry_screen.dart';

/// Opens the asset behind an investmentOut / investmentIn wallet transaction.
///
/// Those transactions are owned by their snapshot, so they are never edited in
/// the transaction editor — changes go through the investment instead.
Future<void> openInvestmentTransaction(
  BuildContext context,
  int transactionId,
) async {
  final navigator = Navigator.of(context);
  final snapshot = await ProviderScope.containerOf(context, listen: false)
      .read(investmentDaoProvider)
      .getSnapshotByTransactionId(transactionId);
  if (snapshot == null) return;
  navigator.push(
    MaterialPageRoute(
      builder: (_) => InvestmentAssetDetailScreen(assetId: snapshot.assetId),
    ),
  );
}

/// One asset: its current value and gain, its own value chart, and every value
/// the user has recorded for it.
class InvestmentAssetDetailScreen extends ConsumerWidget {
  final int assetId;

  const InvestmentAssetDetailScreen({super.key, required this.assetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trans = ref.watch(translationsProvider);
    final isLight = AppThemeProvider.isLightMode(context);
    final textColor = AppColors.adaptiveText(context);
    final mutedColor = isLight ? const Color(0xFF64748B) : Colors.white54;

    final asset = (ref.watch(allInvestmentAssetsProvider).valueOrNull ?? [])
        .where((a) => a.id == assetId)
        .firstOrNull;
    final summary = ref.watch(investmentAssetSummaryProvider(assetId));
    final view = summary.assets.firstOrNull;
    // Newest first, for the history list.
    final snapshots = (ref.watch(investmentSnapshotsProvider).valueOrNull ?? [])
        .where((s) => s.assetId == assetId)
        .toList()
      ..sort((a, b) {
        final byDate = b.snapshotDate.compareTo(a.snapshotDate);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });

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
              asset?.name ?? '',
              style: TextStyle(color: textColor),
            ),
            actions: [
              if (asset != null)
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: textColor),
                  tooltip: trans.investmentEditAssetTitle,
                  onPressed: () async {
                    final gone = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InvestmentAssetEntryScreen(asset: asset),
                      ),
                    );
                    // Sold or deleted: nothing left to show here.
                    if (gone == true && context.mounted) Navigator.pop(context);
                  },
                ),
            ],
          ),
          body: SafeArea(
            child: asset == null
                ? const SizedBox.shrink()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      Text(
                        '${assetTypeLabel(trans, asset.assetType)} · ${asset.currency.code}',
                        style: TextStyle(color: mutedColor, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      InvestmentSummaryHeader(
                        summary: summary,
                        title: trans.investmentCurrentValueLabel,
                      ),
                      const SizedBox(height: 16),
                      InvestmentChartSection(
                        summary: summary,
                        title: trans.investmentAssetChartTitle,
                      ),
                      if (view != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: GlassButton(
                                text: trans.investmentUpdateValue,
                                icon: Icons.edit_note,
                                onPressed: () => showInvestmentUpdateSheet(
                                    context,
                                    views: [view]),
                                isPrimary: true,
                                isFullWidth: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GlassButton(
                                text: trans.investmentSellOrWithdraw,
                                icon: Icons.sell_outlined,
                                onPressed: () =>
                                    _sellOrWithdraw(context, ref, view),
                                isFullWidth: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      Text(
                        trans.investmentHistoryTitle,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (snapshots.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              trans.investmentHistoryEmpty,
                              style: TextStyle(color: mutedColor, fontSize: 14),
                            ),
                          ),
                        )
                      else
                        for (var i = 0; i < snapshots.length; i++)
                          _SnapshotTile(
                            asset: asset,
                            snapshot: snapshots[i],
                            previous: i + 1 < snapshots.length
                                ? snapshots[i + 1]
                                : null,
                          ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// Lets the user pick between selling everything and taking part out.
Future<void> _sellOrWithdraw(
  BuildContext context,
  WidgetRef ref,
  InvestmentAssetView view,
) async {
  final trans = ref.read(translationsProvider);
  final isLight = AppThemeProvider.isLightMode(context);
  final textColor = AppColors.adaptiveText(context);
  final mutedColor = isLight ? const Color(0xFF64748B) : Colors.white60;
  final goldColor =
      isLight ? AppColors.primaryGoldTextLight : AppColors.primaryGold;

  Widget option(IconData icon, String title, String hint, bool sellAll) {
    return ListTile(
      leading: Icon(icon, color: goldColor),
      title: Text(title, style: TextStyle(color: textColor, fontSize: 15)),
      subtitle: Text(hint, style: TextStyle(color: mutedColor, fontSize: 12)),
      onTap: () => Navigator.pop(context, sellAll),
    );
  }

  final sellAll = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.themed3<Color>(
      context,
      defaultTheme: const Color(0xFF221D10),
      dark: const Color(0xFF141414),
      light: Colors.white,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            option(Icons.remove_circle_outline, trans.investmentWithdrawPart,
                trans.investmentWithdrawPartHint, false),
            option(Icons.sell_outlined, trans.investmentSellAll,
                trans.investmentSellAllHint, true),
          ],
        ),
      ),
    ),
  );
  if (sellAll == null || !context.mounted) return;

  if (!sellAll) {
    await showInvestmentUpdateSheet(context, views: [view], withdraw: true);
    return;
  }

  final sold = await showInvestmentSellDialog(
    context,
    asset: view.asset,
    currentValue: view.latestValue,
  );
  if (sold == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(trans.investmentSellDone)),
    );
    // Archived: nothing left to show on this screen.
    Navigator.pop(context);
  }
}

/// One recorded value, with its change from the previous record in the
/// asset's own currency — net of money added, so a top-up is not a gain.
class _SnapshotTile extends ConsumerWidget {
  final InvestmentAsset asset;
  final InvestmentSnapshot snapshot;
  final InvestmentSnapshot? previous;

  const _SnapshotTile({
    required this.asset,
    required this.snapshot,
    required this.previous,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trans = ref.watch(translationsProvider);
    final showDecimal = ref.watch(showDecimalProvider);
    final locale = ref.watch(localeProvider).languageCode;
    final isLight = AppThemeProvider.isLightMode(context);
    final textColor = AppColors.adaptiveText(context);
    final mutedColor = isLight ? const Color(0xFF64748B) : Colors.white54;

    final currency = asset.currency;
    String signed(double amount) =>
        '${amount > 0 ? '+' : amount < 0 ? '-' : ''}${currency.symbol} ${Formatters.formatCurrency(amount.abs(), currency: currency, showDecimal: showDecimal)}';

    final contribution = snapshot.contribution;
    final change = previous == null
        ? null
        : snapshot.value - previous!.value - contribution;
    final changeColor = change == null || change == 0
        ? mutedColor
        : change > 0
            ? (isLight ? AppColors.successLight : AppColors.success)
            : (isLight ? AppColors.errorLight : AppColors.error);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat.yMMMd(locale).format(snapshot.snapshotDate),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (contribution != 0)
                  Text(
                    '${trans.investmentUpdateContributionLabel}: ${signed(contribution)}',
                    style: TextStyle(color: mutedColor, fontSize: 11),
                  ),
                if (snapshot.note != null && snapshot.note!.isNotEmpty)
                  Text(
                    snapshot.note!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: mutedColor, fontSize: 11),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${currency.symbol} ${Formatters.formatCurrency(snapshot.value, currency: currency, showDecimal: showDecimal)}',
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (change != null)
                Text(
                  signed(change),
                  style: TextStyle(
                    color: changeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
