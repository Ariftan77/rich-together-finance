import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme_mode.dart';
import '../theme/colors.dart';
import '../theme/theme_provider_widget.dart';

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
  final bool readOnly;
  final TextInputAction? textInputAction;

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
    this.readOnly = false,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

    // Text color: light theme uses dark text, default+dark use white
    final Color textColor = isLight ? AppColors.textPrimaryLight : AppColors.textPrimary;
    final Color hintColor = isLight ? AppColors.textTertiaryLight : AppColors.textTertiary;
    final Color iconColor = isLight ? AppColors.textSecondaryLight : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          borderRadius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextFormField(
            controller: controller,
            readOnly: readOnly,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            inputFormatters: inputFormatters,
            maxLength: maxLength,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: textColor,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: hintColor,
              ),
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, color: iconColor)
                  : null,
              prefixText: prefixText,
              prefixStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: textColor,
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
