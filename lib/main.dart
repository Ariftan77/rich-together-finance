import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'features/auth/presentation/widgets/app_lock_overlay.dart';
import 'features/splash/presentation/screens/splash_screen.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/theme_provider_widget.dart';
import 'core/providers/profile_provider.dart';
import 'core/services/notification_service.dart';
import 'core/services/sync_service.dart';

void main() async {
  final totalSw = Stopwatch()..start();

  WidgetsFlutterBinding.ensureInitialized();

  // Enable edge-to-edge on Android 15+ (SDK 35). This prevents Flutter from
  // calling the deprecated setStatusBarColor / setNavigationBarColor APIs and
  // opts into the modern WindowInsetsController approach instead.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

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
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('⏱️ [main] Firebase: ${sw.elapsedMilliseconds}ms');
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Enable analytics collection first — must be committed to the native layer
    // before any logEvent call is made. Running this inside Future.wait created
    // a race where the native "collection enabled" flag was not yet applied when
    // logEvent calls arrived from the parallel group.
    sw = Stopwatch()..start();
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    debugPrint('⏱️ [main] Analytics collection enabled: ${sw.elapsedMilliseconds}ms');

    var sw2 = Stopwatch()..start();
    await SyncService.initialize();
    debugPrint('⏱️ [main] Supabase: ${sw2.elapsedMilliseconds}ms');

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
    final appThemeMode = ref.watch(appThemeModeProvider);

    return AppThemeProvider(
      themeMode: appThemeMode,
      child: MaterialApp(
        title: 'Rich Together',
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const SplashScreen(),
        builder: (context, child) => AppLockOverlay(child: child!),
      ),
    );
  }
}
