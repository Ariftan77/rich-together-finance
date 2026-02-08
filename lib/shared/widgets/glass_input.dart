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
            style: AppTypography.textTheme.bodyLarge?.copyWith(
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: AppTypography.textTheme.bodyMedium?.copyWith(
                color: AppColors.textTertiary,
              ),
              prefixIcon: prefixIcon != null 
                  ? Icon(prefixIcon, color: AppColors.textSecondary) 
                  : null,
              prefixText: prefixText,
              prefixStyle: AppTypography.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
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
