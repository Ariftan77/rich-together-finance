import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/providers/locale_provider.dart';

/// Provider for notification settings (reminder toggle + time).
final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
  (ref) {
    final trans = ref.watch(translationsProvider);
    return NotificationSettingsNotifier(trans);
  },
);

class NotificationSettings {
  final bool isReminderEnabled;
  final TimeOfDay reminderTime;

  const NotificationSettings({
    this.isReminderEnabled = false,
    this.reminderTime = const TimeOfDay(hour: 20, minute: 0),
  });

  NotificationSettings copyWith({
    bool? isReminderEnabled,
    TimeOfDay? reminderTime,
  }) {
    return NotificationSettings(
      isReminderEnabled: isReminderEnabled ?? this.isReminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }
}

class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  final AppTranslations trans;

  NotificationSettingsNotifier(this.trans) : super(const NotificationSettings()) {
    _loadFromPrefs();
  }

  static const _enabledKey = 'reminder_enabled';
  static const _hourKey = 'reminder_hour';
  static const _minuteKey = 'reminder_minute';

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey) ?? false;
    final hour = prefs.getInt(_hourKey) ?? 20;
    final minute = prefs.getInt(_minuteKey) ?? 0;

    state = NotificationSettings(
      isReminderEnabled: enabled,
      reminderTime: TimeOfDay(hour: hour, minute: minute),
    );

    // Re-schedule if enabled
    if (enabled) {
      _scheduleReminder(hour, minute);
    }
  }

  Future<void> toggleReminder(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);

    state = state.copyWith(isReminderEnabled: enabled);

    if (enabled) {
      // 1. Ask for permission first
      await NotificationService().requestPermissions();
      // 2. Schedule
      await _scheduleReminder(state.reminderTime.hour, state.reminderTime.minute);
    } else {
      await NotificationService().cancelReminder();
    }
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hourKey, time.hour);
    await prefs.setInt(_minuteKey, time.minute);

    state = state.copyWith(reminderTime: time);

    if (state.isReminderEnabled) {
      _scheduleReminder(time.hour, time.minute);
    }
  }

  Future<void> _scheduleReminder(int hour, int minute) async {
    await NotificationService().scheduleDailyReminder(
      hour: hour,
      minute: minute,
      title: trans.notificationReminderTitle,
      body: trans.notificationReminderBody,
    );
  }
}
