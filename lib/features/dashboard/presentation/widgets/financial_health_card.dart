import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';

import '../../../../shared/widgets/glass_card.dart';
import '../providers/dashboard_providers.dart';

class FinancialHealthCard extends ConsumerStatefulWidget {
  const FinancialHealthCard({super.key});

  @override
  ConsumerState<FinancialHealthCard> createState() =>
      _FinancialHealthCardState();
}

class _FinancialHealthCardState extends ConsumerState<FinancialHealthCard> {
  bool _expanded = false;

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'A':
        return AppColors.success;
      case 'B':
        return Colors.lightGreen;
      case 'C':
        return Colors.amber;
      case 'D':
        return Colors.orange;
      default:
        return AppColors.error;
    }
  }

  String _gradeLabel(String grade, dynamic trans) {
    switch (grade) {
      case 'A':
        return trans.healthScoreGradeA;
      case 'B':
        return trans.healthScoreGradeB;
      case 'C':
        return trans.healthScoreGradeC;
      case 'D':
        return trans.healthScoreGradeD;
      default:
        return trans.healthScoreGradeF;
    }
  }

  @override
  Widget build(BuildContext context) {
    final healthAsync = ref.watch(financialHealthScoreProvider);
    final trans = ref.watch(translationsProvider);
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

    final textColor =
        isLight ? AppColors.textPrimaryLight : Colors.white;
    final subtextColor = isLight
        ? const Color(0xFF64748B)
        : Colors.white.withValues(alpha: 0.55);

    return healthAsync.when(
      data: (health) {
        final gradeColor = _gradeColor(health.grade);
        final gradeLabel = _gradeLabel(health.grade, trans);
        final scoreInt = health.score.round();

        return GlassCard(
          onTap: () => setState(() => _expanded = !_expanded),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row: score + grade badge + label + expand hint ──
              Row(
                children: [
                  // Score number
                  Text(
                    '$scoreInt',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: gradeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 48,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Grade badge
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: gradeColor.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: gradeColor, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      health.grade,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: gradeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trans.healthScoreTitle,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          gradeLabel,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: gradeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: subtextColor,
                    size: 20,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Full-width progress bar ──
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (health.score / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: isLight
                      ? Colors.black.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(gradeColor),
                ),
              ),

              if (!_expanded)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    trans.healthScoreTapToExpand,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: subtextColor,
                    ),
                  ),
                ),

              // ── Animated expandable breakdown ──
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOut,
                child: _expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Column(
                          children: [
                            _ComponentRow(
                              icon: Icons.savings_outlined,
                              label: trans.healthScoreSavings,
                              score: health.savingsComponent,
                              isLight: isLight,
                            ),
                            const SizedBox(height: 10),
                            _ComponentRow(
                              icon: Icons.bar_chart,
                              label: trans.healthScoreBudget,
                              score: health.budgetComponent,
                              isLight: isLight,
                            ),
                            const SizedBox(height: 10),
                            _ComponentRow(
                              icon: Icons.credit_card_outlined,
                              label: trans.healthScoreDebt,
                              score: health.debtComponent,
                              isLight: isLight,
                            ),
                            const SizedBox(height: 10),
                            _ComponentRow(
                              icon: Icons.trending_up,
                              label: trans.healthScoreTrend,
                              score: health.trendComponent,
                              isLight: isLight,
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
      loading: () => GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryGold,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              trans.loading,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: subtextColor),
            ),
          ],
        ),
      ),
      error: (err, _) => const SizedBox.shrink(),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double score;
  final bool isLight;

  const _ComponentRow({
    required this.icon,
    required this.label,
    required this.score,
    required this.isLight,
  });

  Color _scoreColor(double s) {
    if (s >= 80) return AppColors.success;
    if (s >= 65) return Colors.lightGreen;
    if (s >= 50) return Colors.amber;
    if (s >= 35) return Colors.orange;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(score);
    final textColor = isLight ? AppColors.textPrimaryLight : Colors.white;
    final subtextColor = isLight
        ? const Color(0xFF64748B)
        : Colors.white.withValues(alpha: 0.55);

    return Row(
      children: [
        Icon(icon, size: 16, color: subtextColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (score / 100).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: isLight
                  ? Colors.black.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 28,
          child: Text(
            '${score.round()}',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
