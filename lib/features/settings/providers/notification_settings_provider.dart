import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/providers/date_providers.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/providers/service_providers.dart';
import '../../../core/services/budget_alert_calculator.dart';
import '../../../core/services/notification_service.dart';
import '../../budget/presentation/providers/budget_provider.dart';

/// Provider for notification settings (daily reminder + budget alerts).
///
/// Uses [Ref] so locale/premium changes reschedule notifications cleanly
/// without destroying the [StateNotifier] or resetting loaded preferences.
final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
  (ref) => NotificationSettingsNotifier(ref),
);

/// Watches active budgets, notification settings, locale, date, and active
/// profile to keep scheduled daily budget notifications synchronized.
final budgetNotificationSyncProvider = Provider<void>((ref) {
  final notif = ref.watch(notificationSettingsProvider);
  final budgetsAsync = ref.watch(budgetsWithSpendingProvider);
  final trans = ref.watch(translationsProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  ref.watch(currentDateProvider);

  // Use a controller kept alive in this provider closure via ref.onDispose.
  final controller = _BudgetSyncDebounceHolder.instanceFor(ref);

  if (!notif.isLoaded) return;

  if (!notif.isBudgetAlertEnabled || profileId == null) {
    controller.schedule(() async {
      if (controller.lastSignature == 'OFF') return;
      controller.lastSignature = 'OFF';
      await NotificationService().cancelAllBudgetNotifications();
    });
    return;
  }

  budgetsAsync.whenData((budgets) {
    controller.schedule(() async {
      final schedule = BudgetAlertCalculator.buildSchedule(
        budgets: budgets,
        now: DateTime.now(),
        hour: notif.budgetAlertTime.hour,
        minute: notif.budgetAlertTime.minute,
        thresholdPercent: notif.budgetAlertThreshold,
        trans: trans,
      );
      final sigBuffer = StringBuffer()
        ..write('${notif.budgetAlertTime.hour}:${notif.budgetAlertTime.minute}')
        ..write('|${notif.budgetAlertThreshold}|');
      for (final item in schedule) {
        sigBuffer
          ..write(item.id)
          ..write('|')
          ..write(item.scheduledLocalDateTime.toIso8601String())
          ..write('|')
          ..write(item.title)
          ..write('|')
          ..write(item.body)
          ..write(';');
      }
      final sig = sigBuffer.toString();
      if (controller.lastSignature == sig) return;
      controller.lastSignature = sig;
      await NotificationService().syncBudgetNotifications(schedule);
    });
  });
});

class _BudgetSyncDebounceHolder {
  Timer? _timer;
  String? lastSignature;

  static final Expando<_BudgetSyncDebounceHolder> _holders = Expando();

  static _BudgetSyncDebounceHolder instanceFor(Ref ref) {
    final existing = _holders[ref];
    if (existing != null) return existing;
    final created = _BudgetSyncDebounceHolder();
    _holders[ref] = created;
    ref.onDispose(() {
      created._timer?.cancel();
      created._timer = null;
    });
    return created;
  }

  void schedule(Future<void> Function() action) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 350), () {
      unawaited(action());
    });
  }
}

class NotificationSettings {
  final bool isLoaded;
  final bool isReminderEnabled;
  final TimeOfDay reminderTime;
  final String? customReminderText;
  final bool isBudgetAlertEnabled;
  final TimeOfDay budgetAlertTime;
  final int budgetAlertThreshold;

  const NotificationSettings({
    this.isLoaded = false,
    this.isReminderEnabled = false,
    this.reminderTime = const TimeOfDay(hour: 20, minute: 0),
    this.customReminderText,
    this.isBudgetAlertEnabled = false,
    this.budgetAlertTime = const TimeOfDay(hour: 20, minute: 0),
    this.budgetAlertThreshold = 90,
  });

  bool get hasCustomText =>
      customReminderText != null && customReminderText!.trim().isNotEmpty;

