import 'package:flutter/material.dart';
import '../theme/colors.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
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
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
            ),
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
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 15,
                            ),
                          )
                        : null,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF221D10),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                    icon: Icon(
                      Icons.expand_more,
                      color: Colors.white.withValues(alpha: 0.3),
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
