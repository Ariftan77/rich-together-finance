import 'package:flutter/material.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/theme/colors.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDigitButton('1', isDark),
            _buildDigitButton('2', isDark),
            _buildDigitButton('3', isDark),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDigitButton('4', isDark),
            _buildDigitButton('5', isDark),
            _buildDigitButton('6', isDark),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDigitButton('7', isDark),
            _buildDigitButton('8', isDark),
            _buildDigitButton('9', isDark),
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
            _buildDigitButton('0', isDark),
            IconButton(
              onPressed: onDeletePressed,
              icon: const Icon(Icons.backspace_outlined, size: 28),
              style: IconButton.styleFrom(
                foregroundColor:
                    isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDigitButton(String digit, bool isDark) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.08),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.12),
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
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
