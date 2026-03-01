import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
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
  await initializeDateFormatting();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase first — everything depends on it.
  try {
    var sw = Stopwatch()..start();
    await Firebase.initializeApp();
    debugPrint('⏱️ [main] Firebase: ${sw.elapsedMilliseconds}ms');
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // These are all independent of each other — run in parallel.
    int rcMs = 0, notifMs = 0, iapMs = 0, adsMs = 0, supaMs = 0;
    sw = Stopwatch()..start();
    await Future.wait([
      () async { final s = Stopwatch()..start(); await RemoteConfigService().init(); rcMs = s.elapsedMilliseconds; }(),
      () async { final s = Stopwatch()..start(); await NotificationService().init(); notifMs = s.elapsedMilliseconds; }(),
      () async { final s = Stopwatch()..start(); await IapService().init(); iapMs = s.elapsedMilliseconds; }(),
      () async { final s = Stopwatch()..start(); await MobileAds.instance.initialize(); adsMs = s.elapsedMilliseconds; }(),
      () async { final s = Stopwatch()..start(); await SyncService.initialize(); supaMs = s.elapsedMilliseconds; }(),
    ]);
    debugPrint('⏱️ [main] Parallel group done: ${sw.elapsedMilliseconds}ms');
    debugPrint('⏱️   ├─ RemoteConfig: ${rcMs}ms');
    debugPrint('⏱️   ├─ Notifications: ${notifMs}ms');
    debugPrint('⏱️   ├─ IAP: ${iapMs}ms');
    debugPrint('⏱️   ├─ MobileAds: ${adsMs}ms');
    debugPrint('⏱️   └─ Supabase: ${supaMs}ms');

    // PremiumAuthService needs Supabase (SyncService) ready first.
    sw = Stopwatch()..start();
    await PremiumAuthService().init();
    debugPrint('⏱️ [main] PremiumAuth: ${sw.elapsedMilliseconds}ms');
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
    );
  }
}
