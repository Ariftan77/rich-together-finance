import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryGold,
        secondary: AppColors.deepBlue,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.bgDarkStart, // Default, but we'll use gradients
      textTheme: AppTypography.textTheme,
      iconTheme: const IconThemeData(
        color: AppColors.textPrimary,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.glassBorder,
        thickness: 1,
      ),
    );
  }
}
