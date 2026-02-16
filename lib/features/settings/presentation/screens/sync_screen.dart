import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../../shared/widgets/glass_input.dart';
import '../widgets/settings_tile.dart';

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Initialize Supabase if not already? Should be done at app start, 
    // but we can ensure it here safely.
    // SyncService.initialize(); // Better to do in main.dart
  }

  Future<void> _handleAuth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final syncService = ref.read(syncServiceProvider);
      
      if (_isLogin) {
        await syncService.signIn(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        await syncService.signUp(
          _emailController.text.trim(),
          _passwordController.text,
          _nameController.text.trim(),
        );
      }
      
      if (!mounted) return;
      // Navigate back or show success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged in successfully!'), backgroundColor: AppColors.success),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'An unexpected error occurred: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _performSync() async {
    setState(() => _isLoading = true);
    try {
       await ref.read(syncServiceProvider).syncData();
       if (!mounted) return;
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync completed!'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _handleLogout() async {
     await ref.read(syncServiceProvider).signOut();
     setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final syncService = ref.watch(syncServiceProvider);
    final user = syncService.currentUser;

    return Scaffold(
      backgroundColor: AppColors.bgDarkEnd,
      body: Stack(
        children: [
          // Background Gradient (reused from other screens)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.bgDarkStart, AppColors.bgDarkEnd],
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      GlassButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Text('Sync Settings', style: AppTypography.textTheme.headlineMedium),
                    ],
                  ),
                  const SizedBox(height: 32),

                  if (user != null) ...[
                     _buildUserInfo(user),
                     const SizedBox(height: 24),
                     GlassButton(
                       onPressed: _performSync,
                       child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.sync, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Sync Now', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                     ),
                     const SizedBox(height: 16),
                     Center(
                       child: TextButton(
                         onPressed: _handleLogout,
                         child: const Text('Log Out', style: TextStyle(color: AppColors.error)),
                       ),
                     ),
                  ] else ...[
                    _buildAuthForm(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo(User user) {
    return GlassCard(
      child: Column(
        children: [
          const Icon(Icons.cloud_done, color: AppColors.primaryGold, size: 48),
          const SizedBox(height: 16),
          Text(
            'Connected as ${user.email}',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your data is backed up to the cloud.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthForm() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isLogin ? 'Sign In' : 'Create Account',
            style: AppTypography.textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          if (!_isLogin) ...[
            GlassInput(
              controller: _nameController,
              hintText: 'Full Name',
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
          ],
          GlassInput(
            controller: _emailController,
            hintText: 'Email',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          GlassInput(
            controller: _passwordController,
            hintText: 'Password',
            prefixIcon: Icons.lock_outline,
            obscureText: true,
          ),
          const SizedBox(height: 24),
          if (_errorMessage != null) ...[
             Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
             const SizedBox(height: 16),
          ],
          GlassButton(
            onPressed: _isLoading ? () {} : _handleAuth,
            child: Center(
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_isLogin ? 'Sign In' : 'Sign Up', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => setState(() {
                _isLogin = !_isLogin;
                _errorMessage = null;
              }),
              child: Text(
                _isLogin ? "Don't have an account? Sign Up" : "Already have an account? Sign In",
                style: const TextStyle(color: AppColors.primaryGold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
