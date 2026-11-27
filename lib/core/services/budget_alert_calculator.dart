import 'dart:math' as math;

import '../../features/budget/presentation/providers/budget_provider.dart';
import '../localization/app_translations.dart';
import '../models/enums.dart';

/// Represents one scheduled daily budget alert notification.
class ScheduledBudgetNotification {
  final int id;
  final DateTime scheduledLocalDateTime;
  final String title;
  final String body;

  const ScheduledBudgetNotification({
    required this.id,
    required this.scheduledLocalDateTime,
    required this.title,
    required this.body,
  });
}

/// Pure domain helper that builds upcoming daily budget alert notifications
/// without any OS/plugin side effects so it can be unit tested directly.
class BudgetAlertCalculator {
  BudgetAlertCalculator._();

  static const int baseNotificationId = 200;
  static const int maxHorizonDays = 30;

  /// Builds up to [horizonDays] daily notifications starting from the next
  /// occurrence of [hour]:[minute] strictly after [now].
  ///
  /// Only budgets that are active, have `amount > 0`, and belong to the same
  /// budget period as [now] on the target fire date are included so stale
  /// alerts never fire after a week/month/year rolls over.
  ///
  /// Exceeded budgets (`spentAmount > budget.amount`) are always included, even
  /// if [thresholdPercent] is set higher or lower.
  static List<ScheduledBudgetNotification> buildSchedule({
    required List<BudgetWithSpending> budgets,
    required DateTime now,
    required int hour,
    required int minute,
    required int thresholdPercent,
    required AppTranslations trans,
    int horizonDays = maxHorizonDays,
  }) {
    final activeBudgets = budgets
        .where((b) => b.budget.isActive && b.budget.amount > 0)
        .toList();
    if (activeBudgets.isEmpty || horizonDays <= 0) {
      return const [];
    }

    final clampedThreshold = thresholdPercent.clamp(1, 100);
    var firstFireDate = DateTime(now.year, now.month, now.day, hour, minute);
    if (!firstFireDate.isAfter(now)) {
      firstFireDate = DateTime(
        now.year,
        now.month,
        now.day + 1,
        hour,
        minute,
      );
    }

    final results = <ScheduledBudgetNotification>[];

    for (var dayIndex = 0; dayIndex < horizonDays; dayIndex++) {
      final fireDate = DateTime(
        firstFireDate.year,
        firstFireDate.month,
        firstFireDate.day + dayIndex,
        hour,
        minute,
      );

      final inPeriod = activeBudgets
          .where((b) => isSameBudgetPeriod(b.budget.period, now, fireDate))
          .toList();
      if (inPeriod.isEmpty) continue;

      final exceeded = <BudgetWithSpending>[];
      final nearLimit = <BudgetWithSpending>[];

      for (final item in inPeriod) {
        if (item.spentAmount > item.budget.amount) {
          exceeded.add(item);
        } else if ((item.progress * 100 + 1e-9) >= clampedThreshold) {
          nearLimit.add(item);
        }
      }

      if (exceeded.isEmpty && nearLimit.isEmpty) continue;

      exceeded.sort((a, b) => b.progress.compareTo(a.progress));
      nearLimit.sort((a, b) => b.progress.compareTo(a.progress));

      final payload = _buildTitleAndBody(
        exceeded: exceeded,
        nearLimit: nearLimit,
        thresholdPercent: clampedThreshold,
        trans: trans,
      );

      results.add(
        ScheduledBudgetNotification(
          id: baseNotificationId + results.length,
          scheduledLocalDateTime: fireDate,
          title: payload.title,
          body: payload.body,
        ),
      );
    }

    return results;
  }

  /// Returns whether two local timestamps fall in the same [BudgetPeriod].
  static bool isSameBudgetPeriod(
    BudgetPeriod period,
    DateTime a,
    DateTime b,
  ) {
    switch (period) {
      case BudgetPeriod.weekly:
        final startA = DateTime(a.year, a.month, a.day - (a.weekday - 1));
        final startB = DateTime(b.year, b.month, b.day - (b.weekday - 1));
        return startA.year == startB.year &&
            startA.month == startB.month &&
            startA.day == startB.day;
      case BudgetPeriod.monthly:
        return a.year == b.year && a.month == b.month;
      case BudgetPeriod.yearly:
        return a.year == b.year;
    }
  }

  static int _displayPercent(BudgetWithSpending item) {
    final rounded = (item.progress * 100).round();
    if (item.spentAmount > item.budget.amount && rounded <= 100) {
      return math.max(101, rounded);
    }
    return rounded;
  }

  static String _formatBudgetList(
    List<BudgetWithSpending> items,
    AppTranslations trans, {
    int maxShown = 3,
  }) {
    final shown = items
        .take(maxShown)
        .map((b) => '${b.categoryName} (${_displayPercent(b)}%)')
        .join(', ');
    final overflow = items.length - maxShown;
    if (overflow > 0) {
      return '$shown ${trans.notificationBudgetMoreSuffix(overflow)}';
    }
    return shown;
  }

  static ({String title, String body}) _buildTitleAndBody({
    required List<BudgetWithSpending> exceeded,
    required List<BudgetWithSpending> nearLimit,
    required int thresholdPercent,
    required AppTranslations trans,
  }) {
    if (exceeded.isNotEmpty && nearLimit.isNotEmpty) {
      return (
        title: trans.notificationBudgetCombinedTitle,
        body: trans.notificationBudgetCombinedBody(
          _formatBudgetList(exceeded, trans),
          thresholdPercent,
          _formatBudgetList(nearLimit, trans),
        ),
      );
    }

    if (exceeded.isNotEmpty) {
      if (exceeded.length == 1) {
        final item = exceeded.first;
        return (
          title: trans.notificationBudgetExceededTitle,
          body: trans.notificationBudgetSingleExceededBody(
            item.categoryName,
            _displayPercent(item),
          ),
        );
      }
      return (
        title: trans.notificationBudgetExceededTitle,
        body: trans.notificationBudgetMultiExceededBody(
          exceeded.length,
          _formatBudgetList(exceeded, trans),
        ),
      );
    }

    if (nearLimit.length == 1) {
      final item = nearLimit.first;
      return (
        title: trans.notificationBudgetNearTitle(thresholdPercent),
        body: trans.notificationBudgetSingleNearBody(
          item.categoryName,
          _displayPercent(item),
        ),
      );
    }

    return (
      title: trans.notificationBudgetNearTitle(thresholdPercent),
      body: trans.notificationBudgetMultiNearBody(
        nearLimit.length,
        thresholdPercent,
        _formatBudgetList(nearLimit, trans),
      ),
    );
  }
}
