import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
// ignore: depend_on_referenced_packages
import 'package:timezone/data/latest_all.dart' as tz;
// ignore: depend_on_referenced_packages
import 'package:timezone/timezone.dart' as tz;

import 'budget_alert_calculator.dart';

class NotificationService {
  static final NotificationService _i = NotificationService._();
  factory NotificationService() => _i;
  NotificationService._();

  final _localNotifications = FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _fcm;
  Future<void>? _initFuture;

  static const _reminderChannelId = 'daily_reminder';
  static const _reminderChannelName = 'Daily Reminder';
  static const _budgetChannelId = 'budget_alerts';
  static const _budgetChannelName = 'Budget Alerts';
  static const _fcmChannelId = 'push_notifications';
  static const _fcmChannelName = 'Push Notifications';

  static const _reminderNotificationId = 100;
  static const _androidSmallIcon = '@drawable/ic_notification';

  /// Idempotent initialization — safe to call concurrently from startup and
  /// from interactive settings toggles.
  Future<void> init() => _initFuture ??= _doInit();

  Future<void> _doInit() async {
    _configureLocalTimezone();
    await _resolveTimezoneAsync();

    const androidSettings = AndroidInitializationSettings(_androidSmallIcon);
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      defaultPresentAlert: true,
      defaultPresentBanner: true,
      defaultPresentList: true,
      defaultPresentSound: true,
      defaultPresentBadge: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(settings);

    // Create notification channels eagerly (Android 8+) so channels and
    // system notification toggles appear immediately.
    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _reminderChannelId,
            _reminderChannelName,
            importance: Importance.high,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _budgetChannelId,
            _budgetChannelName,
            importance: Importance.high,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _fcmChannelId,
            _fcmChannelName,
            importance: Importance.high,
          ),
        );
      }
    }

    // Fire-and-forget FCM setup so startup never blocks on network calls.
    _initFcmAsync();
  }

  void _configureLocalTimezone() {
    tz.initializeTimeZones();
    _fallbackTimezoneByOffset();
  }

  Future<void> _resolveTimezoneAsync() async {
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('⚠️ Could not resolve IANA timezone, keeping offset fallback: $e');
      _fallbackTimezoneByOffset();
    }
  }

  void _fallbackTimezoneByOffset() {
    final localOffset = DateTime.now().timeZoneOffset;
    for (final location in tz.timeZoneDatabase.locations.values) {
      if (tz.TZDateTime.now(location).timeZoneOffset == localOffset) {
        tz.setLocalLocation(location);
        return;
      }
    }
    tz.setLocalLocation(tz.UTC);
  }

  void _initFcmAsync() async {
    try {
      _fcm = FirebaseMessaging.instance;

      // Handle foreground messages (sync, no network)
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // On iOS, ensure foreground FCM messages can present alert/badge/sound and
      // wait briefly for APNS token registration before token/topic calls.
      if (Platform.isIOS) {
        await _fcm!.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
        String? apnsToken;
        for (var i = 0; i < 10; i++) {
          apnsToken = await _fcm!.getAPNSToken();
          if (apnsToken != null) break;
          await Future.delayed(const Duration(seconds: 1));
        }
        if (apnsToken == null) {
          debugPrint('⚠️ APNS token not available after waiting — skipping FCM setup');
          return;
        }
      }

      // Network calls — run in background
      await Future.wait([
        _fcm!.subscribeToTopic('all_users'),
        _fcm!.getToken().then((token) {
          debugPrint('📱 FCM token: $token');
        }),
      ]);
    } catch (e) {
      debugPrint('⚠️ FCM async init failed: $e');
      _fcm = null;
    }
  }

  /// Requests local notification permissions on iOS and Android.
  ///
  /// Returns `true` if the OS allows posting notifications, `false` otherwise.
  /// When [requestExactAlarmOnAndroid] is true, prompts once for Android exact
  /// alarm permission if not yet granted (a denial never blocks scheduling).
  Future<bool> requestPermissions({
    bool requestExactAlarmOnAndroid = false,
  }) async {
    await init();

    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      final enabled = await androidPlugin?.areNotificationsEnabled() ?? true;

      if (!enabled) {
        return false;
      }

      if (requestExactAlarmOnAndroid) {
        try {
          final canExact =
              await androidPlugin?.canScheduleExactNotifications() ?? false;
          if (!canExact) {
            await androidPlugin?.requestExactAlarmsPermission();
          }
        } catch (e) {
          debugPrint('⚠️ Exact alarm permission request skipped: $e');
        }
      }

      if (_fcm != null) {
        unawaited(
          _fcm!
              .requestPermission(alert: true, badge: true, sound: true)
              .catchError((_) => const NotificationSettings(
                    authorizationStatus: AuthorizationStatus.notDetermined,
                    alert: AppleNotificationSetting.notSupported,
                    announcement: AppleNotificationSetting.notSupported,
                    badge: AppleNotificationSetting.notSupported,
                    carPlay: AppleNotificationSetting.notSupported,
                    lockScreen: AppleNotificationSetting.notSupported,
                    notificationCenter: AppleNotificationSetting.notSupported,
                    showPreviews: AppleShowPreviewSetting.notSupported,
                    timeSensitive: AppleNotificationSetting.notSupported,
                    criticalAlert: AppleNotificationSetting.notSupported,
                    sound: AppleNotificationSetting.notSupported,
                    providesAppNotificationSettings:
                        AppleNotificationSetting.notSupported,
                  )),
        );
      }

      return true;
    }

    if (Platform.isIOS) {
      final iosPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      final status = await iosPlugin?.checkPermissions();
      final enabled = status != null
          ? (status.isEnabled ||
              status.isAlertEnabled ||
              status.isProvisionalEnabled)
          : (granted ?? false);

      if (_fcm != null) {
        unawaited(
          _fcm!
              .requestPermission(alert: true, badge: true, sound: true)
              .catchError((_) => const NotificationSettings(
                    authorizationStatus: AuthorizationStatus.notDetermined,
                    alert: AppleNotificationSetting.notSupported,
                    announcement: AppleNotificationSetting.notSupported,
                    badge: AppleNotificationSetting.notSupported,
                    carPlay: AppleNotificationSetting.notSupported,
                    lockScreen: AppleNotificationSetting.notSupported,
                    notificationCenter: AppleNotificationSetting.notSupported,
                    showPreviews: AppleShowPreviewSetting.notSupported,
                    timeSensitive: AppleNotificationSetting.notSupported,
                    criticalAlert: AppleNotificationSetting.notSupported,
                    sound: AppleNotificationSetting.notSupported,
                    providesAppNotificationSettings:
                        AppleNotificationSetting.notSupported,
                  )),
        );
      }

      return enabled;
    }

    return true;
  }

  /// Checks whether notifications are currently permitted by the OS without
  /// triggering a permission prompt.
  Future<bool> areNotificationsPermitted() async {
    await init();
    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.areNotificationsEnabled() ?? true;
    }
    if (Platform.isIOS) {
      final iosPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final status = await iosPlugin?.checkPermissions();
      if (status == null) return false;
      return status.isEnabled ||
          status.isAlertEnabled ||
          status.isProvisionalEnabled;
    }
    return true;
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _fcmChannelId,
          _fcmChannelName,
          icon: _androidSmallIcon,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(notification.body ?? ''),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
          presentBadge: true,
        ),
      ),
    );
  }

  Future<AndroidScheduleMode> _resolveAndroidScheduleMode() async {
    if (!Platform.isAndroid) return AndroidScheduleMode.inexactAllowWhileIdle;
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final canExact =
        await androidPlugin?.canScheduleExactNotifications() ?? false;
    return canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  NotificationDetails _buildDetails({
    required String channelId,
    required String channelName,
    required String body,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        icon: _androidSmallIcon,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: true,
        presentBadge: true,
      ),
    );
  }

  // ── Local Scheduled Reminders ────────────────────────────────

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await init();
    await _localNotifications.cancel(_reminderNotificationId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (!scheduledDate.isAfter(now)) {
      scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + 1,
        hour,
        minute,
      );
    }

    final scheduleMode = await _resolveAndroidScheduleMode();

    await _localNotifications.zonedSchedule(
      _reminderNotificationId,
      title,
      body,
      scheduledDate,
      _buildDetails(
        channelId: _reminderChannelId,
        channelName: _reminderChannelName,
        body: body,
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelReminder() async {
    await init();
    await _localNotifications.cancel(_reminderNotificationId);
  }

  // ── Scheduled Daily Budget Alerts ────────────────────────────

  Future<void> syncBudgetNotifications(
    List<ScheduledBudgetNotification> items,
  ) async {
    await init();
    await cancelAllBudgetNotifications();
    if (items.isEmpty) return;

    final scheduleMode = await _resolveAndroidScheduleMode();
    final now = tz.TZDateTime.now(tz.local);

    for (final item in items) {
      final d = item.scheduledLocalDateTime;
      final scheduledDate = tz.TZDateTime(
        tz.local,
        d.year,
        d.month,
        d.day,
        d.hour,
        d.minute,
      );
      if (!scheduledDate.isAfter(now)) continue;

      await _localNotifications.zonedSchedule(
        item.id,
        item.title,
        item.body,
        scheduledDate,
        _buildDetails(
          channelId: _budgetChannelId,
          channelName: _budgetChannelName,
          body: item.body,
        ),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelAllBudgetNotifications() async {
    await init();
    await Future.wait([
      for (var i = 0; i < BudgetAlertCalculator.maxHorizonDays; i++)
        _localNotifications
            .cancel(BudgetAlertCalculator.baseNotificationId + i),
    ]);
  }
}

/// Top-level function for handling background FCM messages.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are automatically shown as notifications by FCM.
  // This handler is for any custom processing you want to do.
}
