import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../features/dashboard/presentation/providers/dashboard_providers.dart';
import '../../../shared/theme/colors.dart';
import '../logic/achievement_qualifier.dart';

// ---------------------------------------------------------------------------
// Caption helper
// ---------------------------------------------------------------------------

String _buildCaption(
  AchievementType type,
  AppTranslations trans,
  String monthYear,
) {
  final base = switch (type) {
    AchievementType.savingsStreak => trans.shareCaption_savingsStreak,
    AchievementType.financeChampion => trans.shareCaption_financeChampion,
    AchievementType.budgetChampion => trans.shareCaption_budgetChampion,
    AchievementType.budgetDisciplined => trans.shareCaption_budgetDisciplined,
    AchievementType.gradeA => trans.shareCaption_gradeA,
    AchievementType.gradeB => trans.shareCaption_gradeB,
    AchievementType.spendingUnderControl => trans.shareCaption_spendingUnderControl,
  };
  return '$base\n\n— $monthYear';
}

// ---------------------------------------------------------------------------
// Public API: renders and shares the top achievement card.
// ---------------------------------------------------------------------------

/// Renders the share card offscreen, captures it as PNG, and triggers share.
/// Call this when the user taps the share button.
Future<void> shareAchievement({
  required BuildContext context,
  required WidgetRef ref,
  required AchievementResult achievement,
  required List<SavingsRatePoint> savingsPoints,
  required List<BudgetPerfMonth> budgetPerf,
  required FinancialHealthScore health,
}) async {
  final trans = ref.read(translationsProvider);
  final now = DateTime.now();
  final monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  final monthYear = '${monthNames[now.month - 1]} ${now.year}';
  final caption = _buildCaption(achievement.type, trans, monthYear);

  // Build the card widget tree and capture it.
  final key = GlobalKey();
  final accentColor = Theme.of(context).colorScheme.primary;

  // Render using an overlay entry placed far off-screen so the widget is
  // laid out and painted (Offstage suppresses painting, breaking toImage()).
  final overlayEntry = OverlayEntry(
    builder: (_) => Positioned(
      left: -10000,
      top: -10000,
      child: RepaintBoundary(
        key: key,
        child: _ShareCard(
          achievement: achievement,
          savingsPoints: savingsPoints,
          budgetPerf: budgetPerf,
          health: health,
          accentColor: accentColor,
          monthYear: monthYear,
        ),
      ),
    ),
  );

  final overlay = Overlay.of(context);
  overlay.insert(overlayEntry);

  // Allow enough time for the widget to fully paint before capture.
  await Future.delayed(const Duration(milliseconds: 200));

  try {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    final Uint8List pngBytes = byteData.buffer.asUint8List();
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/richer_achievement.png');
    await file.writeAsBytes(pngBytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: caption,
    );
  } finally {
    overlayEntry.remove();
  }
}

// ---------------------------------------------------------------------------
// Card widget (375 × 520, solid background — no blur)
// ---------------------------------------------------------------------------

class _ShareCard extends StatelessWidget {
  final AchievementResult achievement;
  final List<SavingsRatePoint> savingsPoints;
  final List<BudgetPerfMonth> budgetPerf;
  final FinancialHealthScore health;
  final Color accentColor;
  final String monthYear;

  const _ShareCard({
    required this.achievement,
    required this.savingsPoints,
    required this.budgetPerf,
    required this.health,
    required this.accentColor,
    required this.monthYear,
  });

  static const double _cardWidth = 375;
  static const double _cardHeight = 520;

  String get _achievementName {
    return switch (achievement.type) {
      AchievementType.financeChampion => 'Finance Champion',
      AchievementType.savingsStreak => 'Savings Streak',
      AchievementType.gradeA => 'Financial Grade A',
      AchievementType.gradeB => 'Financial Grade B',
      AchievementType.budgetChampion => 'Budget Champion',
      AchievementType.budgetDisciplined => 'Budget Disciplined',
      AchievementType.spendingUnderControl => 'Spending Under Control',
    };
  }

  IconData get _badgeIcon {
    return switch (achievement.type) {
      AchievementType.financeChampion => Icons.emoji_events,
      AchievementType.savingsStreak => Icons.local_fire_department,
      AchievementType.gradeA => Icons.workspace_premium,
      AchievementType.gradeB => Icons.grade,
      AchievementType.budgetChampion => Icons.shield,
      AchievementType.budgetDisciplined => Icons.shield_outlined,
      AchievementType.spendingUnderControl => Icons.trending_down,
    };
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0F172A); // dark navy, same as app bgDarkStart