  NotificationSettings copyWith({
    bool? isLoaded,
    bool? isReminderEnabled,
    TimeOfDay? reminderTime,
    String? customReminderText,
    bool clearCustomText = false,
    bool? isBudgetAlertEnabled,
    TimeOfDay? budgetAlertTime,
    int? budgetAlertThreshold,
  }) {
    return NotificationSettings(
      isLoaded: isLoaded ?? this.isLoaded,
      isReminderEnabled: isReminderEnabled ?? this.isReminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      customReminderText: clearCustomText
          ? null
          : (customReminderText ?? this.customReminderText),
      isBudgetAlertEnabled: isBudgetAlertEnabled ?? this.isBudgetAlertEnabled,
      budgetAlertTime: budgetAlertTime ?? this.budgetAlertTime,
      budgetAlertThreshold: budgetAlertThreshold ?? this.budgetAlertThreshold,
    );
  }
}

class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  final Ref _ref;

  NotificationSettingsNotifier(this._ref) : super(const NotificationSettings()) {
    _ref.listen<AppTranslations>(translationsProvider, (_, _) {
      if (state.isLoaded && state.isReminderEnabled) {
        unawaited(_scheduleReminder());
      }
    });
    _ref.listen<bool>(premiumStatusProvider, (_, _) {
      if (state.isLoaded && state.isReminderEnabled) {
        unawaited(_scheduleReminder());
      }
    });
    _loadFromPrefs();
  }

  static const enabledKey = 'reminder_enabled';
  static const hourKey = 'reminder_hour';
  static const minuteKey = 'reminder_minute';
  static const customTextKey = 'reminder_custom_text';
  static const budgetEnabledKey = 'budget_alert_enabled';
  static const budgetHourKey = 'budget_alert_hour';
  static const budgetMinuteKey = 'budget_alert_minute';
  static const budgetThresholdKey = 'budget_alert_threshold';
  static const exactAlarmPromptedKey = 'exact_alarm_prompted';

  bool get _canUseCustomText {
    final premiumEnabled = _ref.read(premiumEnabledProvider);
    final iapEnabled = _ref.read(iapEnabledProvider);
    final isPremium = _ref.read(premiumStatusProvider);
    return !premiumEnabled || !iapEnabled || isPremium;
  }

  String _effectiveReminderBody() {
    final trans = _ref.read(translationsProvider);
    if (state.hasCustomText && _canUseCustomText) {
      return state.customReminderText!.trim();
    }
    return trans.notificationReminderBody;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(enabledKey) ?? false;
    final hour = (prefs.getInt(hourKey) ?? 20).clamp(0, 23);
    final minute = (prefs.getInt(minuteKey) ?? 0).clamp(0, 59);
    final rawCustomText = prefs.getString(customTextKey);
    final customText = (rawCustomText != null && rawCustomText.trim().isNotEmpty)
        ? rawCustomText.trim()
        : null;

    final budgetEnabled = prefs.getBool(budgetEnabledKey) ?? false;
    final budgetHour = (prefs.getInt(budgetHourKey) ?? 20).clamp(0, 23);
    final budgetMinute = (prefs.getInt(budgetMinuteKey) ?? 0).clamp(0, 59);
    final budgetThreshold =
        (prefs.getInt(budgetThresholdKey) ?? 90).clamp(1, 100);

    if (!mounted) return;
    state = NotificationSettings(
      isLoaded: true,
      isReminderEnabled: enabled,
      reminderTime: TimeOfDay(hour: hour, minute: minute),
      customReminderText: customText,
      isBudgetAlertEnabled: budgetEnabled,
      budgetAlertTime: TimeOfDay(hour: budgetHour, minute: budgetMinute),
      budgetAlertThreshold: budgetThreshold,
    );

    // Silently re-schedule on startup if enabled (no interactive permission dialogs).
    if (enabled) {
      unawaited(_scheduleReminder());
    }
  }

  Future<bool> _requestNotificationPermissionsInteractive(
    SharedPreferences prefs,
  ) async {
    final alreadyPromptedExact = prefs.getBool(exactAlarmPromptedKey) ?? false;
    final shouldPromptExact = !alreadyPromptedExact;
    if (shouldPromptExact) {
      await prefs.setBool(exactAlarmPromptedKey, true);
    }
    return NotificationService().requestPermissions(
      requestExactAlarmOnAndroid: shouldPromptExact,
    );
  }

  /// Toggles the daily transaction reminder. Returns `true` if the action
  /// succeeded or `false` if OS notification permission was denied.
  Future<bool> toggleReminder(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();

    if (enabled) {
      final permitted = await _requestNotificationPermissionsInteractive(prefs);
      if (!permitted) {
        await prefs.setBool(enabledKey, false);
        if (mounted) state = state.copyWith(isReminderEnabled: false);
        return false;
      }
      await prefs.setBool(enabledKey, true);
      if (mounted) state = state.copyWith(isReminderEnabled: true);
      await _scheduleReminder();
      return true;
    } else {
      await prefs.setBool(enabledKey, false);
      if (mounted) state = state.copyWith(isReminderEnabled: false);
      await NotificationService().cancelReminder();
      return true;
    }
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(hourKey, time.hour);
    await prefs.setInt(minuteKey, time.minute);

    if (mounted) state = state.copyWith(reminderTime: time);

    if (state.isReminderEnabled) {
      await _scheduleReminder();
    }
  }

  Future<void> setCustomReminderText(String? text) async {
    final prefs = await SharedPreferences.getInstance();
    final trans = _ref.read(translationsProvider);
    final trimmed = text?.trim();

    if (trimmed == null ||
        trimmed.isEmpty ||
        trimmed == trans.notificationReminderBody) {
      await prefs.remove(customTextKey);
      if (mounted) state = state.copyWith(clearCustomText: true);
    } else {
      await prefs.setString(customTextKey, trimmed);
      if (mounted) state = state.copyWith(customReminderText: trimmed);
    }

    if (state.isReminderEnabled) {
      await _scheduleReminder();
    }
  }

  Future<void> resetCustomReminderText() => setCustomReminderText(null);

  /// Toggles daily budget alerts. Returns `true` if the action succeeded or
  /// `false` if OS notification permission was denied.
  Future<bool> toggleBudgetAlert(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();

    if (enabled) {
      final permitted = await _requestNotificationPermissionsInteractive(prefs);
      if (!permitted) {
        await prefs.setBool(budgetEnabledKey, false);
        if (mounted) state = state.copyWith(isBudgetAlertEnabled: false);
        return false;
      }
      await prefs.setBool(budgetEnabledKey, true);
      if (mounted) state = state.copyWith(isBudgetAlertEnabled: true);
      return true;
    } else {
      await prefs.setBool(budgetEnabledKey, false);
      if (mounted) state = state.copyWith(isBudgetAlertEnabled: false);
      await NotificationService().cancelAllBudgetNotifications();
      return true;
    }
  }

  Future<void> setBudgetAlertTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(budgetHourKey, time.hour);
    await prefs.setInt(budgetMinuteKey, time.minute);

    if (mounted) state = state.copyWith(budgetAlertTime: time);
  }

  Future<void> setBudgetAlertThreshold(int percent) async {
    final clamped = percent.clamp(1, 100);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(budgetThresholdKey, clamped);

    if (mounted) state = state.copyWith(budgetAlertThreshold: clamped);
  }

  Future<void> _scheduleReminder() async {
    final trans = _ref.read(translationsProvider);
    await NotificationService().scheduleDailyReminder(
      hour: state.reminderTime.hour,
      minute: state.reminderTime.minute,
      title: trans.notificationReminderTitle,
      body: _effectiveReminderBody(),
    );
  }
}
