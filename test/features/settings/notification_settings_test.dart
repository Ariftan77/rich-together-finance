import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rich_together/core/localization/translations_en.dart';
import 'package:rich_together/core/providers/locale_provider.dart';
import 'package:rich_together/core/providers/service_providers.dart';
import 'package:rich_together/features/settings/providers/notification_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderContainer _createTestContainer() {
  return ProviderContainer(
    overrides: [
      translationsProvider.overrideWithValue(AppTranslationsEn()),
      premiumStatusProvider.overrideWithValue(false),
      iapEnabledProvider.overrideWithValue(false),
      premiumEnabledProvider.overrideWithValue(false),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationSettingsNotifier', () {
    test('loads default values when SharedPreferences is empty', () async {
      SharedPreferences.setMockInitialValues({});
      final container = _createTestContainer();
      addTearDown(container.dispose);

      // Trigger provider creation and wait for async _loadFromPrefs
      container.read(notificationSettingsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(notificationSettingsProvider);
      expect(state.isLoaded, isTrue);
      expect(state.isReminderEnabled, isFalse);
      expect(state.reminderTime, const TimeOfDay(hour: 20, minute: 0));
      expect(state.customReminderText, isNull);
      expect(state.hasCustomText, isFalse);
      expect(state.isBudgetAlertEnabled, isFalse);
      expect(state.budgetAlertTime, const TimeOfDay(hour: 20, minute: 0));
      expect(state.budgetAlertThreshold, 90);
    });

    test('persists custom reminder text and resets cleanly to default', () async {
      SharedPreferences.setMockInitialValues({});
      final container = _createTestContainer();
      addTearDown(container.dispose);

      final notifier = container.read(notificationSettingsProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.setCustomReminderText('  Log your coffee expenses!  ');
      var state = container.read(notificationSettingsProvider);
      expect(state.hasCustomText, isTrue);
      expect(state.customReminderText, 'Log your coffee expenses!');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(NotificationSettingsNotifier.customTextKey),
        'Log your coffee expenses!',
      );

      // Reset via explicit reset method
      await notifier.resetCustomReminderText();
      state = container.read(notificationSettingsProvider);
      expect(state.hasCustomText, isFalse);
      expect(state.customReminderText, isNull);
      expect(
        prefs.getString(NotificationSettingsNotifier.customTextKey),
        isNull,
      );

      // Saving the exact default text also normalizes back to null/default
      await notifier.setCustomReminderText(
        AppTranslationsEn().notificationReminderBody,
      );
      state = container.read(notificationSettingsProvider);
      expect(state.hasCustomText, isFalse);
      expect(state.customReminderText, isNull);
    });

    test('persists reminder time, budget alert time, and clamped threshold',
        () async {
      SharedPreferences.setMockInitialValues({});
      final container = _createTestContainer();
      addTearDown(container.dispose);

      final notifier = container.read(notificationSettingsProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await notifier.setReminderTime(const TimeOfDay(hour: 9, minute: 30));
      await notifier.setBudgetAlertTime(const TimeOfDay(hour: 21, minute: 15));
      await notifier.setBudgetAlertThreshold(75);

      var state = container.read(notificationSettingsProvider);
      expect(state.reminderTime, const TimeOfDay(hour: 9, minute: 30));
      expect(state.budgetAlertTime, const TimeOfDay(hour: 21, minute: 15));
      expect(state.budgetAlertThreshold, 75);

      // Clamps out-of-range thresholds into 1..100
      await notifier.setBudgetAlertThreshold(150);
      expect(
        container.read(notificationSettingsProvider).budgetAlertThreshold,
        100,
      );

      await notifier.setBudgetAlertThreshold(0);
      expect(
        container.read(notificationSettingsProvider).budgetAlertThreshold,
        1,
      );
    });
  });
}
