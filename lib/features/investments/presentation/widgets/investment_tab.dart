import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../providers/investment_providers.dart';
import '../screens/investment_asset_detail_screen.dart';
import '../screens/investment_history_screen.dart';
import 'investment_asset_card.dart';
import 'investment_summary_header.dart';
import 'investment_chart_section.dart';
import 'investment_update_sheet.dart';

/// Body of the Investment tab in WealthScreen.
class InvestmentTab extends ConsumerWidget {
  const InvestmentTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trans = ref.watch(translationsProvider);
    final summary = ref.watch(investmentSummaryProvider);
    final isLight = AppThemeProvider.isLightMode(context);

    final textColor = AppColors.adaptiveText(context);
    final mutedColor = isLight ? const Color(0xFF64748B) : Colors.white54;

    if (summary.isEmpty) {
      return _EmptyState(
        title: trans.investmentEmptyTitle,
        hint: trans.investmentEmptyHint,
        isLight: isLight,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        InvestmentSummaryHeader(summary: summary),
        const SizedBox(height: 16),

        InvestmentChartSection(summary: summary),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: Text(
                trans.investmentAssetsSection,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Tight padding so both buttons fit on a 360dp phone with the
            // longer Indonesian labels.
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InvestmentHistoryScreen(),
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: Icon(Icons.history, size: 18, color: mutedColor),
              label: Text(
                trans.investmentHistoryTitle,
                style: TextStyle(color: mutedColor, fontSize: 13),
              ),
            ),
            if (summary.assets.isNotEmpty)
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () async {
                  await showInvestmentUpdateSheet(
                    context,
                    views: summary.assets,
                  );
                },
                icon: const Icon(Icons.edit_note,
                    size: 18, color: AppColors.primaryGold),
                label: Text(
                  trans.investmentUpdateValues,
                  style: const TextStyle(
                    color: AppColors.primaryGold,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        for (final view in summary.assets)
          InvestmentAssetCard(
            view: view,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    InvestmentAssetDetailScreen(assetId: view.asset.id),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String hint;
  final bool isLight;

  const _EmptyState({
    required this.title,
    required this.hint,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor =
        isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.5);
    final hintColor =
        isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.3);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 80, color: hintColor),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: titleColor),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: hintColor),
            ),
          ],
        ),
      ),
    );
  }
}
