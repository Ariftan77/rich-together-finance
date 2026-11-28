import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../domain/home_widget_models.dart';
import '../../services/home_widget_service.dart';
import '../providers/home_widget_providers.dart';

/// Bottom sheet allowing users to preview all 3 Home Screen Widgets,
/// toggle widget amount masking, pin widgets directly on Android 8+,
/// and force-sync widget data.
Future<void> showHomeWidgetsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const HomeWidgetsSheet(),
  );
}

class HomeWidgetsSheet extends ConsumerStatefulWidget {
  const HomeWidgetsSheet({super.key});

  @override
  ConsumerState<HomeWidgetsSheet> createState() => _HomeWidgetsSheetState();
}

class _HomeWidgetsSheetState extends ConsumerState<HomeWidgetsSheet> {
  bool _pinSupported = false;

  @override
  void initState() {
    super.initState();
    ref.read(widgetAmountsMaskedProvider.notifier).reload();
    _checkPinSupport();
  }

  Future<void> _checkPinSupport() async {
    final supported = await HomeWidgetService.isPinSupported();
    if (mounted) {
      setState(() => _pinSupported = supported);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trans = ref.watch(translationsProvider);
    final snapshot = ref.watch(homeWidgetSnapshotProvider);
    final isMasked = ref.watch(widgetAmountsMaskedProvider);
    final isLight = AppThemeProvider.isLightMode(context);

    final bgColor = AppColors.themed3(
      context,
      defaultTheme: AppColors.surface,
      dark: AppColors.surfaceDark,
      light: AppColors.surfaceLight,
    );
    final primaryText = AppColors.adaptiveText(context);
    final secondaryText = AppColors.adaptiveText(
      context,
      darkText: AppColors.textSecondary,
      lightText: AppColors.textSecondaryLight,
    );
    final accentGold =
        isLight ? AppColors.primaryGoldTextLight : AppColors.primaryGold;
    final successColor = isLight ? AppColors.successLight : AppColors.success;
    final errorColor = isLight ? AppColors.errorLight : AppColors.error;
    final warningColor = isLight ? AppColors.warningLight : AppColors.warning;

    String maskOr(String value) =>
        isMasked ? (snapshot?.maskedPlaceholder ?? '••••••') : value;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.55,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isLight ? AppColors.glassBorderLight : AppColors.glassBorder,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: secondaryText.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Icon(Icons.widgets_outlined, color: accentGold, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        trans.settingsHomeWidgets,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: primaryText,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: secondaryText),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  children: [
                    // Instructions banner
                    GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: accentGold, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              !kIsWeb && Platform.isIOS
                                  ? trans.widgetHowToAddIos
                                  : trans.widgetHowToAddAndroid,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: secondaryText, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Privacy toggle card
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isMasked
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: accentGold,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trans.widgetHideAmounts,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: primaryText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  trans.widgetHideAmountsSubtitle,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: secondaryText),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: isMasked,
                            activeTrackColor: accentGold,
                            onChanged: (val) {
                              ref
                                  .read(widgetAmountsMaskedProvider.notifier)
                                  .setMasked(val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Widget 1: Quick Actions ──────────────────────────────
                    _buildWidgetHeader(
                      context,
                      number: '1',
                      title: trans.widgetQuickAddTitle,
                      subtitle: trans.widgetQuickAddDesc,
                      accentColor: accentGold,
                      primaryText: primaryText,
                      secondaryText: secondaryText,
                      kind: HomeWidgetKind.quickActions,
                      pinLabel: trans.widgetPinButton,
                    ),
                    const SizedBox(height: 10),
                    GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          _buildActionPill(
                            context,
                            icon: Icons.remove_circle_outline,
                            label: trans.widgetLblExpenseShort,
                            color: errorColor,
                            primaryText: primaryText,
                          ),
                          const SizedBox(width: 8),
                          _buildActionPill(
                            context,
                            icon: Icons.add_circle_outline,
                            label: trans.widgetLblIncomeShort,
                            color: successColor,
                            primaryText: primaryText,
                          ),
                          const SizedBox(width: 8),
                          _buildActionPill(
                            context,
                            icon: Icons.swap_horiz_rounded,
                            label: trans.widgetLblTransferShort,
                            color: accentGold,
                            primaryText: primaryText,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ── Widget 2: Safe-to-Spend Budget Pulse ─────────────────
                    _buildWidgetHeader(
                      context,
                      number: '2',
                      title: trans.widgetBudgetPulseTitle,
                      subtitle: trans.widgetBudgetPulseDesc,
                      accentColor: accentGold,
                      primaryText: primaryText,
                      secondaryText: secondaryText,
                      kind: HomeWidgetKind.budgetPulse,
                      pinLabel: trans.widgetPinButton,
                    ),
                    const SizedBox(height: 10),
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                snapshot?.hasBudget == true
                                    ? (snapshot!.budgetStatus == 'over'
                                        ? trans.widgetLblOverBudget
                                        : trans.widgetLblSafePerDay)
                                    : trans.widgetBudgetPulseTitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(color: secondaryText),
                              ),
                              const Spacer(),
                              if (snapshot?.hasBudget == true)
                                Text(
                                  snapshot!.lblDaysLeft,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: accentGold),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            snapshot?.hasBudget == true
                                ? maskOr(
                                    snapshot!.budgetStatus == 'over'
                                        ? snapshot.budgetRemainingFmt
                                        : snapshot.safePerDayFmt,
                                  )
                                : trans.widgetLblNoBudget,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: snapshot?.budgetStatus == 'over'
                                      ? errorColor
                                      : primaryText,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (snapshot?.budgetProgressPct ?? 0) / 100.0,
                              minHeight: 6,
                              backgroundColor:
                                  secondaryText.withValues(alpha: 0.18),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                snapshot?.budgetStatus == 'over'
                                    ? errorColor
                                    : snapshot?.budgetStatus == 'warning'
                                        ? warningColor
                                        : successColor,
                              ),
                            ),
                          ),
                          if (snapshot?.hasBudget == true) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${trans.widgetLblBudgetLeft}: ${maskOr(snapshot!.budgetRemainingFmt)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: secondaryText),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ── Widget 3: Cash Flow Snapshot ─────────────────────────
                    _buildWidgetHeader(
                      context,
                      number: '3',
                      title: trans.widgetCashFlowTitle,
                      subtitle: trans.widgetCashFlowDesc,
                      accentColor: accentGold,
                      primaryText: primaryText,
                      secondaryText: secondaryText,
                      kind: HomeWidgetKind.cashFlow,
                      pinLabel: trans.widgetPinButton,
                    ),
                    const SizedBox(height: 10),
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                snapshot?.profileName ?? 'Richer',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: accentGold,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const Spacer(),
                              Icon(
                                isMasked
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 16,
                                color: secondaryText,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            trans.widgetLblTodaySpend,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: secondaryText),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            maskOr(snapshot?.todayExpenseFmt ?? '0'),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: primaryText,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildFlowMiniStat(
                                  context,
                                  label: trans.widgetLblMonthIn,
                                  value:
                                      maskOr(snapshot?.monthIncomeFmt ?? '0'),
                                  valueColor: successColor,
                                  secondaryText: secondaryText,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildFlowMiniStat(
                                  context,
                                  label: trans.widgetLblMonthOut,
                                  value:
                                      maskOr(snapshot?.monthExpenseFmt ?? '0'),
                                  valueColor: errorColor,
                                  secondaryText: secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    GlassButton(
                      text: trans.widgetRefreshNow,
                      icon: Icons.sync_rounded,
                      isFullWidth: true,
                      onPressed: () async {
                        final latest = ref.read(homeWidgetSnapshotProvider);
                        if (latest != null) {
                          await HomeWidgetService.pushSnapshot(latest);
                        } else {
                          await HomeWidgetService.refreshAllWidgets();
                        }
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(trans.widgetRefreshedToast)),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWidgetHeader(
    BuildContext context, {
    required String number,
    required String title,
    required String subtitle,
    required Color accentColor,
    required Color primaryText,
    required Color secondaryText,
    required HomeWidgetKind kind,
    required String pinLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Text(
                number,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: primaryText,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            if (_pinSupported)
              TextButton.icon(
                onPressed: () => HomeWidgetService.requestPinWidget(kind),
                icon: Icon(Icons.add_to_home_screen, size: 16, color: accentColor),
                label: Text(
                  pinLabel,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: secondaryText),
        ),
      ],
    );
  }

  Widget _buildActionPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required Color primaryText,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: primaryText,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowMiniStat(
    BuildContext context, {
    required String label,
    required String value,
    required Color valueColor,
    required Color secondaryText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: valueColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: secondaryText),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
