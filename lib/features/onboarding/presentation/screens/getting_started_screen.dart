import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
import '../../../../shared/widgets/currency_picker_field.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/onboarding_defaults.dart';
import 'onboarding_stories_screen.dart';

class GettingStartedScreen extends ConsumerStatefulWidget {
  const GettingStartedScreen({super.key});

  @override
  ConsumerState<GettingStartedScreen> createState() => _GettingStartedScreenState();
}

class _GettingStartedScreenState extends ConsumerState<GettingStartedScreen> {
  Currency _selectedCurrency = Currency.idr;
  OnboardingCountry _selectedCountry = OnboardingCountry.indonesia;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackOnboardingStarted();
  }

  // ---------------------------------------------------------------------------
  // Locale helpers
  // ---------------------------------------------------------------------------

  /// Whether the current locale is Bahasa Indonesia.
  bool get _isIndonesianLocale {
    final locale = ref.read(localeProvider);
    return locale.languageCode == 'id';
  }

  // ---------------------------------------------------------------------------
  // Language selection
  // ---------------------------------------------------------------------------

  Future<void> _setLanguage(String code) async {
    final profile = await ref.read(profileDaoProvider).getActiveProfile();
    if (profile != null) {
      await ref.read(settingsDaoProvider).setLanguage(profile.id, code);
    }
    // Update country default based on language
    if (mounted) {
      setState(() {
        // Bahasa Indonesia always defaults to Indonesia; English keeps current
        // country selection (defaults to Indonesia unless user changed it).
        if (code == 'id') {
          _selectedCountry = OnboardingCountry.indonesia;
        }
      });
    }
  }

  void _showLanguageSelector() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgDarkEnd,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _LanguageSelectorSheet(
        onSelected: (code) async {
          Navigator.pop(ctx);
          await _setLanguage(code);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Country selection (English locale only)
  // ---------------------------------------------------------------------------

  void _showCountrySelector() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgDarkEnd,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CountrySelectorSheet(
        selected: _selectedCountry,
        onSelected: (country) {
          Navigator.pop(ctx);
          setState(() => _selectedCountry = country);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Get Started action
  // ---------------------------------------------------------------------------

  Future<void> _onGetStarted() async {
    setState(() => _isSaving = true);
    try {
      final profileDao = ref.read(profileDaoProvider);
      final profile = await profileDao.getActiveProfile();

      if (profile != null) {
        final profileId = profile.id;

        // 1. Save selected currency.
        await ref.read(settingsDaoProvider).setDefaultCurrency(profileId, _selectedCurrency);

        // 2. Determine which country defaults to seed.
        final country = _isIndonesianLocale
            ? OnboardingCountry.indonesia
            : _selectedCountry;

        // 3. Seed wallet accounts.
        await _seedAccounts(profileId, country);

        // 4. Seed categories.
        await _seedCategories(profileId, country);
      } else {
        debugPrint('GettingStartedScreen: no active profile — skipping currency/defaults setup.');
      }

      // 5. Mark onboarding as complete.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.onboardingCompletedKey, true);

      if (!mounted) return;
      AnalyticsService.trackOnboardingStepCompleted('getting_started');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingStoriesScreen()),
      );
    } catch (e, stack) {
      debugPrint('GettingStartedScreen: failed to complete onboarding: $e\n$stack');
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _seedAccounts(int profileId, OnboardingCountry country) async {
    final dao = ref.read(accountDaoProvider);
    final defaults = getOnboardingDefaults(country);
    final now = DateTime.now();

    for (final account in defaults.accounts) {
      await dao.insertAccount(
        AccountsCompanion(
          profileId: drift.Value(profileId),
          name: drift.Value(account.name),
          type: drift.Value(account.type),
          currency: drift.Value(_selectedCurrency),
          initialBalance: const drift.Value(0),
          icon: const drift.Value('wallet'),
          color: const drift.Value('0xFFD4AF37'),
          isActive: const drift.Value(true),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );
    }
  }

  Future<void> _seedCategories(int profileId, OnboardingCountry country) async {
    final dao = ref.read(categoryDaoProvider);
    final defaults = getOnboardingDefaults(country);
    int sortOrder = 0;

    for (final category in defaults.categories) {
      await dao.createCategory(
        CategoriesCompanion(
          profileId: drift.Value(profileId),
          name: drift.Value(category.name),
          type: drift.Value(category.type),
          icon: const drift.Value(kDefaultCategoryIcon),
          color: const drift.Value(kDefaultCategoryColor),
          isSystem: const drift.Value(false),
          sortOrder: drift.Value(sortOrder++),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final isId = locale.languageCode == 'id';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.splashGradient),
        child: SafeArea(
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
                  child: Semantics(
                    label: 'Richer app logo',
                    image: true,
                    child: Image.asset(
                      'assets/images/splash_icon.png',
                      fit: BoxFit.contain,
                    ),
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

                Text(
                  'Welcome! Let\'s get started.',
                  style: AppTypography.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const Spacer(flex: 2),

                // ── Language selector ──────────────────────────────────────
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose your language',
                    style: AppTypography.textTheme.labelLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  label: 'Language selector, currently ${isId ? 'Bahasa Indonesia' : 'English'}',
                  hint: 'Double tap to open language picker',
                  button: true,
                  child: GestureDetector(
                    onTap: _showLanguageSelector,
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      borderRadius: 12,
                      child: Row(
                        children: [
                          Text(
                            isId ? '🇮🇩' : '🇺🇸',
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isId ? 'Bahasa Indonesia' : 'English',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.expand_more,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Country selector (English locale only) ─────────────────
                if (!isId) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choose your country',
                      style: AppTypography.textTheme.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    label: 'Country selector, currently ${_selectedCountry.displayName}',
                    hint: 'Double tap to open country picker',
                    button: true,
                    child: GestureDetector(
                      onTap: _showCountrySelector,
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        borderRadius: 12,
                        child: Row(
                          children: [
                            Text(
                              _selectedCountry.flag,
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedCountry.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.expand_more,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sets up wallet accounts and categories for your region.',
                    style: AppTypography.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Currency selector ──────────────────────────────────────
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose your primary currency',
                    style: AppTypography.textTheme.labelLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                Semantics(
                  label: 'Currency selector, currently ${_selectedCurrency.countryName} — ${_selectedCurrency.code}',
                  hint: 'Double tap to open currency picker',
                  button: true,
                  child: CurrencyPickerField(
                    value: _selectedCurrency,
                    onChanged: (c) => setState(() => _selectedCurrency = c),
                    isDark: true,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'You can change this anytime in Settings.',
                  style: AppTypography.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),

                const Spacer(flex: 2),

                // ── Get Started button ─────────────────────────────────────
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
    );
  }
}

// =============================================================================
// Language selector bottom sheet
// =============================================================================

class _LanguageSelectorSheet extends ConsumerWidget {
  final ValueChanged<String> onSelected;

  const _LanguageSelectorSheet({required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Language',
            style: AppTypography.textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),
          _LanguageTile(
            flag: '🇺🇸',
            label: 'English',
            isSelected: currentLocale.languageCode == 'en',
            onTap: () => onSelected('en'),
          ),
          const SizedBox(height: 8),
          _LanguageTile(
            flag: '🇮🇩',
            label: 'Bahasa Indonesia',
            isSelected: currentLocale.languageCode == 'id',
            onTap: () => onSelected('id'),
          ),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final String flag;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.flag,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGold.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryGold.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.primaryGold : Colors.white,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primaryGold, size: 20),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Country selector bottom sheet
// =============================================================================

class _CountrySelectorSheet extends StatelessWidget {
  final OnboardingCountry selected;
  final ValueChanged<OnboardingCountry> onSelected;

  const _CountrySelectorSheet({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Your Country',
            style: AppTypography.textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll set up wallet accounts and categories tailored to your region.',
            style: AppTypography.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          ...OnboardingCountry.values.map(
            (country) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CountryTile(
                country: country,
                isSelected: selected == country,
                onTap: () => onSelected(country),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountryTile extends StatelessWidget {
  final OnboardingCountry country;
  final bool isSelected;
  final VoidCallback onTap;

  const _CountryTile({
    required this.country,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGold.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryGold.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Text(country.flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    country.displayName,
                    style: TextStyle(
                      color: isSelected ? AppColors.primaryGold : Colors.white,
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (country == OnboardingCountry.indonesia)
                    Text(
                      'Includes BCA, Mandiri, GoPay, OVO, Dana...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                    )
                  else
                    Text(
                      'Generic bank, cash, wallet & credit card',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primaryGold, size: 20),
          ],
        ),
      ),
    );
  }
}
