import 'package:flutter/material.dart';
import '../theme/app_theme_mode.dart';
import '../theme/colors.dart';
import '../theme/theme_provider_widget.dart';

class FabButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;

  const FabButton({
    super.key,
    required this.onPressed,
    this.icon = Icons.add,
  });

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

    // Bake opacity directly into gradient colors to avoid Opacity compositing layer.
    // Light mode uses a slightly reduced opacity; default+dark use their own values.
    final double fabAlpha = isLight ? 0.75 : 0.5;
    final double shadowAlpha = isLight ? 0.25 : 0.4;

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGold.withValues(alpha: fabAlpha),
            AppColors.primaryGoldAccent.withValues(alpha: fabAlpha),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGold.withValues(alpha: shadowAlpha),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(32),
          child: Icon(
            icon,
            color: AppColors.deepBlue,
            size: 32,
          ),
        ),
      ),
    );
  }
}
