import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
import '../../../../shared/widgets/currency_picker_field.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../dashboard/presentation/dashboard_shell.dart';

class GettingStartedScreen extends ConsumerStatefulWidget {
  const GettingStartedScreen({super.key});

  @override
  ConsumerState<GettingStartedScreen> createState() => _GettingStartedScreenState();
}

class _GettingStartedScreenState extends ConsumerState<GettingStartedScreen> {
  Currency _selectedCurrency = Currency.idr;
  bool _isSaving = false;

  Future<void> _onGetStarted() async {
    setState(() => _isSaving = true);
    try {
      // Read profile directly from DAO — the StreamProvider may not have emitted yet
      // on first launch, so activeProfileIdProvider would return null.
      final profile = await ref.read(profileDaoProvider).getActiveProfile();
      if (profile != null) {
        await ref.read(settingsDaoProvider).setDefaultCurrency(profile.id, _selectedCurrency);
      }

      // Mark onboarding as complete
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardShell()),
      );
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background gradient matching splash
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0F172A),
                Color(0xFF171E2E),
                Color(0xFF854D0E),
                Color(0xFFC25400),
              ],
              stops: [0.0, 0.3, 0.8, 1.0],
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Logo
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGold.withValues(alpha: 0.25),
                          blurRadius: 32,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/splash_icon.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // App name
                  Text(
                    'Richer - Money Management',
                    textAlign: TextAlign.center,
                    style: AppTypography.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'Welcome! Let\'s get started.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Currency section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choose your primary currency',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Override the theme brightness so picker uses dark style
                  Theme(
                    data: Theme.of(context).copyWith(brightness: Brightness.dark),
                    child: CurrencyPickerField(
                      value: _selectedCurrency,
                      onChanged: (c) => setState(() => _selectedCurrency = c),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'You can change this anytime in Settings.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Get Started button
                  GlassButton(
                    text: 'Get Started',
                    isFullWidth: true,
                    size: GlassButtonSize.large,
                    onPressed: _onGetStarted,
                    isLoading: _isSaving,
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
