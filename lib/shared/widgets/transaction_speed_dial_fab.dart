import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/locale_provider.dart';
import '../theme/app_theme_mode.dart';
import '../theme/colors.dart';
import '../theme/theme_provider_widget.dart';

/// A speed-dial FAB that expands to show three transaction type options:
/// Income, Expense, and Transfer.
///
/// The [onSelected] callback receives the index of the tapped option:
///   0 = Income
///   1 = Expense
///   2 = Transfer
///
/// [onOpenChanged] is called whenever the dial opens or closes (true = open).
/// Use a [GlobalKey<TransactionSpeedDialFabState>] to call [close] externally.
class TransactionSpeedDialFab extends ConsumerStatefulWidget {
  final void Function(int optionIndex) onSelected;
  final void Function(bool isOpen)? onOpenChanged;

  const TransactionSpeedDialFab({
    super.key,
    required this.onSelected,
    this.onOpenChanged,
  });

  @override
  ConsumerState<TransactionSpeedDialFab> createState() =>
      TransactionSpeedDialFabState();
}

class TransactionSpeedDialFabState
    extends ConsumerState<TransactionSpeedDialFab>
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
    // Small delay lets the close animation start before navigation.
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

    // Options are declared in order 0=Income, 1=Expense, 2=Transfer so that
    // the [onSelected] index matches the TransactionType mapping in the shell.
    final options = [
      _SpeedDialOption(
        label: trans.entryTypeIncome,
        icon: Icons.arrow_downward_rounded,
        color: const Color(0xFF34D399),
        colorAccent: const Color(0xFF10B981),
      ),
      _SpeedDialOption(
        label: trans.entryTypeExpense,
        icon: Icons.arrow_upward_rounded,
        color: const Color(0xFFFB7185),
        colorAccent: const Color(0xFFF43F5E),
      ),
      _SpeedDialOption(
        label: trans.entryTypeTransfer,
        icon: Icons.swap_horiz_rounded,
        color: const Color(0xFF60A5FA),
        colorAccent: const Color(0xFF3B82F6),
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Mini options rendered top-to-bottom above the FAB.
        // We reverse to show Income at top, Transfer closest to the FAB.
        for (int i = options.length - 1; i >= 0; i--) ...[
          _buildMiniOption(
            option: options[i],
            index: i,
            isLight: isLight,
            // Stagger: item furthest from FAB (Income, i=0) animates first.
            staggerDelay: i * 0.10,
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
    required _SpeedDialOption option,
    required int index,
    required bool isLight,
    required double staggerDelay,
  }) {
    final double fabAlpha = isLight ? 0.85 : 0.65;
    final double shadowAlpha = isLight ? 0.25 : 0.35;

    return AnimatedBuilder(
      animation: _expandAnim,
      builder: (context, child) {
        // Stagger: map [staggerDelay..1.0] into [0..1] for this item.
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
          // Mini circular FAB
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

class _SpeedDialOption {
  final String label;
  final IconData icon;
  final Color color;
  final Color colorAccent;

  const _SpeedDialOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.colorAccent,
  });
}
