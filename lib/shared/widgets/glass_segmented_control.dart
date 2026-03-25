import 'package:flutter/material.dart';
import '../theme/app_theme_mode.dart';
import '../theme/colors.dart';
import '../theme/theme_provider_widget.dart';

/// A glass-styled segmented control for selecting between multiple options
class GlassSegmentedControl<T> extends StatelessWidget {
  final T value;
  final List<T> options;
  final List<String> labels;
  final ValueChanged<T> onChanged;
  final T? highlightValue; // Value to highlight with gold color

  const GlassSegmentedControl({
    super.key,
    required this.value,
    required this.options,
    required this.labels,
    required this.onChanged,
    this.highlightValue,
  }) : assert(options.length == labels.length, 'Options and labels must have the same length');

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

    // Container background
    final Color containerBg = isLight
        ? Colors.black.withValues(alpha: 0.04)
        : AppColors.glassBackground;

    // Container border
    final Color containerBorder = isLight
        ? Colors.black.withValues(alpha: 0.1)
        : Colors.white.withValues(alpha: 0.1);

    // Unselected label color
    final Color unselectedColor = isLight
        ? const Color(0xFF94A3B8)
        : Colors.white.withValues(alpha: 0.4);

    // Selected segment highlight alpha
    final double selectedAlpha = isLight ? 0.15 : 0.2;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: containerBorder),
      ),
      child: Row(
        children: List.generate(options.length, (index) {
          final option = options[index];
          final label = labels[index];
          final isSelected = value == option;
          final shouldHighlight = highlightValue != null && option == highlightValue;

          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryGold.withValues(alpha: selectedAlpha)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.primaryGold
                        : unselectedColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
