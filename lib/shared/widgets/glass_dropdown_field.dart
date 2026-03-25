import 'package:flutter/material.dart';
import '../theme/app_theme_mode.dart';
import '../theme/colors.dart';
import '../theme/theme_provider_widget.dart';

/// A glass-styled dropdown field with icon prefix and chevron suffix
class GlassDropdownField<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;

  const GlassDropdownField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;

    // Label color
    final Color labelColor = isLight
        ? const Color(0xFF64748B)
        : Colors.white.withValues(alpha: 0.6);

    // Container fill
    final Color containerBg = isLight
        ? Colors.black.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.05);

    // Container border
    final Color containerBorder = isLight
        ? Colors.black.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.15);

    // Hint text color
    final Color hintColor = isLight
        ? const Color(0xFF94A3B8)
        : Colors.white.withValues(alpha: 0.4);

    // Dropdown popup background:
    // default=warm dark, dark=true black, light=white
    final Color dropdownBg = isDefault
        ? const Color(0xFF221D10)
        : isLight
            ? Colors.white
            : const Color(0xFF111111);

    // Selected value text color
    final Color valueTextColor = isLight ? AppColors.textPrimaryLight : Colors.white;

    // Chevron icon color
    final Color chevronColor = isLight
        ? const Color(0xFFCBD5E1)
        : Colors.white.withValues(alpha: 0.3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: labelColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: containerBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: containerBorder),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: AppColors.primaryGold.withValues(alpha: 0.8),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<T>(
                    value: value,
                    items: items,
                    onChanged: onChanged,
                    hint: hint != null
                        ? Text(
                            hint!,
                            style: TextStyle(
                              color: hintColor,
                              fontSize: 15,
                            ),
                          )
                        : null,
                    isExpanded: true,
                    dropdownColor: dropdownBg,
                    style: TextStyle(
                      color: valueTextColor,
                      fontSize: 15,
                    ),
                    icon: Icon(
                      Icons.expand_more,
                      color: chevronColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
