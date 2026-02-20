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
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  
  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase first so AdMob can integrate with it.
  try {
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized');
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await RemoteConfigService().init();
    await NotificationService().init();
    await IapService().init();
  } catch (e) {
    debugPrint('⚠️ Firebase init skipped (missing config?): $e');
  }

  // Initialize AdMob after Firebase so it can detect Firebase and suppress the warning.
  await MobileAds.instance.initialize();
  debugPrint('✅ MobileAds initialized');

  // Initialize Supabase
  await SyncService.initialize();

  // Restore premium session after Supabase is ready
  await PremiumAuthService().init();

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
