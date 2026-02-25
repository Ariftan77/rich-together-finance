import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Dio provider
final dioProvider = Provider<Dio>((ref) {
  return Dio();
});
