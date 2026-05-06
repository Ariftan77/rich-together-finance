import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/locale_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/analytics_service.dart';
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
  AnalyticsService.trackPremiumModalGateOpen();
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
    // Clear any stale restore callback to avoid firing into a dead widget.
    IapService().onRestoreSuccess = null;
    _pulseController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Purchase logic
  // ---------------------------------------------------------------------------

  Future<void> _handleBuyPremium() async {
    AnalyticsService.trackGetPremiumTapped(source: 'modal');
    setState(() => _isLoading = true);

    final trans = ref.read(translationsProvider);

    // If the user already has premium (e.g. was already signed in), restore
    // directly instead of triggering a new purchase which would result in a
    // Play Store "already owned" error.
    if (PremiumAuthService().isPremium) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ref.invalidate(premiumStatusProvider);
      Navigator.of(context).pop(true);
      return;
    }

    // Proceed with the purchase. Both iOS and Android now skip the sign-in
    // check — unsigned purchases are stored locally and synced to the backend
    // the next time the user signs in.
    final result = await IapService().buyPremium(
      skipSignInCheck: true,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result == IapResult.success) {
      // Invalidate the cached premium status so any watchers update.
      ref.invalidate(premiumStatusProvider);
      // Pop modal — caller will handle snackbars and UI refresh.
      Navigator.of(context).pop(true);
      if (!mounted) return;
      // Show a brief success snackbar then nudge unsigned users to sign in.
      if (!PremiumAuthService().isSignedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trans.premiumActivated),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
        // Only show sign-in modal on Android (disabled for iOS).
        if (Platform.isAndroid) {
          // Brief delay so the snackbar is visible before the modal appears.
          await Future.delayed(const Duration(milliseconds: 800));
          if (!mounted) return;
          await _showSignInBenefitsModal();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trans.premiumActivated),
            backgroundColor: AppColors.success,
          ),
        );
      }
      return;
    }

    // USER_CANCELED: user backed out — silently dismiss, no snackbar.
    if (result == IapResult.userCanceled) return;

    // Retryable infrastructure errors — offer a "Try Again" action.
    if (result == IapResult.serviceUnavailable ||
        result == IapResult.serviceDisconnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(trans.iapErrorServiceUnavailable),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: trans.iapActionTryAgain,
            textColor: Colors.white,
            onPressed: _handleBuyPremium,
          ),
        ),
      );
      return;
    }

    // Activation succeeded on Play Store but backend call failed — direct to
    // support so the user can recover their purchase.
    if (result == IapResult.activationFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(trans.iapErrorActivationFailed),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: trans.iapActionContactSupport,
            textColor: Colors.white,
            onPressed: () {
              final email = Uri.encodeComponent('axiomtech.dev@gmail.com');
              final subject = Uri.encodeComponent('Premium Activation Issue');
              launchUrl(Uri.parse('mailto:$email?subject=$subject'));
            },
          ),
        ),
      );
      return;
    }

    // itemAlreadyOwned: the purchase is on the Play Store but not active locally.
    // Show a snackbar with a Restore action so the user can recover immediately.
    if (result == IapResult.alreadyOwned) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(trans.iapErrorAlreadyOwned),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: trans.iapActionRestore,
            textColor: Colors.white,
            onPressed: _handleRestore,
          ),
        ),
      );
      return;
    }

    // Defensive fallback for notSignedIn — both platforms now use
    // skipSignInCheck: true, so this case should not occur.
    if (result == IapResult.notSignedIn) {
      Navigator.of(context).pop(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(trans.premiumNotSignedIn),
          backgroundColor: AppColors.info,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // All other non-retryable errors — plain localized message.
    final message = switch (result) {
      IapResult.productNotFound => trans.iapErrorProductNotFound,
      IapResult.billingUnavailable => trans.iapErrorBillingUnavailable,
      IapResult.featureNotSupported => trans.iapErrorFeatureNotSupported,
      IapResult.disabled => trans.iapErrorDisabled,
      _ => trans.iapErrorPurchaseFailed,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  /// Shows the sign-in benefits bottom sheet after a successful unsigned
  /// purchase or voucher redemption. Attempts Google sign-in if the user
  /// taps the sign-in button and invalidates premium status on success.
  Future<void> _showSignInBenefitsModal() async {
    final trans = ref.read(translationsProvider);
    final auth = PremiumAuthService();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _SignInBenefitsModal(
        trans: trans,
        onSignIn: () async {
          Navigator.pop(sheetContext);
          if (!mounted) return;
          setState(() => _isLoading = true);
          final ok = await auth.signInWithGoogle();
          if (!mounted) return;
          setState(() => _isLoading = false);
          if (ok) {
            AnalyticsService.logSignInProvider(provider: 'google');
            ref.invalidate(premiumStatusProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(trans.premiumSignInSuccess),
                backgroundColor: AppColors.success,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(trans.premiumSignInFailed),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        onSkip: () => Navigator.pop(sheetContext),
      ),
    );
  }

  Future<void> _handleRestore() async {
    final trans = ref.read(translationsProvider);
    setState(() => _isRestoring = true);

    try {
      // Step 1: For signed-in users, check Supabase first — the user may
      // already have premium on the backend (e.g. purchased on another device
      // or the local cache is stale). Skip for unsigned users since they have
      // no backend record yet.
      if (PremiumAuthService().isSignedIn) {
        String? backendStatus;
        try {
          backendStatus = await PremiumAuthService().getPremiumStatus();
        } catch (_) {
          // Network error — fall through to platform restore.
        }

        if (backendStatus != null) {
          ref.invalidate(premiumStatusProvider);
          if (!mounted) return;
          setState(() => _isRestoring = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(trans.premiumActivated),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop(true);
          return;
        }
      }

      // Step 2: Android — try to validate the existing Play Store purchase
      // against the backend without showing any native UI. This works for both
      // signed-in and unsigned users because the backend accepts temporary_user_id.
      if (Platform.isAndroid) {
        final validation =
            await IapService().validateExistingPurchaseOnBackend();
        if (validation != null && validation.success) {
          final premiumType = validation.premiumType ?? 'lifetime';
          await PremiumAuthService().activatePremiumFromValidation(
            premiumType,
            expiresAt: validation.expiresAt,
          );
          ref.invalidate(premiumStatusProvider);
          if (!mounted) return;
          setState(() => _isRestoring = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(trans.premiumActivated),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop(true);
          return;
        }
      }

      // Step 3: Register the one-shot callback BEFORE triggering the platform
      // restore so it is in place when the restored event arrives.
      // _onPurchaseUpdate will call validateReceiptOnBackend internally before
      // activating, and then fire this callback on success.
      IapService().onRestoreSuccess = () {
        if (!mounted) return;
        setState(() => _isRestoring = false);
        ref.invalidate(premiumStatusProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trans.premiumActivated),
            backgroundColor: AppColors.success,
          ),
        );
        if (mounted) Navigator.of(context).pop(true);
      };

      // Step 4: Trigger the platform store restore flow.
      // iOS: shows the App Store restore sheet; StoreKit delivers restored
      //      events to _onPurchaseUpdate, which now validates with the backend.
      // Android: falls through here only when queryPastPurchases returned
      //          nothing (e.g. different account).
      await IapService().restorePurchases();

      // Step 5: Show a neutral "checking" snackbar — the callback above
      // handles the success case asynchronously when the restored event arrives.
      if (!mounted) return;
      setState(() => _isRestoring = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Platform.isIOS
                ? trans.premiumCheckingAppStore
                : trans.premiumCheckingPlayStore,
          ),
        ),
      );
    } catch (_) {
      // Ensure spinner is always cleared on unexpected errors.
      IapService().onRestoreSuccess = null;
      if (!mounted) return;
      setState(() => _isRestoring = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(trans.iapErrorPurchaseFailed),
          backgroundColor: AppColors.error,
        ),
      );
    }
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
          // Price label — shown only when the store has returned a price string.
          if (iapEnabled && IapService().premiumPrice != null) ...[
            const SizedBox(height: 6),
            Builder(builder: (_) {
              final pd = IapService().premiumProductDetails;
              debugPrint('[PremiumGate] price=${pd?.price} '
                  'rawPrice=${pd?.rawPrice} '
                  'currencyCode=${pd?.currencyCode} '
                  'currencySymbol=${pd?.currencySymbol}');
              return const SizedBox.shrink();
            }),
            Text(
              IapService().premiumPrice!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textMuted,
                fontSize: 13,
              ),
            ),
          ],
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

// ---------------------------------------------------------------------------
// Sign-In Benefits Modal — shown after unsigned purchase/voucher success
// ---------------------------------------------------------------------------

class _SignInBenefitsModal extends StatefulWidget {
  final dynamic trans; // AppTranslations instance
  final Future<void> Function() onSignIn;
  final VoidCallback onSkip;

  const _SignInBenefitsModal({
    required this.trans,
    required this.onSignIn,
    required this.onSkip,
  });

  @override
  State<_SignInBenefitsModal> createState() => _SignInBenefitsModalState();
}

class _SignInBenefitsModalState extends State<_SignInBenefitsModal> {
  bool _signingIn = false;

  @override
  Widget build(BuildContext context) {
    final isLight = AppThemeProvider.isLightMode(context);
    final themeMode = AppThemeProvider.of(context);
    final isDefault = themeMode == AppThemeMode.defaultTheme;

    final sheetBg = isDefault
        ? const Color(0xFF1A1208)
        : isLight
            ? Colors.white
            : const Color(0xFF111111);

    final textPrimary = isLight ? AppColors.textPrimaryLight : Colors.white;
    final textMuted = isLight
        ? const Color(0xFF64748B)
        : Colors.white.withValues(alpha: 0.6);

    final benefits = [
      widget.trans.signInBenefitRestore as String,
      widget.trans.signInBenefitBackup as String,
    ];

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 36,
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

          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryGold.withValues(alpha: 0.15),
              border: Border.all(
                color: AppColors.primaryGold.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.cloud_sync_rounded,
              color: AppColors.primaryGold,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            widget.trans.signInBenefitsTitle as String,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 20),

          // Benefits list
          ...benefits.map(
            (benefit) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryGold.withValues(alpha: 0.15),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: AppColors.primaryGold,
                      size: 13,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      benefit,
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Sign-in button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _signingIn
                  ? null
                  : () async {
                      setState(() => _signingIn = true);
                      await widget.onSignIn();
                      if (mounted) setState(() => _signingIn = false);
                    },
              icon: _signingIn
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.login, size: 18),
              label: Text(
                _signingIn ? '' : widget.trans.signInBenefitsSignInButton as String,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Skip button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _signingIn ? null : widget.onSkip,
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 46),
                foregroundColor: textMuted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isLight
                        ? const Color(0xFFCBD5E1)
                        : Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ),
              child: Text(
                widget.trans.signInBenefitsSkipButton as String,
                style: TextStyle(
                  fontSize: 14,
                  color: textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
