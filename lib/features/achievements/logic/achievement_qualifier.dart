// Pure Dart — no Flutter, no Riverpod imports.
// Input: raw provider data structs.
// Output: List<AchievementResult> (ordered by display priority).

import '../../../features/dashboard/presentation/providers/dashboard_providers.dart';

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

enum AchievementType {
  financeChampion,
  savingsStreak,
  gradeA,
  gradeB,
  budgetChampion,
  budgetDisciplined,
  spendingUnderControl,
}

class AchievementResult {
  final AchievementType type;
  final String heroNumber;   // e.g. "23%", "Score: 84", "All 4 budgets kept"
  final String heroLabel;    // short description below the hero number
  final double heroValue;    // raw numeric value for visualizations
  final bool isShareable;    // only Silver+ tier

  const AchievementResult({
    required this.type,
    required this.heroNumber,
    required this.heroLabel,
    required this.heroValue,
    required this.isShareable,
  });
}

// ---------------------------------------------------------------------------
// Qualifier — static evaluate()
// ---------------------------------------------------------------------------

class AchievementQualifier {
  // Display priority order (index 0 = highest priority).
  static const List<AchievementType> _priority = [
    AchievementType.financeChampion,
    AchievementType.savingsStreak,
    AchievementType.gradeA,
    AchievementType.gradeB,
    AchievementType.budgetChampion,
    AchievementType.budgetDisciplined,
    AchievementType.spendingUnderControl,
  ];

