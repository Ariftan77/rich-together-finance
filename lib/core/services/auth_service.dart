import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

/// Service for handling authentication (PIN & Biometrics)
class AuthService {
  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  AuthService(this._storage, this._localAuth);

  static const _pinKey = 'user_pin';
  static const _biometricEnabledKey = 'biometric_enabled';
  static const _authEnabledKey = 'auth_enabled';

  /// Check if authentication is enabled
  Future<bool> isAuthEnabled() async {
    final enabled = await _storage.read(key: _authEnabledKey);
    return enabled == 'true';
  }

  /// Check if biometric is enabled
  Future<bool> isBiometricEnabled() async {
    final enabled = await _storage.read(key: _biometricEnabledKey);
    return enabled == 'true';
  }

  /// Set auth enabled status
  Future<void> setAuthEnabled(bool enabled) async {
    await _storage.write(key: _authEnabledKey, value: enabled.toString());
  }

  /// Set biometric enabled status
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  /// Check if a PIN is set
  Future<bool> hasPin() async {
    final pin = await _storage.read(key: _pinKey);
    return pin != null && pin.isNotEmpty;
  }

  /// Set a new PIN
  Future<void> setPin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
    // Auto-enable auth when PIN is set
    await setAuthEnabled(true);
  }

  /// Verify PIN
  Future<bool> verifyPin(String enteredPin) async {
    final storedPin = await _storage.read(key: _pinKey);
    return storedPin == enteredPin;
  }

  /// Check if device supports biometrics
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics && await _localAuth.isDeviceSupported();
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Authenticate with biometrics
  Future<bool> authenticateWithBiometrics() async {
    try {
      final isAvailable = await canCheckBiometrics();
      if (!isAvailable) return false;

      return await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access Rich Together',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Biometric Authentication',
            cancelButton: 'Use PIN',
          ),
          IOSAuthMessages(
            cancelButton: 'Use PIN',
          ),
        ],
      );
    } on PlatformException catch (_) {
      return false;
    }
  }
}

/// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
    LocalAuthentication(),
  );
});

/// State provider for current auth status
enum AuthStatus {
  authenticated,
  unauthenticated,
  setupRequired, // No PIN set
}

final authStatusProvider = StateNotifierProvider<AuthStatusNotifier, AuthStatus>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthStatusNotifier(authService);
});

class AuthStatusNotifier extends StateNotifier<AuthStatus> {
  final AuthService _authService;

  AuthStatusNotifier(this._authService) : super(AuthStatus.unauthenticated) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    final hasPin = await _authService.hasPin();
    final isEnabled = await _authService.isAuthEnabled();

    if (!hasPin) {
      // By default, if no PIN is set, the app is unlocked and usable.
      state = AuthStatus.authenticated;
    } else if (!isEnabled) {
      state = AuthStatus.authenticated; // If auth disabled, consider authenticated
    } else {
      state = AuthStatus.unauthenticated;
      // Try biometric auto-login if enabled
      final bioEnabled = await _authService.isBiometricEnabled();
      if (bioEnabled) {
        final success = await _authService.authenticateWithBiometrics();
        if (success) {
          state = AuthStatus.authenticated;
        }
      }
    }
  }

  void setAuthenticated() {
    state = AuthStatus.authenticated;
  }

  void logout() {
    state = AuthStatus.unauthenticated;
  }
}
