import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/colors.dart';

class GlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<BottomNavItem> items;

  const GlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
      height: 80,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: isDark ? 16 : 20,
            sigmaY: isDark ? 16 : 20,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.glassBackground
                  : Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDark
                    ? AppColors.glassBorder
                    : Colors.black.withValues(alpha: 0.1),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: items.map((item) {
                final int index = items.indexOf(item);
                final bool isSelected = currentIndex == index;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(index),
                    child: Container(
                      color: Colors.transparent,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryGold.withValues(alpha: isDark ? 0.2 : 0.15)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isSelected ? item.activeIcon : item.icon,
                              color: isSelected
                                  ? AppColors.primaryGold
                                  : isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.label,
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.primaryGold
                                  : isDark ? AppColors.textSecondary : const Color(0xFF64748B),
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class BottomNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
