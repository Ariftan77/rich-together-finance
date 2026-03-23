import 'package:flutter/material.dart';
import 'app_theme_mode.dart';
import 'theme_provider_widget.dart';

class AppColors {
  // Primary & Accent
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color primaryGoldAccent = Color(0xFFEEB42B);
  static const Color deepBlue = Color(0xFF1F3B61);

  // ===== DEFAULT (WARM) THEME COLORS =====
  // Backgrounds
  static const Color bgDarkStart = Color(0xFF0F172A);
  static const Color bgDarkEnd = Color(0xFF221D10);

  // Status
  static const Color success = Color(0xFF2ECC71);
  static const Color error = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF1C40F);
  static const Color info = Color(0xFF3498DB);

  // Text - Default/Dark Theme (white on dark backgrounds)
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF); // 70% opacity
  static const Color textTertiary = Color(0x80FFFFFF);  // 50% opacity

  // Glass / Overlay - Default/Dark Theme
  static const Color glassBorder = Color(0x1AFFFFFF);    // 10% opacity
  static const Color glassBackground = Color(0x1AFFFFFF); // 10% opacity
  static const Color surface = Color(0xFF1E293B);
  static const Color cardSurface = Color(0xFF1E293B);

  // ===== AMOLED DARK THEME COLORS =====
  static const LinearGradient mainGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF000000), Color(0xFF0A0A0A), Color(0xFF050505)],
    stops: [0.0, 0.4, 1.0],
  );

  // AMOLED dark surface colors
  static const Color surfaceDark = Color(0xFF121212);
  static const Color cardDark = Color(0xFF1A1A1A);
  static const Color cardBorderDark = Color(0xFF2A2A2A);

  // ===== LIGHT THEME COLORS =====
  // Backgrounds - Light
  static const Color bgLightStart = Color(0xFFF8FAFC);
  static const Color bgLightEnd = Color(0xFFFFFBEB);

  // Text - Light Theme
  static const Color textPrimaryLight = Color(0xFF1E293B);
  static const Color textSecondaryLight = Color(0xB31E293B); // 70% opacity
  static const Color textTertiaryLight = Color(0x801E293B);  // 50% opacity

  // Glass / Overlay - Light Theme
  static const Color glassBorderLight = Color(0x1A000000);    // 10% opacity black
  static const Color glassBackgroundLight = Color(0x1A000000); // 10% opacity black
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardSurfaceLight = Color(0xFFF1F5F9);

  /// Shared splash/onboarding background gradient (dark navy -> amber).
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0F172A),
      Color(0xFF171E2E),
      Color(0xFF854D0E),
      Color(0xFFC25400),
    ],
    stops: [0.0, 0.3, 0.8, 1.0],
  );

  /// Default warm brown/gold gradient — the app's signature background.
  static const LinearGradient mainGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2C5282),
      Color(0xFF1F3B61),
      Color(0xFF8E792A),
    ],
    stops: [0.0, 0.4, 1.0],
  );

  static const LinearGradient mainGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFEFF6FF), // very light steel blue
      Color(0xFFF8FAFC), // near-white warm gray
      Color(0xFFFFFBEB), // pale warm cream
    ],
    stops: [0.0, 0.4, 1.0],
  );

  // Light mode status colors (AA-compliant on light backgrounds)
  static const Color successLight = Color(0xFF16A34A);
  static const Color errorLight = Color(0xFFDC2626);
  static const Color warningLight = Color(0xFFD97706);
  static const Color infoLight = Color(0xFF2563EB);

  // Gold text-safe variant for light mode (AA-compliant on white)
  static const Color primaryGoldTextLight = Color(0xFFB8962E);

  // ---------------------------------------------------------------------------
  // Context-aware helpers
  // ---------------------------------------------------------------------------

  /// Returns one of three values based on the current [AppThemeMode].
  /// - [defaultTheme]: warm brown/gold glassmorphism (original app look)
  /// - [dark]:        true AMOLED black
  /// - [light]/[system]: white/light-gray
  ///
  /// Usage:
  /// ```dart
  /// color: AppColors.themed3(context,
  ///   defaultTheme: Colors.white,
  ///   dark: Colors.white,
  ///   light: AppColors.textPrimaryLight,
  /// ),
  /// ```
  static T themed3<T>(
    BuildContext context, {
    required T defaultTheme,
    required T dark,
    required T light,
  }) {
    final mode = AppThemeProvider.of(context);
    switch (mode) {
      case AppThemeMode.defaultTheme:
        return defaultTheme;
      case AppThemeMode.dark:
        return dark;
      case AppThemeMode.light:
        return light;
      case AppThemeMode.system:
        final brightness = MediaQuery.platformBrightnessOf(context);
        return brightness == Brightness.dark ? dark : light;
    }
  }

  /// Shorthand for "not-light" text colours — Default and Dark both use white
  /// text, only Light uses dark text. Equivalent to `themed3` with
  /// `defaultTheme == dark`.
  static Color adaptiveText(
    BuildContext context, {
    Color darkText = textPrimary,
    Color lightText = textPrimaryLight,
  }) {
    return AppThemeProvider.isLightMode(context) ? lightText : darkText;
  }

  /// Returns the gradient for the main background based on theme mode.
  static LinearGradient backgroundGradient(BuildContext context) {
    final mode = AppThemeProvider.of(context);
    switch (mode) {
      case AppThemeMode.defaultTheme:
        return mainGradient;
      case AppThemeMode.dark:
        return mainGradientDark;
      case AppThemeMode.light:
        return mainGradientLight;
      case AppThemeMode.system:
        final brightness = MediaQuery.platformBrightnessOf(context);
        return brightness == Brightness.dark ? mainGradientDark : mainGradientLight;
    }
  }
}
