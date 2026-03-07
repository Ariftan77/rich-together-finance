import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
// ignore: depend_on_referenced_packages
import 'package:timezone/timezone.dart' as tz;
// ignore: depend_on_referenced_packages
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  static final NotificationService _i = NotificationService._();
  factory NotificationService() => _i;
  NotificationService._();

  final _localNotifications = FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _fcm;

  static const _reminderChannelId = 'daily_reminder';
  static const _reminderChannelName = 'Daily Reminder';
  static const _fcmChannelId = 'push_notifications';
  static const _fcmChannelName = 'Push Notifications';
  static const _reminderNotificationId = 100;

  Future<void> init() async {
    // Initialize timezone
    tz.initializeTimeZones();
    final timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(settings);

    // ── Create notification channels eagerly (Android 8+) ──────
    // Ensures the app appears in system notification settings immediately.
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
            _fcmChannelId,
            _fcmChannelName,
            importance: Importance.high,
          ),
        );
      }
    }

    // ── FCM Setup (non-blocking) ───────────────────────────────
    // Topic subscription & token fetch are network calls — not needed at startup.
    // Fire-and-forget so they don't block main().
    _initFcmAsync();
  }

  void _initFcmAsync() async {
    try {
      _fcm = FirebaseMessaging.instance;

      // Handle foreground messages (sync, no network)
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

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

  Future<void> requestPermissions({bool pushOnly = false}) async {
    // Request via local notifications plugin (Android 13+ POST_NOTIFICATIONS).
    // This works independently of FCM initialization state.
    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }

    // Also request via FCM (covers iOS + additional Android logic)
    if (_fcm != null) {
      await _fcm!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    // Show as local notification when app is in foreground
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _fcmChannelId,
          _fcmChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
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
    await cancelReminder();

    if (Platform.isAndroid) {
      final status = await Permission.scheduleExactAlarm.status;
      if (!status.isGranted) {
        final result = await Permission.scheduleExactAlarm.request();
        if (!result.isGranted) {
          debugPrint('Exact alarms permission denied. Cannot schedule daily reminder.');
          return;
        }
      }
    }

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _localNotifications.zonedSchedule(
      _reminderNotificationId,
      title,
      body,
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannelId,
          _reminderChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeats daily
    );
  }

  Future<void> cancelReminder() async {
    await _localNotifications.cancel(_reminderNotificationId);
  }
}

/// Top-level function for handling background FCM messages.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are automatically shown as notifications by FCM.
  // This handler is for any custom processing you want to do.

}
