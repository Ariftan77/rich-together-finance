import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleAuthResult {
  final String appleUserId;
  final String? email;
  final String? givenName;
  final String? familyName;

  AppleAuthResult({
    required this.appleUserId,
    this.email,
    this.givenName,
    this.familyName,
  });
}

class AppleAuthService {
  static final AppleAuthService _i = AppleAuthService._();
  factory AppleAuthService() => _i;
  AppleAuthService._();

  Future<bool> get isAvailable => SignInWithApple.isAvailable();

  /// Apple only provides email and name on FIRST sign-in.
  /// Callers MUST persist immediately on first receipt.
  Future<AppleAuthResult?> signIn() async {
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      if (credential.userIdentifier == null) return null;

      return AppleAuthResult(
        appleUserId: credential.userIdentifier!,
        email: credential.email,
        givenName: credential.givenName,
        familyName: credential.familyName,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      debugPrint('[AppleAuth] Authorization error: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[AppleAuth] Sign-in failed: $e');
      return null;
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }
}
