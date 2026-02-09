import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final Gradient? borderGradient;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 24.0,
    this.backgroundColor,
    this.borderColor,
    this.borderGradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.transparent, // Ensure container is transparent so blur shows
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: padding ?? const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: backgroundColor ?? (Theme.of(context).brightness == Brightness.dark 
                    ? AppColors.glassBackground 
                    : AppColors.glassBackgroundLight),
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: borderColor ?? (Theme.of(context).brightness == Brightness.dark 
                      ? AppColors.glassBorder 
                      : AppColors.glassBorderLight),
                  width: 1.0,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
