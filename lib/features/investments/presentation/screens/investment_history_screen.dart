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
import '../../../../shared/widgets/glass_card.dart';
import '../providers/investment_providers.dart';

/// Every update the user has confirmed, newest first, with the values they
/// entered on each date.
///
/// Each save adds its own record, so a day can hold several for one asset.
/// Deleting a whole session is offered here because it cannot be undone any
/// other way.
class InvestmentHistoryScreen extends ConsumerWidget {
  const InvestmentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trans = ref.watch(translationsProvider);
    final sessions = ref.watch(investmentSessionsProvider);
    final assets = ref.watch(allInvestmentAssetsProvider).valueOrNull ?? [];
    final locale = ref.watch(localeProvider).languageCode;
    final isLight = AppThemeProvider.isLightMode(context);

    final textColor = AppColors.adaptiveText(context);
    final mutedColor = isLight ? const Color(0xFF64748B) : Colors.white54;
    final assetById = {for (final a in assets) a.id: a};

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
              trans.investmentHistoryTitle,
              style: TextStyle(color: textColor),
            ),
          ),
          body: SafeArea(
            child: sessions.isEmpty
                ? Center(
                    child: Text(
                      trans.investmentHistoryEmpty,
                      style: TextStyle(color: mutedColor, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return _SessionCard(
                        session: session,
                        assetById: assetById,
                        locale: locale,
                        isLight: isLight,
                        textColor: textColor,
                        mutedColor: mutedColor,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _SessionCard extends ConsumerWidget {
  final InvestmentSession session;
  final Map<int, InvestmentAsset> assetById;
  final String locale;
  final bool isLight;
  final Color textColor;
  final Color mutedColor;

  const _SessionCard({
    required this.session,
    required this.assetById,
    required this.locale,
    required this.isLight,
    required this.textColor,
    required this.mutedColor,
  });

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final trans = ref.read(translationsProvider);
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
          trans.investmentDeleteSession,
          style: TextStyle(color: textColor, fontSize: 17),
        ),
        content: Text(
          trans.investmentDeleteSessionConfirm,
          style: TextStyle(color: mutedColor, fontSize: 13),
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

    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) return;
    await ref
        .read(investmentDaoProvider)
        .deleteSnapshotsOnDate(profileId, session.date);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trans = ref.watch(translationsProvider);
    final showDecimal = ref.watch(showDecimalProvider);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Theme(
        // ExpansionTile draws its own dividers and icon colours.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          iconColor: mutedColor,
          collapsedIconColor: mutedColor,
          title: Text(
            DateFormat.yMMMd(locale).format(session.date),
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            trans.investmentHistoryAssetCount(
                session.snapshots.map((s) => s.assetId).toSet().length),
            style: TextStyle(color: mutedColor, fontSize: 11),
          ),
          children: [
            for (final snapshot in session.snapshots)
              _SnapshotRow(
                snapshot: snapshot,
                asset: assetById[snapshot.assetId],
                showDecimal: showDecimal,
                textColor: textColor,
                mutedColor: mutedColor,
                contributionLabel: trans.investmentUpdateContributionLabel,
              ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _delete(context, ref),
                icon: Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: isLight ? AppColors.errorLight : AppColors.error,
                ),
                label: Text(
                  trans.investmentDeleteSession,
                  style: TextStyle(
                    color: isLight ? AppColors.errorLight : AppColors.error,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  final InvestmentSnapshot snapshot;
  final InvestmentAsset? asset;
  final bool showDecimal;
  final Color textColor;
  final Color mutedColor;
  final String contributionLabel;

  const _SnapshotRow({
    required this.snapshot,
    required this.asset,
    required this.showDecimal,
    required this.textColor,
    required this.mutedColor,
    required this.contributionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final currency = asset?.currency ?? Currency.idr;
    final contribution = snapshot.contribution;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset?.name ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textColor, fontSize: 13),
                ),
                if (contribution != 0)
                  Text(
                    '$contributionLabel: ${contribution > 0 ? '+' : '-'}${currency.symbol} ${Formatters.formatCurrency(contribution.abs(), currency: currency, showDecimal: showDecimal)}',
                    style: TextStyle(color: mutedColor, fontSize: 10),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${currency.symbol} ${Formatters.formatCurrency(snapshot.value, currency: currency, showDecimal: showDecimal)}',
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
