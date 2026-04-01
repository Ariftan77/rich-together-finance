import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../features/dashboard/presentation/providers/dashboard_providers.dart';
import '../logic/achievement_qualifier.dart';

export '../logic/achievement_qualifier.dart' show AchievementResult, AchievementType;

/// Evaluates all 7 achievements from current provider data.
/// Returns unlocked achievements in display priority order.
final achievementProvider =
    FutureProvider.autoDispose<List<AchievementResult>>((ref) async {
  final profileId = ref.watch(activeProfileIdProvider);

  final health = await ref.watch(financialHealthScoreProvider.future);
  final cashFlow = await ref.watch(dashboardCashFlowProvider.future);
  final budgetPerf = await ref.watch(budgetPerformanceProvider.future);
  final savingsRateAsync = ref.watch(savingsRateTrendProvider);

  final savingsRate = savingsRateAsync.whenOrNull(data: (v) => v) ?? [];

  return AchievementQualifier.evaluate(
    cashFlow: cashFlow,
    health: health,
    budgetPerf: budgetPerf,
    savingsRate: savingsRate,
    profileId: profileId,
  );
});
