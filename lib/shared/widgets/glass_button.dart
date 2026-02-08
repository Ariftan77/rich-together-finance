import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'glass_card.dart';

enum GlassButtonSize { small, medium, large }

class GlassButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final GlassButtonSize size;
  final bool isPrimary;
  final bool isFullWidth;
  final bool isLoading;

  const GlassButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.size = GlassButtonSize.medium,
    this.isPrimary = true,
    this.isFullWidth = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // ... existing variable declarations ...
    final double paddingVertical = _getPaddingVertical();
    final double paddingHorizontal = _getPaddingHorizontal();
    final TextStyle textStyle = _getTextStyle(context);
    final Color bgColor = isPrimary 
        ? AppColors.primaryGold.withValues(alpha: 0.8) 
        : AppColors.glassBackground;
    final Color borderColor = isPrimary 
        ? AppColors.primaryGoldAccent.withValues(alpha: 0.5) 
        : AppColors.glassBorder;

    Widget content;
    
    if (isLoading) {
      content = SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            isPrimary ? Colors.black : Colors.white
          ),
        ),
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.textPrimary, size: 20),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: textStyle,
          ),
        ],
      );
    }
    
    if (isFullWidth) {
      content = Center(child: content);
    }

    return GestureDetector(
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