    return SizedBox(
      width: _cardWidth,
      height: _cardHeight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: _cardWidth,
          height: _cardHeight,
          decoration: const BoxDecoration(color: bgColor),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              // Accent divider
              Container(height: 2, color: accentColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildBadge(),
                      const SizedBox(height: 16),
                      _buildAchievementName(),
                      const SizedBox(height: 8),
                      _buildHeroNumber(),
                      const SizedBox(height: 4),
                      _buildHeroLabel(),
                      const SizedBox(height: 20),
                      _buildVisualization(),
                      const Spacer(),
                      _buildFooter(),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              // 8px brand gradient strip at bottom
              Container(
                height: 8,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2C5282), Color(0xFF8E792A)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              'assets/images/app_icon.png',
              width: 28,
              height: 28,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Richer',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const Text(
                'Personal Finance',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accentColor.withValues(alpha: 0.15),
        border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Icon(_badgeIcon, color: accentColor, size: 40),
    );
  }

  Widget _buildAchievementName() {
    return Text(
      _achievementName,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildHeroNumber() {
    return Text(
      achievement.heroNumber,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: accentColor,
        fontSize: 48,
        fontWeight: FontWeight.w900,
        letterSpacing: -1,
        height: 1.0,
      ),
    );
  }

  Widget _buildHeroLabel() {
    return Text(
      achievement.heroLabel,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 13,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildVisualization() {
    return SizedBox(
      height: 80,
      child: switch (achievement.type) {
        AchievementType.financeChampion ||
        AchievementType.savingsStreak =>
          _SavingsBarChart(
            points: savingsPoints,
            accentColor: accentColor,
          ),
        AchievementType.spendingUnderControl =>
          _SpendingBarChart(
            points: savingsPoints,
            accentColor: accentColor,
          ),
        AchievementType.budgetChampion ||
        AchievementType.budgetDisciplined =>
          _BudgetDotRow(budgetPerf: budgetPerf),
        AchievementType.gradeA ||
        AchievementType.gradeB =>
          _HealthComponentBars(
            health: health,
            accentColor: accentColor,
            budgetPerf: budgetPerf,
            savingsPoints: savingsPoints,
          ),
      },
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Track your financial journey',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              monthYear,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
            const Text(
              '#Richer',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Visualization widgets
// ---------------------------------------------------------------------------

/// Savings bar chart: positive bars green, negative bars red.
class _SavingsBarChart extends StatelessWidget {
  final List<SavingsRatePoint> points;
  final Color accentColor;

  const _SavingsBarChart({required this.points, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    // Use first 5 entries (completed months, indices 0–4).
    final data = points.length > 5 ? points.sublist(0, 5) : points;
    if (data.isEmpty) return const SizedBox.shrink();

    final maxAbs = data.map((p) => p.rate.abs()).fold(1.0, (a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: data.map((p) {
        final normalized = (p.rate.abs() / maxAbs).clamp(0.05, 1.0);
        final barHeight = 52 * normalized;
        final color = p.rate >= 0 ? AppColors.success : AppColors.error;
        return _BarWithLabel(
          label: p.month.substring(0, 3),
          barHeight: barHeight,
          color: color,
        );
      }).toList(),
    );
  }
}

/// Spending bar chart: all amber tones, most recent bar brighter.
class _SpendingBarChart extends StatelessWidget {
  final List<SavingsRatePoint> points;
  final Color accentColor;

  const _SpendingBarChart({required this.points, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final data = points.length > 5 ? points.sublist(0, 5) : points;
    if (data.isEmpty) return const SizedBox.shrink();

    final maxExpense =
        data.map((p) => p.expense).fold(1.0, (a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: data.asMap().entries.map((entry) {
        final i = entry.key;
        final p = entry.value;
        final normalized =
            maxExpense > 0 ? (p.expense / maxExpense).clamp(0.05, 1.0) : 0.05;
        final barHeight = 52 * normalized;
        final isLatest = i == data.length - 1;
        final color = isLatest ? Colors.orange : Colors.orange.withValues(alpha: 0.5);
        return _BarWithLabel(
          label: p.month.substring(0, 3),
          barHeight: barHeight.toDouble(),
          color: color,
        );
      }).toList(),
    );
  }
}

class _BarWithLabel extends StatelessWidget {
  final String label;
  final double barHeight;
  final Color color;

  const _BarWithLabel({
    required this.label,
    required this.barHeight,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 28,
          height: barHeight.clamp(4.0, 52.0),
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 9),
        ),
      ],
    );
  }
}

/// Budget dot row: green = all kept, amber = mostly kept, red = exceeded.
class _BudgetDotRow extends StatelessWidget {
  final List<BudgetPerfMonth> budgetPerf;

  const _BudgetDotRow({required this.budgetPerf});

  @override
  Widget build(BuildContext context) {
    final data =
        budgetPerf.length > 5 ? budgetPerf.sublist(0, 5) : budgetPerf;
    if (data.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: data.map((m) {
            Color dotColor;
            if (m.exceededCount == 0) {
              dotColor = AppColors.success;
            } else if (m.exceededPct <= 25) {
              dotColor = Colors.amber;
            } else {
              dotColor = AppColors.error;
            }
            return Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  m.month.substring(0, 3),
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// 4 horizontal component progress bars for health score achievements.
class _HealthComponentBars extends StatelessWidget {
  final FinancialHealthScore health;
  final Color accentColor;
  final List<BudgetPerfMonth> budgetPerf;
  final List<SavingsRatePoint> savingsPoints;

  const _HealthComponentBars({
    required this.health,
    required this.accentColor,
    required this.budgetPerf,
    required this.savingsPoints,
  });

  @override
  Widget build(BuildContext context) {
    final realIncomeMonths =
        savingsPoints.where((p) => p.income > 0).length;
    final savingsInflated =
        health.savingsComponent == 50.0 && realIncomeMonths < 3;
    final budgetInflated =
        health.budgetComponent == 70.0 && budgetPerf.isEmpty;

    final components = [
      _ComponentData(
        label: 'Savings',
        score: health.savingsComponent,
        inflated: savingsInflated,
      ),
      _ComponentData(
        label: 'Budget',
        score: health.budgetComponent,
        inflated: budgetInflated,
      ),
      _ComponentData(label: 'Debt', score: health.debtComponent),
      _ComponentData(label: 'Trend', score: health.trendComponent),
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: components.map((c) {
        if (c.inflated) {
          return _ComponentBarRow(
            label: c.label,
            score: 0,
            barColor: Colors.grey,
            scoreText: '—',
            accentColor: accentColor,
          );
        }
        final barColor = _barColor(c.score, accentColor);
        return _ComponentBarRow(
          label: c.label,
          score: c.score,
          barColor: barColor,
          scoreText: '${c.score.round()}',
          accentColor: accentColor,
        );
      }).toList(),
    );
  }

  Color _barColor(double score, Color accent) {
    if (score >= 70) return accent;
    if (score >= 40) return Colors.amber;
    return AppColors.error;
  }
}

class _ComponentData {
  final String label;
  final double score;
  final bool inflated;

  const _ComponentData({
    required this.label,
    required this.score,
    this.inflated = false,
  });
}

class _ComponentBarRow extends StatelessWidget {
  final String label;
  final double score;
  final Color barColor;
  final String scoreText;
  final Color accentColor;

  const _ComponentBarRow({
    required this.label,
    required this.score,
    required this.barColor,
    required this.scoreText,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (score / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 24,
            child: Text(
              scoreText,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: barColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Achievement picker bottom sheet
// ---------------------------------------------------------------------------

/// Shows a bottom sheet listing all unlocked shareable achievements ranked
/// from highest to lowest tier. Tapping a row closes the sheet and shares
/// that achievement's card.
class AchievementPickerSheet extends StatelessWidget {
  final List<AchievementResult> shareable;
  final List<SavingsRatePoint> savingsPoints;
  final List<BudgetPerfMonth> budgetPerf;
  final FinancialHealthScore health;
  final WidgetRef ref;

  const AchievementPickerSheet({
    super.key,
    required this.shareable,
    required this.savingsPoints,
    required this.budgetPerf,
    required this.health,
    required this.ref,
  });

  IconData _iconFor(AchievementType type) {
    return switch (type) {
      AchievementType.financeChampion => Icons.emoji_events,
      AchievementType.savingsStreak => Icons.local_fire_department,
      AchievementType.gradeA => Icons.workspace_premium,
      AchievementType.gradeB => Icons.grade,
      AchievementType.budgetChampion => Icons.shield,
      AchievementType.budgetDisciplined => Icons.shield_outlined,
      AchievementType.spendingUnderControl => Icons.trending_down,
    };
  }

  String _nameFor(AchievementType type) {
    return switch (type) {
      AchievementType.financeChampion => 'Finance Champion',
      AchievementType.savingsStreak => 'Savings Streak',
      AchievementType.gradeA => 'Financial Grade A',
      AchievementType.gradeB => 'Financial Grade B',
      AchievementType.budgetChampion => 'Budget Champion',
      AchievementType.budgetDisciplined => 'Budget Disciplined',
      AchievementType.spendingUnderControl => 'Spending Under Control',
    };
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    const bgColor = Color(0xFF1A1A2E);
    const dividerColor = Color(0xFF2A2A3E);

    return Container(
      decoration: const BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.share_outlined, color: accentColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Share Achievement',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: dividerColor, height: 1),
          // Achievement rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: shareable.length,
            separatorBuilder: (context, i) =>
                const Divider(color: dividerColor, height: 1),
            itemBuilder: (context, index) {
              final achievement = shareable[index];
              final icon = _iconFor(achievement.type);
              final name = _nameFor(achievement.type);

              return InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  shareAchievement(
                    context: context,
                    ref: ref,
                    achievement: achievement,
                    savingsPoints: savingsPoints,
                    budgetPerf: budgetPerf,
                    health: health,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      // Badge icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor.withValues(alpha: 0.12),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Icon(icon, color: accentColor, size: 20),
                      ),
                      const SizedBox(width: 14),
                      // Name + hero number/label
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${achievement.heroNumber}  •  ${achievement.heroLabel}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Share arrow
                      Icon(
                        Icons.chevron_right,
                        color: Colors.white.withValues(alpha: 0.3),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Bottom safe-area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }
}
