import 'package:flutter/material.dart';
import '../theme/colors.dart';

class FabButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;

  const FabButton({
    super.key,
    required this.onPressed,
    this.icon = Icons.add,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryGold, AppColors.primaryGoldAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGold.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(32),
          child: Icon(
            icon,
            color: AppColors.deepBlue,
            size: 32,
          ),
        ),
      ),
    );
  }
}
