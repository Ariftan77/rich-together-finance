import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/date_providers.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../shared/theme/colors.dart';
import 'pin_pad.dart';

/// Full-screen lock overlay shown when app resumes from background.
/// Sits above all routes via MaterialApp.builder.
class AppLockOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const AppLockOverlay({super.key, required this.child});

  @override
  ConsumerState<AppLockOverlay> createState() => _AppLockOverlayState();
}

class _AppLockOverlayState extends ConsumerState<AppLockOverlay>
    with WidgetsBindingObserver {
  bool _isLocked = false;
  String _pin = '';
  String _message = 'Enter PIN';
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _lockIfAuthEnabled();
    } else if (state == AppLifecycleState.resumed) {
      // Refresh current date in case the calendar day changed while backgrounded
      final now = DateTime.now();
      final newDate = DateTime(now.year, now.month, now.day);
      if (newDate != ref.read(currentDateProvider)) {
        ref.read(currentDateProvider.notifier).state = newDate;
      }
      // Try biometric auto-unlock on resume
      if (_isLocked) _tryBiometricUnlock();
    }
  }

  Future<void> _lockIfAuthEnabled() async {
    final authService = ref.read(authServiceProvider);
    final hasPin = await authService.hasPin();
    final isEnabled = await authService.isAuthEnabled();

    if (hasPin && isEnabled && mounted) {
      final bioEnabled = await authService.isBiometricEnabled();
      setState(() {
        _isLocked = true;
        _pin = '';
        _message = 'Enter PIN';
        _biometricEnabled = bioEnabled;
      });
    }
  }

  Future<void> _tryBiometricUnlock() async {
    if (!_biometricEnabled) return;

    final authService = ref.read(authServiceProvider);
    final success = await authService.authenticateWithBiometrics();
    if (success && mounted) {
      setState(() => _isLocked = false);
    }
  }

  void _onDigitPressed(String digit) {
    if (_pin.length < 6) {
      setState(() => _pin += digit);
      if (_pin.length == 6) {
        _verifyPin();
      }
    }
  }

  void _onDeletePressed() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  Future<void> _verifyPin() async {
    final authService = ref.read(authServiceProvider);
    final isValid = await authService.verifyPin(_pin);
    if (isValid) {
      if (mounted) setState(() => _isLocked = false);
    } else {
      if (mounted) {
        setState(() {
          _pin = '';
          _message = 'Incorrect PIN';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isLocked)
          Positioned.fill(
            child: Material(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.mainGradient,
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      const Spacer(),
                      const Icon(
                        Icons.lock_outline,
                        size: 64,
                        color: AppColors.primaryGold,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _message,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 48),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index < _pin.length
                                  ? AppColors.primaryGold
                                  : AppColors.textSecondary.withOpacity(0.2),
                            ),
                          );
                        }),
                      ),
                      const Spacer(),
                      PinPad(
                        onDigitPressed: _onDigitPressed,
                        onDeletePressed: _onDeletePressed,
                        showBiometric: _biometricEnabled,
                        onBiometricPressed:
                            _biometricEnabled ? _tryBiometricUnlock : null,
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
