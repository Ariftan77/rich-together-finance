import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/locale_provider.dart';
import '../theme/app_theme_mode.dart';
import '../theme/colors.dart';
import '../theme/theme_provider_widget.dart';

/// A speed-dial FAB for the Debt tab that expands to show two options:
///   0 = I Owe (payable)
///   1 = Owed to Me (receivable)
///
/// [onSelected] receives the option index.
/// [onOpenChanged] is called whenever the dial opens or closes (true = open).
class DebtSpeedDialFab extends ConsumerStatefulWidget {
  final void Function(int optionIndex) onSelected;
  final void Function(bool isOpen)? onOpenChanged;

  const DebtSpeedDialFab({
    super.key,
    required this.onSelected,
    this.onOpenChanged,
  });

  @override
  ConsumerState<DebtSpeedDialFab> createState() => DebtSpeedDialFabState();
}

class DebtSpeedDialFabState extends ConsumerState<DebtSpeedDialFab>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late final AnimationController _controller;
  late final Animation<double> _expandAnim;
  late final Animation<double> _rotateAnim;

  bool get isOpen => _isOpen;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expandAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _rotateAnim = Tween<double>(begin: 0.0, end: 0.375).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void toggle() {
    HapticFeedback.lightImpact();
    final nowOpen = !_isOpen;
    setState(() => _isOpen = nowOpen);
    if (nowOpen) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    widget.onOpenChanged?.call(nowOpen);
  }

  void close() {
    if (!_isOpen) return;
    setState(() => _isOpen = false);
    _controller.reverse();
    widget.onOpenChanged?.call(false);
  }

  void _handleOptionTap(int index) {
    close();
    Future.delayed(const Duration(milliseconds: 120), () {
      widget.onSelected(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final trans = ref.watch(translationsProvider);
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

    final double fabAlpha = isLight ? 0.75 : 0.5;
    final double shadowAlpha = isLight ? 0.25 : 0.4;

    final options = [
      _DebtDialOption(
        label: trans.debtPayable,
        icon: Icons.arrow_upward_rounded,
        color: const Color(0xFFFB7185),
        colorAccent: const Color(0xFFF43F5E),
      ),
      _DebtDialOption(
        label: trans.debtReceivable,
        icon: Icons.arrow_downward_rounded,
        color: const Color(0xFF34D399),
        colorAccent: const Color(0xFF10B981),
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (int i = options.length - 1; i >= 0; i--) ...[
          _buildMiniOption(
            option: options[i],
            index: i,
            isLight: isLight,
            staggerDelay: i * 0.15,
          ),
          const SizedBox(height: 12),
        ],

        // Main FAB
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryGold.withValues(alpha: fabAlpha),
                AppColors.primaryGoldAccent.withValues(alpha: fabAlpha),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGold.withValues(alpha: shadowAlpha),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: toggle,
              borderRadius: BorderRadius.circular(32),
              child: AnimatedBuilder(
                animation: _rotateAnim,
                builder: (context, child) => Transform.rotate(
                  angle: _rotateAnim.value * 2 * 3.14159265,
                  child: child,
                ),
                child: const Icon(
                  Icons.add,
                  color: AppColors.deepBlue,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniOption({
    required _DebtDialOption option,
    required int index,
    required bool isLight,
    required double staggerDelay,
  }) {
    final double fabAlpha = isLight ? 0.85 : 0.65;
    final double shadowAlpha = isLight ? 0.25 : 0.35;

    return AnimatedBuilder(
      animation: _expandAnim,
      builder: (context, child) {
        final rangeSize = 1.0 - staggerDelay;
        final localT = rangeSize > 0
            ? ((_expandAnim.value - staggerDelay) / rangeSize).clamp(0.0, 1.0)
            : _expandAnim.value;
        final translateY = (1.0 - localT) * 14.0;

        return Transform.translate(
          offset: Offset(0, translateY),
          child: Opacity(
            opacity: localT,
            child: IgnorePointer(
              ignoring: !_isOpen,
              child: child,
            ),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.white.withValues(alpha: 0.92)
                  : Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.14),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              option.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isLight
                    ? AppColors.textPrimaryLight
                    : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Mini circular button
          GestureDetector(
            onTap: () => _handleOptionTap(index),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    option.color.withValues(alpha: fabAlpha),
                    option.colorAccent.withValues(alpha: fabAlpha),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: option.color.withValues(alpha: shadowAlpha),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: option.color.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                option.icon,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtDialOption {
  final String label;
  final IconData icon;
  final Color color;
  final Color colorAccent;

  const _DebtDialOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.colorAccent,
  });
}
