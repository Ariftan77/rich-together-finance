import 'package:flutter_test/flutter_test.dart';
import 'package:rich_together/core/database/database.dart';
import 'package:rich_together/core/localization/translations_en.dart';
import 'package:rich_together/core/localization/translations_id.dart';
import 'package:rich_together/core/models/enums.dart';
import 'package:rich_together/core/services/budget_alert_calculator.dart';
import 'package:rich_together/features/budget/presentation/providers/budget_provider.dart';

BudgetWithSpending _makeBudget({
  required int id,
  required String name,
  required double amount,
  required double spent,
  BudgetPeriod period = BudgetPeriod.monthly,
  bool isActive = true,
}) {
  return BudgetWithSpending(
    budget: Budget(
      id: id,
      profileId: 1,
      name: name,
      amount: amount,
      currency: Currency.usd,
      period: period,
      startDate: DateTime(2026, 11, 1),
      isActive: isActive,
      createdAt: DateTime(2026, 11, 1),
      isSynced: false,
    ),
    categories: [
      Category(
        id: id,
        profileId: 1,
        name: name,
        type: CategoryType.expense,
        icon: '🍔',
        isSystem: false,
        sortOrder: 0,
        isSynced: false,
      ),
    ],
    linkedCategoryCount: 1,
    spentAmount: spent,
  );
}

