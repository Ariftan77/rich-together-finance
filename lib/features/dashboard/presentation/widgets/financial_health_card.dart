import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_translations.dart';
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

  void _showMethodologySheet(
    BuildContext context,
    FinancialHealthScore health,
    AppTranslations trans,
    bool isLight,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HealthMethodologySheet(
        health: health,
        trans: trans,
        isLight: isLight,
      ),
    );
  }

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
              // ── Header row: score + grade badge + label + info + expand ──
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
                  // Info button
                  GestureDetector(
                    onTap: () => _showMethodologySheet(context, health, trans, isLight),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.info_outline, color: subtextColor, size: 18),
                    ),
                  ),
                  const SizedBox(width: 4),
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

// ── Methodology Bottom Sheet ──────────────────────────────────────────────────

class _HealthMethodologySheet extends StatelessWidget {
  final FinancialHealthScore health;
  final AppTranslations trans;
  final bool isLight;

  const _HealthMethodologySheet({
    required this.health,
    required this.trans,
    required this.isLight,
  });

  Color _componentColor(double s) {
    if (s >= 80) return AppColors.success;
    if (s >= 65) return Colors.lightGreen;
    if (s >= 50) return Colors.amber;
    if (s >= 35) return Colors.orange;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isLight ? const Color(0xFFF8F9FA) : const Color(0xFF1A1A2E);
    final cardColor = isLight ? Colors.white : const Color(0xFF22223B);
    final textColor = isLight ? AppColors.textPrimaryLight : Colors.white;
    final subtextColor = isLight
        ? const Color(0xFF64748B)
        : Colors.white.withValues(alpha: 0.55);
    final dividerColor = isLight
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.08);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: subtextColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                trans.healthScoreMethodologyTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Divider(color: dividerColor, height: 1),
            // Scrollable content
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(16),
                children: [
                  // Overall formula card
                  _SectionCard(
                    color: cardColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(
                          icon: Icons.functions,
                          label: trans.healthScoreFormulaLabel,
                          textColor: textColor,
                          accentColor: AppColors.primaryGold,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          trans.healthScoreFormulaDesc,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: subtextColor,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Grade scale chips
                        Text(
                          trans.healthScoreGradeScaleLabel,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: subtextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _GradeScale(textColor: textColor),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Savings Rate
                  _ComponentCard(
                    color: cardColor,
                    icon: Icons.savings_outlined,
                    label: trans.healthScoreSavings,
                    weight: trans.healthScoreWeight,
                    currentScore: health.savingsComponent,
                    currentScoreLabel: trans.healthScoreCurrentScore,
                    scoreColor: _componentColor(health.savingsComponent),
                    textColor: textColor,
                    subtextColor: subtextColor,
                    dividerColor: dividerColor,
                    desc: trans.healthScoreSavingsDesc,
                    thresholdLabel: trans.healthScoreThresholdLabel,
                    thresholds: trans.healthScoreSavingsFormula,
                  ),
                  const SizedBox(height: 10),

                  // Budget Adherence
                  _ComponentCard(
                    color: cardColor,
                    icon: Icons.bar_chart,
                    label: trans.healthScoreBudget,
                    weight: trans.healthScoreWeight,
                    currentScore: health.budgetComponent,
                    currentScoreLabel: trans.healthScoreCurrentScore,
                    scoreColor: _componentColor(health.budgetComponent),
                    textColor: textColor,
                    subtextColor: subtextColor,
                    dividerColor: dividerColor,
                    desc: trans.healthScoreBudgetDesc,
                    thresholdLabel: trans.healthScoreThresholdLabel,
                    thresholds: trans.healthScoreBudgetNote,
                  ),
                  const SizedBox(height: 10),

                  // Debt Burden
                  _ComponentCard(
                    color: cardColor,
                    icon: Icons.credit_card_outlined,
                    label: trans.healthScoreDebt,
                    weight: trans.healthScoreWeight,
                    currentScore: health.debtComponent,
                    currentScoreLabel: trans.healthScoreCurrentScore,
                    scoreColor: _componentColor(health.debtComponent),
                    textColor: textColor,
                    subtextColor: subtextColor,
                    dividerColor: dividerColor,
                    desc: trans.healthScoreDebtDesc,
                    thresholdLabel: trans.healthScoreThresholdLabel,
                    thresholds: trans.healthScoreDebtFormula,
                  ),
                  const SizedBox(height: 10),

                  // Expense Trend
                  _ComponentCard(
                    color: cardColor,
                    icon: Icons.trending_up,
                    label: trans.healthScoreTrend,
                    weight: trans.healthScoreWeight,
                    currentScore: health.trendComponent,
                    currentScoreLabel: trans.healthScoreCurrentScore,
                    scoreColor: _componentColor(health.trendComponent),
                    textColor: textColor,
                    subtextColor: subtextColor,
                    dividerColor: dividerColor,
                    desc: trans.healthScoreTrendDesc,
                    thresholdLabel: trans.healthScoreThresholdLabel,
                    thresholds: trans.healthScoreTrendFormula,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Color color;
  final Widget child;

  const _SectionCard({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color textColor;
  final Color accentColor;

  const _SectionTitle({
    required this.icon,
    required this.label,
    required this.textColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: accentColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _GradeScale extends StatelessWidget {
  final Color textColor;

  const _GradeScale({required this.textColor});

  static const _grades = [
    ('A', '≥ 80', AppColors.success),
    ('B', '≥ 65', Colors.lightGreen),
    ('C', '≥ 50', Colors.amber),
    ('D', '≥ 35', Colors.orange),
    ('F', '< 35', AppColors.error),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _grades.map((g) {
        return Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: g.$3.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: g.$3, width: 1.2),
              ),
              alignment: Alignment.center,
              child: Text(
                g.$1,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: g.$3,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              g.$2,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: textColor,
                fontSize: 10,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _ComponentCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final String weight;
  final double currentScore;
  final String currentScoreLabel;
  final Color scoreColor;
  final Color textColor;
  final Color subtextColor;
  final Color dividerColor;
  final String desc;
  final String thresholdLabel;
  final String thresholds;

  const _ComponentCard({
    required this.color,
    required this.icon,
    required this.label,
    required this.weight,
    required this.currentScore,
    required this.currentScoreLabel,
    required this.scoreColor,
    required this.textColor,
    required this.subtextColor,
    required this.dividerColor,
    required this.desc,
    required this.thresholdLabel,
    required this.thresholds,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: icon + label + weight badge + score
          Row(
            children: [
              Icon(icon, size: 15, color: scoreColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Weight badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.primaryGold.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  weight,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.primaryGold,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Current score
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${currentScore.round()}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scoreColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    currentScoreLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: subtextColor,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Score bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (currentScore / 100).clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
            ),
          ),
          const SizedBox(height: 10),
          Divider(color: dividerColor, height: 1),
          const SizedBox(height: 10),
          // Description
          Text(
            desc,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: subtextColor,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          // Threshold label
          Text(
            thresholdLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: subtextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            thresholds,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: subtextColor,
              height: 1.7,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