  /// Evaluate all 7 achievements and return unlocked ones in priority order.
  static List<AchievementResult> evaluate({
    required List<MonthlyFlow> cashFlow,          // 6 entries, index 5 = current month
    required FinancialHealthScore health,
    required List<BudgetPerfMonth> budgetPerf,    // up to 6 entries
    required List<SavingsRatePoint> savingsRate,  // 6 entries
    required int? profileId,
  }) {
    // ── Universal eligibility gate ────────────────────────────────────────
    if (profileId == null) return [];

    final realIncomeMonths =
        cashFlow.where((m) => m.income > 0).length;
    if (realIncomeMonths < 2) return [];

    // At least one completed month (indices 0–4) with income > 0.
    final completedWithIncome =
        _completedFlows(cashFlow).where((m) => m.income > 0).length;
    if (completedWithIncome < 1) return [];

    // ── Inflation flags ───────────────────────────────────────────────────
    final inflatedBudget =
        health.budgetComponent == 70.0 && budgetPerf.isEmpty;
    final inflatedSavings =
        health.savingsComponent == 50.0 && realIncomeMonths < 3;
    final inflatedTrend =
        health.trendComponent == 50.0 && realIncomeMonths < 2;

    // ── Evaluate each achievement ─────────────────────────────────────────
    final Map<AchievementType, AchievementResult> unlocked = {};

    // 1. Finance Champion
    final champion = _evalFinanceChampion(cashFlow, realIncomeMonths);
    if (champion != null) unlocked[AchievementType.financeChampion] = champion;

    // 2. Savings Streak
    if (!inflatedSavings) {
      final streak = _evalSavingsStreak(cashFlow, savingsRate);
      if (streak != null) unlocked[AchievementType.savingsStreak] = streak;
    }

    // 3. Grade A
    if (health.grade == 'A' &&
        realIncomeMonths >= 3 &&
        !inflatedSavings &&
        !inflatedBudget) {
      unlocked[AchievementType.gradeA] = AchievementResult(
        type: AchievementType.gradeA,
        heroNumber: 'Score: ${health.score.round()}',
        heroLabel: 'Grade A',
        heroValue: health.score,
        isShareable: true,
      );
    }

    // 4. Grade B
    if (health.grade == 'B' &&
        realIncomeMonths >= 3 &&
        health.savingsComponent > 50.0) {
      unlocked[AchievementType.gradeB] = AchievementResult(
        type: AchievementType.gradeB,
        heroNumber: 'Score: ${health.score.round()}',
        heroLabel: 'Grade B',
        heroValue: health.score,
        isShareable: true,
      );
    }

    // 5. Budget Champion
    if (!inflatedBudget) {
      final bc = _evalBudgetChampion(budgetPerf);
      if (bc != null) unlocked[AchievementType.budgetChampion] = bc;
    }

    // 6. Budget Disciplined
    if (!inflatedBudget) {
      final bd = _evalBudgetDisciplined(budgetPerf);
      if (bd != null) unlocked[AchievementType.budgetDisciplined] = bd;
    }

    // 7. Spending Under Control
    if (!inflatedTrend) {
      final suc = _evalSpendingUnderControl(cashFlow, health);
      if (suc != null) unlocked[AchievementType.spendingUnderControl] = suc;
    }

    // Return in priority order.
    return _priority
        .where((t) => unlocked.containsKey(t))
        .map((t) => unlocked[t]!)
        .toList();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Returns indices 0–4 (completed months), excluding index 5 (current month).
  static List<MonthlyFlow> _completedFlows(List<MonthlyFlow> cashFlow) {
    if (cashFlow.length <= 5) return cashFlow;
    return cashFlow.sublist(0, 5);
  }

  // ── Achievement logic ────────────────────────────────────────────────────

  static AchievementResult? _evalFinanceChampion(
    List<MonthlyFlow> cashFlow,
    int realIncomeMonths,
  ) {
    if (realIncomeMonths < 5) return null;
    final completed = _completedFlows(cashFlow);
    if (completed.length < 5) return null;

    // All 5 completed months must have income > expense AND income > 0.
    final qualifying = completed.where((m) => m.income > 0 && m.income > m.expense);
    if (qualifying.length < 5) return null;

    // Hero: best single-month savings rate among the 5.
    double bestRate = 0;
    for (final m in completed) {
      if (m.income > 0) {
        final rate = (m.income - m.expense) / m.income * 100;
        if (rate > bestRate) bestRate = rate;
      }
    }

    return AchievementResult(
      type: AchievementType.financeChampion,
      heroNumber: '${bestRate.round()}%',
      heroLabel: 'Best savings rate',
      heroValue: bestRate,
      isShareable: true,
    );
  }

  static AchievementResult? _evalSavingsStreak(
    List<MonthlyFlow> cashFlow,
    List<SavingsRatePoint> savingsRate,
  ) {
    final completed = _completedFlows(cashFlow);
    if (completed.length < 3) return null;

    // Find any 3 consecutive completed months (by array index) where
    // income > 0 AND income > expense.
    int? streakStart;
    for (int i = 0; i <= completed.length - 3; i++) {
      bool valid = true;
      for (int j = i; j < i + 3; j++) {
        final m = completed[j];
        if (m.income <= 0 || m.income <= m.expense) {
          valid = false;
          break;
        }
      }
      if (valid) {
        // Pick the latest streak (prefer most recent).
        streakStart = i;
      }
    }
    if (streakStart == null) return null;

    // Hero: average savings rate across the 3 qualifying months.
    double rateSum = 0;
    for (int j = streakStart; j < streakStart + 3; j++) {
      final m = completed[j];
      rateSum += (m.income - m.expense) / m.income * 100;
    }
    final avgRate = rateSum / 3;

    return AchievementResult(
      type: AchievementType.savingsStreak,
      heroNumber: '${avgRate.round()}%',
      heroLabel: 'Avg savings rate (3-month streak)',
      heroValue: avgRate,
      isShareable: true,
    );
  }

  static AchievementResult? _evalBudgetChampion(
    List<BudgetPerfMonth> budgetPerf,
  ) {
    if (budgetPerf.isEmpty) return null;

    // Find any completed month (indices 0–4) where totalBudgets >= 2
    // and exceededCount == 0.
    // budgetPerf has up to 6 entries, index 5 = current month.
    final completedBudget =
        budgetPerf.length > 5 ? budgetPerf.sublist(0, 5) : budgetPerf;

    BudgetPerfMonth? best;
    for (final m in completedBudget) {
      if (m.totalBudgets >= 2 && m.exceededCount == 0) {
        // Pick the one with the most budgets (most impressive).
        if (best == null || m.totalBudgets > best.totalBudgets) {
          best = m;
        }
      }
    }
    if (best == null) return null;

    return AchievementResult(
      type: AchievementType.budgetChampion,
      heroNumber: 'All ${best.totalBudgets}',
      heroLabel: 'budgets kept',
      heroValue: best.totalBudgets.toDouble(),
      isShareable: true,
    );
  }

  static AchievementResult? _evalBudgetDisciplined(
    List<BudgetPerfMonth> budgetPerf,
  ) {
    if (budgetPerf.isEmpty) return null;

    final completedBudget =
        budgetPerf.length > 5 ? budgetPerf.sublist(0, 5) : budgetPerf;
    if (completedBudget.length < 3) return null;

    // Find 3 consecutive completed months where totalBudgets >= 2
    // and exceededPct <= 25%.  A month with totalBudgets == 0 breaks streak.
    int? streakStart;
    for (int i = 0; i <= completedBudget.length - 3; i++) {
      bool valid = true;
      for (int j = i; j < i + 3; j++) {
        final m = completedBudget[j];
        if (m.totalBudgets < 2 || m.exceededPct > 25.0) {
          valid = false;
          break;
        }
      }
      if (valid) {
        streakStart = i; // keep latest
      }
    }
    if (streakStart == null) return null;

    // Hero: average adherence % across the 3 months.
    double adherenceSum = 0;
    for (int j = streakStart; j < streakStart + 3; j++) {
      final m = completedBudget[j];
      adherenceSum +=
          m.totalBudgets > 0 ? (1 - m.exceededCount / m.totalBudgets) * 100 : 0;
    }
    final avgAdherence = adherenceSum / 3;

    return AchievementResult(
      type: AchievementType.budgetDisciplined,
      heroNumber: '${avgAdherence.round()}%',
      heroLabel: 'budget adherence',
      heroValue: avgAdherence,
      isShareable: true,
    );
  }

  static AchievementResult? _evalSpendingUnderControl(
    List<MonthlyFlow> cashFlow,
    FinancialHealthScore health,
  ) {
    if (health.trendComponent < 60.0) return null;

    final completed = _completedFlows(cashFlow);
    if (completed.length < 3) return null;

    // 3 most recent completed months = indices 2, 3, 4.
    final last3 = completed.sublist(completed.length - 3);

    // All 3 must have income > 0.
    if (last3.any((m) => m.income <= 0)) return null;

    // Count month-over-month transitions where expense[m] <= expense[m-1].
    int decreasingTransitions = 0;
    // Transitions: (last3[0] -> last3[1]) and (last3[1] -> last3[2]).
    if (last3[1].expense <= last3[0].expense) decreasingTransitions++;
    if (last3[2].expense <= last3[1].expense) decreasingTransitions++;

    if (decreasingTransitions < 2) return null;

    // Hero: (expense[oldest] - expense[newest]) / expense[oldest] * 100.
    final oldest = last3[0].expense;
    final newest = last3[2].expense;

    if (oldest <= 0) return null;

    final delta = (oldest - newest) / oldest * 100;

    final heroNumber =
        delta >= 5 ? '${delta.round()}%' : '~0%';
    final heroLabel =
        delta >= 5 ? 'Expenses down' : 'Expenses stable';

    return AchievementResult(
      type: AchievementType.spendingUnderControl,
      heroNumber: heroNumber,
      heroLabel: heroLabel,
      heroValue: delta,
      isShareable: true,
    );
  }
}
