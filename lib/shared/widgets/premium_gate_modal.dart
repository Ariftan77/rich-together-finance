import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/locale_provider.dart';
import '../../core/providers/nav_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/iap_service.dart';
import '../../core/services/premium_auth_service.dart';
import '../theme/app_theme_mode.dart';
import '../theme/colors.dart';
import '../theme/theme_provider_widget.dart';
import 'glass_button.dart';

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Show the premium gate modal.
///
/// [title] and [description] are caller-provided (already localized by caller).
/// Returns `true` if the purchase succeeded, `false` if dismissed or failed.
Future<bool> showPremiumGateModal(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String description,
  IconData icon = Icons.workspace_premium,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _PremiumGateModal(
      title: title,
      description: description,
      icon: icon,
    ),
  );
  return result ?? false;
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class _PremiumGateModal extends ConsumerStatefulWidget {
  final String title;
  final String description;
  final IconData icon;

  const _PremiumGateModal({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  ConsumerState<_PremiumGateModal> createState() => _PremiumGateModalState();
}

class _PremiumGateModalState extends ConsumerState<_PremiumGateModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  bool _isLoading = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Purchase logic
  // ---------------------------------------------------------------------------

  Future<void> _handleBuyPremium() async {
    // Step 1: Pre-check — ensure the user is signed in with Google before
    // attempting a purchase. IapService.buyPremium() requires a Google account
    // to record the purchase; catching it here gives a better UX than the
    // IapResult.notSignedIn fallback.
    if (!PremiumAuthService().isSignedIn) {
      final shouldSignIn = await _showSignInRequiredDialog();
      if (!mounted) return;
      if (!shouldSignIn) return; // user tapped Cancel — stay on modal

      // Step 2: Attempt sign-in while showing the loading spinner.
      setState(() => _isLoading = true);
      final signedIn = await PremiumAuthService().signIn();
      if (!mounted) return;
      if (!signedIn) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google sign-in failed. Please try again.'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
      // signIn() succeeded — keep _isLoading = true and fall through to purchase.
    } else {
      setState(() => _isLoading = true);
    }

    // Step 3: Proceed with the purchase.
    final result = await IapService().buyPremium();
    if (!mounted) return;
    setState(() => _isLoading = false);

    switch (result) {
      case IapResult.success:
        // Pop with true to signal caller that premium is now active.
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(translationsProvider).premiumActivated),
            backgroundColor: AppColors.success,
          ),
        );
        // Invalidate the cached premium status so any watchers update.
        ref.invalidate(premiumStatusProvider);
        break;

      case IapResult.notSignedIn:
        // Defensive fallback — should not reach here after the pre-check above,
        // but handle gracefully without an action button.
        Navigator.of(context).pop(false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(translationsProvider).premiumNotSignedIn),
            backgroundColor: AppColors.info,
            duration: const Duration(seconds: 3),
          ),
        );
        break;

      case IapResult.productNotFound:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Product not found. Please try again later.'),
            backgroundColor: AppColors.error,
          ),
        );
        break;

      case IapResult.disabled:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('In-app purchases are currently unavailable.'),
            backgroundColor: AppColors.error,
          ),
        );
        break;

      case IapResult.purchaseFailed:
      case IapResult.activationFailed:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Purchase failed. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
        break;
    }
  }

  Future<bool> _showSignInRequiredDialog() async {
    final trans = ref.read(translationsProvider);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final themeMode = AppThemeProvider.of(context);
        final isLight = themeMode == AppThemeMode.light ||
            (themeMode == AppThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.light);
        final isDefault = themeMode == AppThemeMode.defaultTheme;
        return AlertDialog(
          backgroundColor: isDefault
              ? AppColors.bgDarkEnd
              : isLight
                  ? Colors.white
                  : const Color(0xFF111111),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.account_circle, color: AppColors.primaryGold),
              const SizedBox(width: 12),
              Text(
                'Google Sign-In Required',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You need to sign in with Google to purchase premium features.',
                style: TextStyle(
                  color: isLight
                      ? AppColors.textPrimaryLight
                      : Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primaryGold.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.primaryGold, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This allows you to restore your purchase on any device.',
                        style: TextStyle(
                          color: isLight
                              ? AppColors.textPrimaryLight
                              : Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                trans.genericCancel,
                style: TextStyle(
                  color: isLight ? const Color(0xFF374151) : Colors.white70,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Sign In'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _handleRestore() async {
    setState(() => _isRestoring = true);
    await IapService().restorePurchases();
    if (!mounted) return;
    setState(() => _isRestoring = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ref.read(translationsProvider).premiumCheckingPlayStore,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final trans = ref.watch(translationsProvider);
    final isLight = AppThemeProvider.isLightMode(context);
    final accentColor = Theme.of(context).colorScheme.primary;
    final iapEnabled = ref.watch(iapEnabledProvider);

    // Sheet background color — matches existing modal pattern in app.
    final sheetBg = AppColors.themed3<Color>(
      context,
      defaultTheme: const Color(0xFF1A1208),
      dark: const Color(0xFF111111),
      light: Colors.white,
    );

    final textPrimary = isLight ? AppColors.textPrimaryLight : Colors.white;
    final textMuted = isLight
        ? const Color(0xFF64748B)
        : Colors.white.withValues(alpha: 0.6);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isLight
                  ? const Color(0xFFCBD5E1)
                  : Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          // Animated icon
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: child,
              );
            },
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.15),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Icon(
                widget.icon,
                color: accentColor,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Dynamic title
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          // Dynamic description
          Text(
            widget.description,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textMuted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // Primary CTA button
          iapEnabled
              ? GlassButton(
                  text: trans.premiumGateButtonBuyLifetime,
                  icon: Icons.workspace_premium,
                  isFullWidth: true,
                  size: GlassButtonSize.large,
                  isLoading: _isLoading,
                  onPressed: _handleBuyPremium,
                )
              : GlassButton(
                  text: 'Coming Soon',
                  icon: Icons.lock_clock_outlined,
                  isFullWidth: true,
                  size: GlassButtonSize.large,
                  isPrimary: false,
                  onPressed: () {},
                  // Visually disabled — isLoading:false, but we treat onPressed as no-op
                ),
          const SizedBox(height: 10),

          // Tagline
          Text(
            trans.premiumGateTagline,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),

          // Maybe Later ghost button
          GlassButton(
            text: trans.premiumGateButtonMaybeLater,
            isPrimary: false,
            isFullWidth: true,
            size: GlassButtonSize.medium,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          const SizedBox(height: 20),

          // Restore Purchase link
          GestureDetector(
            onTap: _isRestoring ? null : _handleRestore,
            child: _isRestoring
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accentColor,
                    ),
                  )
                : Text(
                    trans.premiumGateRestorePurchase,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: accentColor.withValues(alpha: 0.8),
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                      decorationColor: accentColor.withValues(alpha: 0.5),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