void main() {
  final en = AppTranslationsEn();
  final id = AppTranslationsId();

  group('BudgetAlertCalculator.buildSchedule', () {
    test('returns empty when no budgets reach threshold or exceed 100%', () {
      final schedule = BudgetAlertCalculator.buildSchedule(
        budgets: [
          _makeBudget(id: 1, name: 'Food', amount: 100, spent: 89),
          _makeBudget(id: 2, name: 'Inactive', amount: 100, spent: 99, isActive: false),
        ],
        now: DateTime(2026, 11, 20, 10, 0),
        hour: 20,
        minute: 0,
        thresholdPercent: 90,
        trans: en,
      );

      expect(schedule, isEmpty);
    });

    test('includes budgets at or above custom threshold and excludes below', () {
      final schedule = BudgetAlertCalculator.buildSchedule(
        budgets: [
          _makeBudget(id: 1, name: 'Food', amount: 100, spent: 75),
          _makeBudget(id: 2, name: 'Transport', amount: 100, spent: 82),
          _makeBudget(id: 3, name: 'Coffee', amount: 100, spent: 74),
        ],
        now: DateTime(2026, 11, 20, 10, 0),
        hour: 20,
        minute: 0,
        thresholdPercent: 75,
        trans: en,
      );

      expect(schedule, isNotEmpty);
      expect(schedule.first.title, en.notificationBudgetNearTitle(75));
      expect(schedule.first.body, contains('Transport (82%)'));
      expect(schedule.first.body, contains('Food (75%)'));
      expect(schedule.first.body, isNot(contains('Coffee')));
    });

    test('always includes exceeded budgets alongside near-limit budgets', () {
      final schedule = BudgetAlertCalculator.buildSchedule(
        budgets: [
          _makeBudget(id: 1, name: 'Dining', amount: 100, spent: 120),
          _makeBudget(id: 2, name: 'Groceries', amount: 100, spent: 92),
          _makeBudget(id: 3, name: 'Utilities', amount: 100, spent: 50),
        ],
        now: DateTime(2026, 11, 20, 10, 0),
        hour: 20,
        minute: 0,
        thresholdPercent: 90,
        trans: en,
      );

      expect(schedule, isNotEmpty);
      expect(schedule.first.title, en.notificationBudgetCombinedTitle);
      expect(schedule.first.body, contains('Dining (120%)'));
      expect(schedule.first.body, contains('Groceries (92%)'));
      expect(schedule.first.body, isNot(contains('Utilities')));
    });

    test('includes exceeded budgets even when threshold is 100%', () {
      final schedule = BudgetAlertCalculator.buildSchedule(
        budgets: [
          _makeBudget(id: 1, name: 'Shopping', amount: 100, spent: 100.4),
        ],
        now: DateTime(2026, 11, 20, 10, 0),
        hour: 20,
        minute: 0,
        thresholdPercent: 100,
        trans: en,
      );

      expect(schedule, isNotEmpty);
      expect(schedule.first.title, en.notificationBudgetExceededTitle);
      expect(schedule.first.body, contains('Shopping has exceeded its budget (101%)!'));
    });

    test('starts today when alert time is in the future, tomorrow when passed', () {
      final budgets = [_makeBudget(id: 1, name: 'Food', amount: 100, spent: 95)];

      final beforeAlert = BudgetAlertCalculator.buildSchedule(
        budgets: budgets,
        now: DateTime(2026, 11, 20, 19, 59),
        hour: 20,
        minute: 0,
        thresholdPercent: 90,
        trans: en,
      );
      expect(
        beforeAlert.first.scheduledLocalDateTime,
        DateTime(2026, 11, 20, 20, 0),
      );

      final atAlert = BudgetAlertCalculator.buildSchedule(
        budgets: budgets,
        now: DateTime(2026, 11, 20, 20, 0),
        hour: 20,
        minute: 0,
        thresholdPercent: 90,
        trans: en,
      );
      expect(
        atAlert.first.scheduledLocalDateTime,
        DateTime(2026, 11, 21, 20, 0),
      );
    });

    test('stops scheduling on period rollover for weekly, monthly, and yearly', () {
      // Friday 2026-11-27 10:00 -> weekly period ends Sunday 2026-11-29 (3 days: Fri, Sat, Sun)
      final weekly = BudgetAlertCalculator.buildSchedule(
        budgets: [
          _makeBudget(
            id: 1,
            name: 'WeeklyFood',
            amount: 100,
            spent: 95,
            period: BudgetPeriod.weekly,
          ),
        ],
        now: DateTime(2026, 11, 27, 10, 0),
        hour: 20,
        minute: 0,
        thresholdPercent: 90,
        trans: en,
      );
      expect(weekly.length, 3);
      expect(weekly.last.scheduledLocalDateTime, DateTime(2026, 11, 29, 20, 0));

      // 2026-11-27 10:00 -> monthly period ends 2026-11-30 (4 days: 27..30)
      final monthly = BudgetAlertCalculator.buildSchedule(
        budgets: [
          _makeBudget(
            id: 2,
            name: 'MonthlyRent',
            amount: 100,
            spent: 95,
            period: BudgetPeriod.monthly,
          ),
        ],
        now: DateTime(2026, 11, 27, 10, 0),
        hour: 20,
        minute: 0,
        thresholdPercent: 90,
        trans: en,
      );
      expect(monthly.length, 4);
      expect(monthly.last.scheduledLocalDateTime, DateTime(2026, 11, 30, 20, 0));

      // 2026-12-28 10:00 -> yearly period ends 2026-12-31 (4 days: 28..31)
      final yearly = BudgetAlertCalculator.buildSchedule(
        budgets: [
          _makeBudget(
            id: 3,
            name: 'YearlyTravel',
            amount: 100,
            spent: 110,
            period: BudgetPeriod.yearly,
          ),
        ],
        now: DateTime(2026, 12, 28, 10, 0),
        hour: 20,
        minute: 0,
        thresholdPercent: 90,
        trans: en,
      );
      expect(yearly.length, 4);
      expect(yearly.last.scheduledLocalDateTime, DateTime(2026, 12, 31, 20, 0));
    });

    test('formats overflow suffix and Indonesian localization properly', () {
      final budgets = [
        _makeBudget(id: 1, name: 'A', amount: 100, spent: 95),
        _makeBudget(id: 2, name: 'B', amount: 100, spent: 94),
        _makeBudget(id: 3, name: 'C', amount: 100, spent: 93),
        _makeBudget(id: 4, name: 'D', amount: 100, spent: 92),
      ];

      final scheduleId = BudgetAlertCalculator.buildSchedule(
        budgets: budgets,
        now: DateTime(2026, 11, 1, 10, 0),
        hour: 20,
        minute: 0,
        thresholdPercent: 90,
        trans: id,
      );

      expect(scheduleId, isNotEmpty);
      expect(scheduleId.first.title, id.notificationBudgetNearTitle(90));
      expect(scheduleId.first.body, contains('+1 lainnya'));
      expect(scheduleId.first.id, BudgetAlertCalculator.baseNotificationId);
    });
  });
}
