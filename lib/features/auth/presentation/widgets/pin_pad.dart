import 'package:flutter/material.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';

class PinPad extends StatelessWidget {
  final Function(String) onDigitPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback? onBiometricPressed;
  final bool showBiometric;

  const PinPad({
    super.key,
    required this.onDigitPressed,
    required this.onDeletePressed,
    this.onBiometricPressed,
    this.showBiometric = false,
  });

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDigitButton(context, '1', isLight),
            _buildDigitButton(context, '2', isLight),
            _buildDigitButton(context, '3', isLight),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDigitButton(context, '4', isLight),
            _buildDigitButton(context, '5', isLight),
            _buildDigitButton(context, '6', isLight),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDigitButton(context, '7', isLight),
            _buildDigitButton(context, '8', isLight),
            _buildDigitButton(context, '9', isLight),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            showBiometric
                ? IconButton(
                    onPressed: onBiometricPressed,
                    icon: const Icon(Icons.fingerprint, size: 32),
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.primaryGold,
                    ),
                  )
                : const SizedBox(width: 64, height: 64),
            _buildDigitButton(context, '0', isLight),
            IconButton(
              onPressed: onDeletePressed,
              icon: const Icon(Icons.backspace_outlined, size: 28),
              style: IconButton.styleFrom(
                foregroundColor:
                    isLight ? AppColors.textPrimaryLight : Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDigitButton(BuildContext context, String digit, bool isLight) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isLight
            ? Colors.black.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.1),
        border: Border.all(
          color: isLight
              ? Colors.black.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => onDigitPressed(digit),
          child: Center(
            child: Text(
              digit,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isLight ? AppColors.textPrimaryLight : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
