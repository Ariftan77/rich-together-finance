import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/encryption_service.dart';
import '../services/premium_auth_service.dart';
import '../services/remote_config_service.dart';

// Dio provider
final dioProvider = Provider<Dio>((ref) {
  return Dio();
});

// Encryption service provider
final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
});

/// Thin provider that exposes [PremiumAuthService.isPremium] synchronously.
/// Reads directly from the cached SharedPreferences value — no async needed.
final premiumStatusProvider = Provider<bool>((ref) {
  return PremiumAuthService().isPremium;
});

final iapEnabledProvider = Provider<bool>((ref) {
  return RemoteConfigService().iapEnabled;
});

final premiumEnabledProvider = Provider<bool>((ref) {
  return RemoteConfigService().premiumEnabled;
});
