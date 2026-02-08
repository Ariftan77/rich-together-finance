import 'package:flutter/material.dart';
import '../theme/colors.dart';

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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.glassBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (shouldHighlight
                          ? AppColors.primaryGold.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.1))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected
                        ? (shouldHighlight ? AppColors.primaryGold : Colors.white)
                        : Colors.white.withValues(alpha: 0.4),
                    fontSize: 14,
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
