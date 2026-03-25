import 'package:flutter/material.dart';
import '../theme/app_theme_mode.dart';
import '../theme/colors.dart';
import '../theme/theme_provider_widget.dart';
import 'glass_card.dart';

enum GlassButtonSize { small, medium, large }

class GlassButton extends StatelessWidget {
  final String? text;
  final Widget? child;
  final VoidCallback onPressed;
  final IconData? icon;
  final GlassButtonSize size;
  final bool isPrimary;
  final bool isFullWidth;
  final bool isLoading;

  const GlassButton({
    super.key,
    this.text,
    this.child,
    required this.onPressed,
    this.icon,
    this.size = GlassButtonSize.medium,
    this.isPrimary = true,
    this.isFullWidth = false,
    this.isLoading = false,
  }) : assert(text != null || child != null, 'Either text or child must be provided');

  @override
  Widget build(BuildContext context) {
    final double paddingVertical = _getPaddingVertical();
    final double paddingHorizontal = _getPaddingHorizontal();
    final TextStyle textStyle = _getTextStyle(context);

    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

    // Secondary button surface: light=light glass, default+dark=warm/dark glass
    final Color bgColor = isPrimary
        ? AppColors.primaryGold.withValues(alpha: 0.8)
        : (isLight ? AppColors.glassBackgroundLight : AppColors.glassBackground);
    final Color borderColor = isPrimary
        ? AppColors.primaryGoldAccent.withValues(alpha: 0.5)
        : (isLight ? AppColors.glassBorderLight : AppColors.glassBorder);

    // Content text/icon color for secondary: light=dark text, default+dark=white
    final Color secondaryContentColor = isLight
        ? AppColors.textPrimaryLight
        : AppColors.textPrimary;

    Widget content;

    if (isLoading) {
      content = SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            isPrimary ? Colors.black : secondaryContentColor,
          ),
        ),
      );
    } else if (child != null) {
      content = child!;
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: isPrimary ? Colors.black : secondaryContentColor,
              size: 20,
            ),
            const SizedBox(width: 8),
          ],
          Text(
            text!,
            style: textStyle.copyWith(
              color: isPrimary ? Colors.black : secondaryContentColor,
            ),
          ),
        ],
      );
    }

    if (isFullWidth) {
      content = Center(child: content);
    }

    // Determine the accessibility label: prefer the explicit text, fall back to
    // nothing (callers using [child] should wrap their own Semantics if needed).
    final String? semanticLabel = text;

    return Semantics(
      button: true,
      enabled: !isLoading,
      label: isLoading ? '${semanticLabel ?? 'Button'}, loading' : semanticLabel,
      child: GestureDetector(
        onTap: isLoading ? null : onPressed,
        child: GlassCard(
          borderRadius: 32, // More rounded for buttons
          backgroundColor: bgColor,
          borderColor: borderColor,
          padding: EdgeInsets.symmetric(
            vertical: paddingVertical,
            horizontal: paddingHorizontal,
          ),
          width: isFullWidth ? double.infinity : null,
          child: content,
        ),
      ),
    );
  }

  double _getPaddingVertical() {
    switch (size) {
      case GlassButtonSize.small: return 8;
      case GlassButtonSize.medium: return 12;
      case GlassButtonSize.large: return 16;
    }
  }

  double _getPaddingHorizontal() {
    switch (size) {
      case GlassButtonSize.small: return 16;
      case GlassButtonSize.medium: return 24;
      case GlassButtonSize.large: return 32;
    }
  }

  TextStyle _getTextStyle(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.labelLarge!;
    switch (size) {
      case GlassButtonSize.small:
        return baseStyle.copyWith(fontSize: 12);
      case GlassButtonSize.medium:
        return baseStyle.copyWith(fontSize: 14);
      case GlassButtonSize.large:
        return baseStyle.copyWith(fontSize: 16);
    }
  }
}
