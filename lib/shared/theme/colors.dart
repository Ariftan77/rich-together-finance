import 'package:flutter/material.dart';

class AppColors {
  // Primary & Accent
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color primaryGoldAccent = Color(0xFFEEB42B);
  static const Color deepBlue = Color(0xFF1F3B61);

  // Backgrounds
  static const Color bgDarkStart = Color(0xFF0F172A);
  static const Color bgDarkEnd = Color(0xFF221D10);
  
  // Status
  static const Color success = Color(0xFF2ECC71);
  static const Color error = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF1C40F);
  static const Color info = Color(0xFF3498DB);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF); // 70% opacity
  static const Color textTertiary = Color(0x80FFFFFF);  // 50% opacity

  // Glass / Overlay
  static const Color glassBorder = Color(0x1AFFFFFF);   // 10% opacity
  static const Color glassBackground = Color(0x1AFFFFFF); // 10% opacity
  static const Color surface = Color(0xFF1E293B);
  static const Color cardSurface = Color(0xFF1E293B); // Same as surface for now
}
