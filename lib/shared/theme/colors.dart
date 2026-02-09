import 'package:flutter/material.dart';

class AppColors {
  // Primary & Accent
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color primaryGoldAccent = Color(0xFFEEB42B);
  static const Color deepBlue = Color(0xFF1F3B61);

  // ===== DARK THEME COLORS =====
  // Backgrounds
  static const Color bgDarkStart = Color(0xFF0F172A);
  static const Color bgDarkEnd = Color(0xFF221D10);
  
  // Status
  static const Color success = Color(0xFF2ECC71);
  static const Color error = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF1C40F);
  static const Color info = Color(0xFF3498DB);

  // Text - Dark Theme
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF); // 70% opacity
  static const Color textTertiary = Color(0x80FFFFFF);  // 50% opacity

  // Glass / Overlay - Dark Theme
  static const Color glassBorder = Color(0x1AFFFFFF);   // 10% opacity
  static const Color glassBackground = Color(0x1AFFFFFF); // 10% opacity
  static const Color surface = Color(0xFF1E293B);
  static const Color cardSurface = Color(0xFF1E293B);

  // ===== LIGHT THEME COLORS =====
  // Backgrounds - Light
  static const Color bgLightStart = Color(0xFFF8FAFC);
  static const Color bgLightEnd = Color(0xFFFFFBEB);
  
  // Text - Light Theme  
  static const Color textPrimaryLight = Color(0xFF1E293B);
  static const Color textSecondaryLight = Color(0xB31E293B); // 70% opacity
  static const Color textTertiaryLight = Color(0x801E293B);  // 50% opacity

  // Glass / Overlay - Light Theme
  static const Color glassBorderLight = Color(0x1A000000);   // 10% opacity black
  static const Color glassBackgroundLight = Color(0x1A000000); // 10% opacity black
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardSurfaceLight = Color(0xFFF1F5F9);
  static const LinearGradient mainGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2C5282), // #2c5282 0%
      Color(0xFF1F3B61), // #1f3b61 40%
      Color(0xFF8E792A), // #8e792a 120%
    ],
    stops: [0.0, 0.4, 1.0], // Approximate stops from CSS
  );
}
