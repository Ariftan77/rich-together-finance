import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../core/providers/locale_provider.dart';
import '../providers/dashboard_providers.dart';

class MonthOverMonthCard extends ConsumerWidget {
  final String currencySymbol;
  final bool showDecimal;

  const MonthOverMonthCard({
    super.key,
    required this.currencySymbol,
    this.showDecimal = false,
  });

  // ---------------------------------------------------------------------------
  // Compact amount formatter
  // ---------------------------------------------------------------------------

  String _formatCompact(double value, {required String symbol, required bool showDecimal}) {
    final abs = value.abs();
    final String formatted;
    if (abs >= 1000000000) {
      formatted = '${(abs / 1e9).toStringAsFixed(1)}B';
    } else if (abs >= 1000000) {
      formatted = '${(abs / 1e6).toStringAsFixed(1)}M';
    } else if (abs >= 10000) {
      formatted = '${(abs / 1e3).toStringAsFixed(0)}K';
    } else {
      formatted = Formatters.formatCurrency(abs, showDecimal: showDecimal);
    }
    return '$symbol$formatted';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final trans = ref.watch(translationsProvider);
    final momAsync = ref.watch(monthOverMonthProvider);

    return momAsync.when(
      loading: () => GlassCard(
        child: SizedBox(
          height: 160,
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primaryGold),
          ),
        ),
      ),
      error: (err, _) => GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${trans.error}: $err',
            style: TextStyle(
              color: isLight ? AppColors.errorLight : AppColors.error,
              fontSize: 13,
            ),
          ),
        ),
      ),
      data: (data) => _buildContent(context, isLight, trans, data),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isLight,
    dynamic trans,
    MonthComparison data,
  ) {
    // Muted label color — matches the rest of the codebase
    final mutedColor = isLight
        ? const Color(0xFF64748B)
        : Colors.white.withValues(alpha: 0.6);

    // Primary text color
    final primaryColor = isLight ? AppColors.textPrimaryLight : Colors.white;

    // Column header color — slightly more muted than primary
    final headerColor = isLight
        ? const Color(0xFF94A3B8)
        : Colors.white.withValues(alpha: 0.5);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Text(
            trans.monthOverMonthTitle,
            style: TextStyle(
              color: primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),

          // Column headers
          _HeaderRow(
            thisMonthLabel: trans.monthOverMonthThisMonth,
            lastMonthLabel: trans.monthOverMonthLastMonth,
            lastYearLabel: trans.monthOverMonthLastYear,
            color: headerColor,
          ),
          const SizedBox(height: 8),

          // Income row
          _DataRow(
            label: trans.entryTypeIncome,
            thisMonthValue: _formatCompact(
              data.thisMonthIncome,
              symbol: currencySymbol,
              showDecimal: showDecimal,
            ),
            lastMonthValue: _formatCompact(
              data.lastMonthIncome,
              symbol: currencySymbol,
              showDecimal: showDecimal,
            ),
            lastYearValue: _formatCompact(
              data.lastYearIncome,
              symbol: currencySymbol,
              showDecimal: showDecimal,
            ),
            labelColor: mutedColor,
            valueColor: primaryColor,
          ),

          _Divider(isLight: isLight),

          // Expense row
          _DataRow(
            label: trans.entryTypeExpense,
            thisMonthValue: _formatCompact(
              data.thisMonthExpense,
              symbol: currencySymbol,
              showDecimal: showDecimal,
            ),
            lastMonthValue: _formatCompact(
              data.lastMonthExpense,
              symbol: currencySymbol,
              showDecimal: showDecimal,
            ),
            lastYearValue: _formatCompact(
              data.lastYearExpense,
              symbol: currencySymbol,
              showDecimal: showDecimal,
            ),
            labelColor: mutedColor,
            valueColor: primaryColor,
          ),

          _Divider(isLight: isLight),

          // Net row — color depends on sign
          _NetRow(
            label: trans.reportNet,
            thisMonthNet: data.thisMonthNet,
            lastMonthNet: data.lastMonthNet,
            lastYearNet: data.lastYearNet,
            currencySymbol: currencySymbol,
            showDecimal: showDecimal,
            labelColor: mutedColor,
            formatCompact: _formatCompact,
            isLight: isLight,
          ),

          // Delta badges — only render if at least one delta is available
          if (data.expenseDeltaVsLastMonth != null ||
              data.expenseDeltaVsLastYear != null) ...[
            const SizedBox(height: 12),
            _DeltaBadgeRow(
              deltaVsLastMonth: data.expenseDeltaVsLastMonth,
              deltaVsLastYear: data.expenseDeltaVsLastYear,
              isLight: isLight,
              trans: trans,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

/// Three evenly-spaced column header labels (right-aligned inside each cell).
class _HeaderRow extends StatelessWidget {
  final String thisMonthLabel;
  final String lastMonthLabel;
  final String lastYearLabel;
  final Color color;

  const _HeaderRow({
    required this.thisMonthLabel,
    required this.lastMonthLabel,
    required this.lastYearLabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Spacer matching the row-label width
        const SizedBox(width: 64),
        Expanded(
          child: Text(
            thisMonthLabel,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        Expanded(
          child: Text(
            lastMonthLabel,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        Expanded(
          child: Text(
            lastYearLabel,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// A single data row with a row label and three value columns.
class _DataRow extends StatelessWidget {
  final String label;
  final String thisMonthValue;
  final String lastMonthValue;
  final String lastYearValue;
  final Color labelColor;
  final Color valueColor;

  const _DataRow({
    required this.label,
    required this.thisMonthValue,
    required this.lastMonthValue,
    required this.lastYearValue,
    required this.labelColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: labelColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              thisMonthValue,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              lastMonthValue,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              lastYearValue,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Net row — each value is coloured green/red based on its sign.
class _NetRow extends StatelessWidget {
  final String label;
  final double thisMonthNet;
  final double lastMonthNet;
  final double lastYearNet;
  final String currencySymbol;
  final bool showDecimal;
  final Color labelColor;
  final bool isLight;
  final String Function(double, {required String symbol, required bool showDecimal}) formatCompact;

  const _NetRow({
    required this.label,
    required this.thisMonthNet,
    required this.lastMonthNet,
    required this.lastYearNet,
    required this.currencySymbol,
    required this.showDecimal,
    required this.labelColor,
    required this.isLight,
    required this.formatCompact,
  });

  Color _netColor(double value) {
    if (value >= 0) {
      return isLight ? AppColors.successLight : AppColors.success;
    }
    return isLight ? AppColors.errorLight : AppColors.error;
  }

  String _netText(double value) {
    final prefix = value >= 0 ? '+' : '-';
    return '$prefix${formatCompact(value.abs(), symbol: currencySymbol, showDecimal: showDecimal)}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: labelColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              _netText(thisMonthNet),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _netColor(thisMonthNet),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              _netText(lastMonthNet),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _netColor(lastMonthNet),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              _netText(lastYearNet),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _netColor(lastYearNet),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A thin horizontal divider between table rows.
class _Divider extends StatelessWidget {
  final bool isLight;

  const _Divider({required this.isLight});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isLight
          ? Colors.black.withValues(alpha: 0.06)
          : Colors.white.withValues(alpha: 0.08),
    );
  }
}

/// Row of delta badges at the bottom of the card — expense deltas only.
class _DeltaBadgeRow extends StatelessWidget {
  final double? deltaVsLastMonth;
  final double? deltaVsLastYear;
  final bool isLight;
  final dynamic trans;

  const _DeltaBadgeRow({
    required this.deltaVsLastMonth,
    required this.deltaVsLastYear,
    required this.isLight,
    required this.trans,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (deltaVsLastMonth != null)
          _DeltaBadge(
            delta: deltaVsLastMonth!,
            label: trans.monthOverMonthLastMonth,
            isLight: isLight,
          ),
        if (deltaVsLastYear != null)
          _DeltaBadge(
            delta: deltaVsLastYear!,
            label: trans.monthOverMonthLastYear,
            isLight: isLight,
          ),
      ],
    );
  }
}

/// A single pill-shaped delta badge.
///
/// For expenses: negative delta = good (spent less) → green;
/// positive delta = bad (spent more) → red.
class _DeltaBadge extends StatelessWidget {
  final double delta;
  final String label;
  final bool isLight;

  const _DeltaBadge({
    required this.delta,
    required this.label,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    final isGood = delta <= 0; // spending less is better
    final baseColor = isGood
        ? (isLight ? AppColors.successLight : AppColors.success)
        : (isLight ? AppColors.errorLight : AppColors.error);
    final bgColor = baseColor.withValues(alpha: 0.12);
    final borderColor = baseColor.withValues(alpha: 0.30);

    final arrowIcon = isGood ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
    final percentText = '${delta.abs().toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(arrowIcon, size: 11, color: baseColor),
          const SizedBox(width: 3),
          Text(
            '$percentText vs $label',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: baseColor,
            ),
          ),
        ],
      ),
    );
  }
}
