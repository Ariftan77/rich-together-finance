import 'package:flutter/material.dart';

/// App-specific theme modes (not Flutter's ThemeMode)
enum AppThemeMode {
  defaultTheme, // 0 - warm brown/gold glassmorphism (original app look)
  dark,         // 1 - true AMOLED black
  light,        // 2 - white/light gray
  system,       // 3 - auto switch between dark and light based on system
}

extension AppThemeModeX on AppThemeMode {
  int get value => index;

  static AppThemeMode fromValue(int value) {
    if (value >= 0 && value < AppThemeMode.values.length) {
      return AppThemeMode.values[value];
    }
    return AppThemeMode.defaultTheme;
  }

  String get label {
    switch (this) {
      case AppThemeMode.defaultTheme:
        return 'Default';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.system:
        return 'System';
    }
  }

  IconData get icon {
    switch (this) {
      case AppThemeMode.defaultTheme:
        return Icons.palette_outlined;
      case AppThemeMode.dark:
        return Icons.dark_mode_outlined;
      case AppThemeMode.light:
        return Icons.light_mode_outlined;
      case AppThemeMode.system:
        return Icons.settings_brightness_outlined;
    }
  }

  /// Maps to the Flutter ThemeMode used by MaterialApp.
  /// Default and Dark both use dark ThemeMode, Light uses light, System follows system.
  ThemeMode toFlutterThemeMode() {
    switch (this) {
      case AppThemeMode.defaultTheme:
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}
