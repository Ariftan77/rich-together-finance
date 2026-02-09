import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'glass_card.dart';

class GlassInput extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final IconData? prefixIcon;
  final String? prefixText;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final int? maxLines;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;

  const GlassInput({
    super.key,
    this.controller,
    required this.hintText,
    this.prefixIcon,
    this.prefixText,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.autofocus = false,
    this.inputFormatters,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          borderRadius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLength: maxLength,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null, // Hide counter text but keep enforcement? Or show it? TextFields usually show it.
            // If I want to hide it I can return null.
            // But for PIN, maybe no counter is better if I visualy restrict.
            // Let's keep default behavior for now or hide it?
            // "maxLength: 6" usually shows "0/6".
            // I'll stick to standard behavior or hiding it if it looks bad in GlassCard.
            // Let's just pass maxLength.
            style: AppTypography.textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? AppColors.textPrimary 
                  : AppColors.textPrimaryLight,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: AppTypography.textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? AppColors.textTertiary 
                    : AppColors.textTertiaryLight,
              ),
              prefixIcon: prefixIcon != null 
                  ? Icon(prefixIcon, color: Theme.of(context).brightness == Brightness.dark 
                      ? AppColors.textSecondary 
                      : AppColors.textSecondaryLight) 
                  : null,
              prefixText: prefixText,
              prefixStyle: AppTypography.textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? AppColors.textPrimary 
                      : AppColors.textPrimaryLight,
                  fontWeight: FontWeight.bold,
              ),
              suffixIcon: suffixIcon,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            validator: validator,
            onChanged: onChanged,
            maxLines: maxLines,
            autofocus: autofocus,
          ),
        ),
      ],
    );
  }
}
