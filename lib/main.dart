import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'features/splash/presentation/screens/splash_screen.dart';
import 'shared/theme/app_theme.dart';
import 'core/providers/profile_provider.dart';
import 'core/services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  
  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Supabase
  await SyncService.initialize();

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
