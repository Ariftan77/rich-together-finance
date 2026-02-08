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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDigitButton('1'),
            _buildDigitButton('2'),
            _buildDigitButton('3'),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDigitButton('4'),
            _buildDigitButton('5'),
            _buildDigitButton('6'),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDigitButton('7'),
            _buildDigitButton('8'),
            _buildDigitButton('9'),
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
            _buildDigitButton('0'),
            IconButton(
              onPressed: onDeletePressed,
              icon: const Icon(Icons.backspace_outlined, size: 28),
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDigitButton(String digit) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.1),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => onDigitPressed(digit),
          child: Center(
            child: Text(
              digit,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
