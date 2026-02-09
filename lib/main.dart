import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'features/auth/presentation/auth_wrapper.dart';
import 'shared/theme/app_theme.dart';
import 'core/providers/profile_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

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
      home: const AuthWrapper(),
    );
  }
}
