import 'package:flutter/material.dart';
import 'app_theme_mode.dart';

/// InheritedWidget that provides [AppThemeMode] to the entire widget tree.
/// Wrap the MaterialApp child with this so every widget can call
/// [AppThemeProvider.of(context)] to get the current theme mode.
class AppThemeProvider extends InheritedWidget {
  final AppThemeMode themeMode;

  const AppThemeProvider({
    super.key,
    required this.themeMode,
    required super.child,
  });

  /// Returns the current [AppThemeMode] from the nearest [AppThemeProvider]
  /// ancestor. Falls back to [AppThemeMode.defaultTheme] if none is found.
  static AppThemeMode of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<AppThemeProvider>();
    return provider?.themeMode ?? AppThemeMode.defaultTheme;
  }

  /// Convenience: returns true when the resolved theme mode means light text
  /// on light background (i.e. the user picked Light or System resolved to
  /// light). All other modes (Default warm, Dark AMOLED) use dark/warm
  /// backgrounds with white text.
  static bool isLightMode(BuildContext context) {
    final mode = of(context);
    if (mode == AppThemeMode.light) return true;
    if (mode == AppThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.light;
    }
    return false;
  }

  @override
  bool updateShouldNotify(AppThemeProvider oldWidget) =>
      themeMode != oldWidget.themeMode;
}
