import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/encryption_service.dart';

// Dio provider
final dioProvider = Provider<Dio>((ref) {
  return Dio();
});

// Encryption service provider
final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
});
