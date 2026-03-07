import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'features/auth/presentation/widgets/app_lock_overlay.dart';
import 'features/splash/presentation/screens/splash_screen.dart';
import 'shared/theme/app_theme.dart';
import 'core/providers/profile_provider.dart';
import 'core/services/sync_service.dart';
import 'core/services/remote_config_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/iap_service.dart';
import 'core/services/premium_auth_service.dart';

void main() async {
  final totalSw = Stopwatch()..start();

  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    // Tell sqlite3 to load libsqlcipher.so instead of libsqlite3.so.
    // Do NOT call applyWorkaroundToOpenSqlCipherOnOldAndroidVersions() here —
    // that forces DynamicLibrary.open('libsqlcipher.so') at startup which
    // blocks early and can interfere with Flutter's network initialization.
    // The workaround is called only when the database is first opened.
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
  }

  await initializeDateFormatting();

  // Lock orientation to portrait
  // await SystemChrome.setPreferredOrientations([
  //   DeviceOrientation.portraitUp,
  //   DeviceOrientation.portraitDown,
  // ]);

  // Initialize Firebase first — everything depends on it.
  try {
    var sw = Stopwatch()..start();
    await Firebase.initializeApp();
    debugPrint('⏱️ [main] Firebase: ${sw.elapsedMilliseconds}ms');
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Parallel — all independent. Network-heavy parts of Notifications and
    // PremiumAuth are fire-and-forget internally, so they resolve fast.
    // MobileAds moved out (conditional on RemoteConfig).
    int rcMs = 0, notifMs = 0, iapMs = 0, supaMs = 0, premMs = 0;
    sw = Stopwatch()..start();
    await Future.wait([
      () async { final s = Stopwatch()..start(); await RemoteConfigService().init(); rcMs = s.elapsedMilliseconds; }(),
      () async { final s = Stopwatch()..start(); await NotificationService().init(); notifMs = s.elapsedMilliseconds; }(),
      () async { final s = Stopwatch()..start(); await IapService().init(); iapMs = s.elapsedMilliseconds; }(),
      () async { final s = Stopwatch()..start(); await SyncService.initialize(); supaMs = s.elapsedMilliseconds; }(),
      () async { final s = Stopwatch()..start(); await PremiumAuthService().init(); premMs = s.elapsedMilliseconds; }(),
    ]);
    debugPrint('⏱️ [main] Parallel group done: ${sw.elapsedMilliseconds}ms');
    debugPrint('⏱️   ├─ RemoteConfig: ${rcMs}ms');
    debugPrint('⏱️   ├─ Notifications: ${notifMs}ms');
    debugPrint('⏱️   ├─ IAP: ${iapMs}ms');
    debugPrint('⏱️   ├─ Supabase: ${supaMs}ms');
    debugPrint('⏱️   └─ PremiumAuth: ${premMs}ms');

    // Phase 3: Conditional — only init MobileAds if ads are enabled via RemoteConfig.
    if (RemoteConfigService().adsEnabled) {
      sw = Stopwatch()..start();
      await MobileAds.instance.initialize();
      debugPrint('⏱️ [main] MobileAds: ${sw.elapsedMilliseconds}ms');
    } else {
      debugPrint('⏱️ [main] MobileAds: SKIPPED (ads disabled)');
    }
  } catch (e) {
    debugPrint('⚠️ Init error: $e');
  }

  debugPrint('⏱️ [main] Total before runApp(): ${totalSw.elapsedMilliseconds}ms');

  runApp(
    const ProviderScope(
      child: RichTogetherApp(),
    ),
  );
}

class RichTogetherApp extends ConsumerWidget {
  const RichTogetherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the theme mode from settings
    final themeMode = ref.watch(themeModeProvider);
    
    return MaterialApp(
      title: 'Rich Together',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const SplashScreen(),
      builder: (context, child) => AppLockOverlay(child: child!),
    );
  }
}
