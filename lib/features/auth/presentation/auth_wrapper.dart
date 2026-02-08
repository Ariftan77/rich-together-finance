import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/auth_service.dart';
import '../../dashboard/presentation/dashboard_shell.dart';
import 'screens/auth_screen.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStatus = ref.watch(authStatusProvider);

    switch (authStatus) {
      case AuthStatus.authenticated:
        return const DashboardShell();
      case AuthStatus.setupRequired:
        return const AuthScreen(isSetup: true);
      case AuthStatus.unauthenticated:
        return const AuthScreen(isSetup: false);
    }
  }
}
