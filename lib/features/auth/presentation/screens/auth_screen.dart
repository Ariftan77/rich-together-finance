import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/theme/colors.dart';
import '../widgets/pin_pad.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final bool isSetup;

  const AuthScreen({super.key, this.isSetup = false});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String _message = 'Enter PIN';

  @override
  void initState() {
    super.initState();
    if (widget.isSetup) {
      _message = 'Create a PIN';
    } else {
      _message = 'Enter PIN';
      _checkBiometric();
    }
  }

  Future<void> _checkBiometric() async {
    final authService = ref.read(authServiceProvider);
    final bioEnabled = await authService.isBiometricEnabled();
    if (bioEnabled) {
      _authenticateBiometric();
    }
  }

  Future<void> _authenticateBiometric() async {
    final authService = ref.read(authServiceProvider);
    final success = await authService.authenticateWithBiometrics();
    if (success) {
      ref.read(authStatusProvider.notifier).setAuthenticated();
    }
  }

  void _onDigitPressed(String digit) {
    if (_pin.length < 6) {
      setState(() {
        _pin += digit;
      });
      if (_pin.length == 6) {
        _onPinComplete();
      }
    }
  }

  void _onDeletePressed() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  void _onPinComplete() async {
    if (widget.isSetup) {
      if (!_isConfirming) {
        setState(() {
          _confirmPin = _pin;
          _pin = '';
          _isConfirming = true;
          _message = 'Confirm PIN';
        });
      } else {
        if (_pin == _confirmPin) {
          // PIN match
          final authService = ref.read(authServiceProvider);
          await authService.setPin(_pin);
          // Ask for biometric
          if (mounted) {
            final canBio = await authService.canCheckBiometrics();
            if (canBio) {
              _showBiometricDialog();
            } else {
              ref.read(authStatusProvider.notifier).setAuthenticated();
            }
          }
        } else {
          // PIN mismatch
          setState(() {
            _pin = '';
            _confirmPin = '';
            _isConfirming = false;
            _message = 'PINs do not match. Try again.';
          });
        }
      }
    } else {
      // Login
      final authService = ref.read(authServiceProvider);
      final isValid = await authService.verifyPin(_pin);
      if (isValid) {
        ref.read(authStatusProvider.notifier).setAuthenticated();
      } else {
        setState(() {
          _pin = '';
          _message = 'Incorrect PIN';
        });
      }
    }
  }

  void _showBiometricDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Enable Biometrics?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Use fingerprint or face ID for faster login.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(authStatusProvider.notifier).setAuthenticated();
              Navigator.pop(context);
            },
            child: const Text('No Thanks', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final authService = ref.read(authServiceProvider);
              await authService.setBiometricEnabled(true);
              ref.read(authStatusProvider.notifier).setAuthenticated();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Enable', style: TextStyle(color: AppColors.primaryGold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDarkStart,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgDarkStart, AppColors.bgDarkEnd],
          ),
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
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
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
                showBiometric: !widget.isSetup,
                onBiometricPressed: !widget.isSetup ? _authenticateBiometric : null,
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
