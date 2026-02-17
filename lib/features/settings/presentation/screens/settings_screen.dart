import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/glass_input.dart';
import '../../../../shared/widgets/glass_button.dart';
import '../../../../core/services/auth_service.dart';
import '../widgets/profile_selector_modal.dart';
import '../widgets/settings_tile.dart';
import 'about_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';
import 'help_faq_screen.dart';
import 'categories_screen.dart';
import 'backup_screen.dart';
import 'sync_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = '${info.version} (${info.buildNumber})';
      });
    } catch (e) {
      setState(() {
        _appVersion = '1.0.0';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeProfile = ref.watch(activeProfileProvider);
    final settings = ref.watch(activeProfileSettingsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                ref.watch(translationsProvider).navSettings,
                style: AppTypography.textTheme.displaySmall,
              ),
              const SizedBox(height: 24),

              // Profile Section
              _buildSectionHeader(ref.watch(translationsProvider).settingsProfile),
              const SizedBox(height: 12),
              activeProfile.when(
                data: (profile) => _buildProfileCard(profile),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 24),

              // Preferences Section
              _buildSectionHeader(ref.watch(translationsProvider).settingsPreferences),
              const SizedBox(height: 12),
              settings.when(
                data: (userSettings) => _buildPreferencesSection(userSettings),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 24),

              // Security Section
              _buildSectionHeader(ref.watch(translationsProvider).settingsSecurity),
              const SizedBox(height: 12),
              _buildSecuritySection(settings.valueOrNull),
              const SizedBox(height: 24),

              // App Info Section
              _buildSectionHeader(ref.watch(translationsProvider).settingsAbout),
              const SizedBox(height: 12),
              _buildAppInfoSection(),
              const SizedBox(height: 24),

              Center(
                child: TextButton.icon(
                  onPressed: () => _showClearDataDialog(),
                  icon: const Icon(Icons.delete_forever, color: AppColors.error, size: 18),
                  label: Text(ref.watch(translationsProvider).settingsClearData, style: const TextStyle(color: AppColors.error)),
                ),
              ),

              // Version info at bottom
              Center(
                child: Text(
                  '${ref.watch(translationsProvider).settingsVersion} $_appVersion',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTypography.textTheme.titleMedium?.copyWith(
        color: AppColors.primaryGold,
      ),
    );
  }

  Widget _buildProfileCard(Profile? profile) {
    return Column(
      children: [
        GlassCard(
          onTap: () => _showProfileSelector(),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    profile?.avatar ?? '👤',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?.name ?? ref.watch(translationsProvider).settingsNoProfile,
                      style: AppTypography.textTheme.titleMedium,
                    ),
                      Text(
                        ref.watch(translationsProvider).settingsTapToSwitch,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: EdgeInsets.zero,
          child: SettingsTile(
            icon: Icons.cloud_sync,
            title: ref.watch(translationsProvider).settingsSyncBackup,
            subtitle: ref.watch(translationsProvider).settingsConnectSupabase,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SyncScreen()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreferencesSection(UserSetting? settings) {
    final currency = settings?.defaultCurrency ?? Currency.idr;
    final showDecimal = settings?.showDecimal ?? false;

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SettingsTile(
            icon: Icons.language,
            title: ref.watch(translationsProvider).settingsLanguage,
            subtitle: ref.watch(localeProvider).languageCode == 'id' ? 'Bahasa Indonesia' : 'English',
            onTap: () => _showLanguageSelector(),
          ),
          _buildDivider(),
          SettingsTile(
            icon: Icons.category_outlined,
            title: ref.watch(translationsProvider).settingsManageCategories,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CategoriesScreen()),
            ),
          ),
          _buildDivider(),
          SettingsTile(
            icon: Icons.backup_outlined,
            title: ref.watch(translationsProvider).settingsBackupRestore,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BackupScreen()),
            ),
          ),
          _buildDivider(),
          SettingsTile(
            icon: Icons.attach_money,
            title: ref.watch(translationsProvider).settingsBaseCurrency,
            subtitle: currency.code,
            onTap: () => _showCurrencyPicker(currency),
          ),
          _buildDivider(),
          SettingsTile(
            icon: Icons.exposure,
            title: ref.watch(translationsProvider).settingsShowDecimals,
            trailing: Switch(
              value: showDecimal,
              onChanged: (value) => _toggleShowDecimal(value),
              activeColor: AppColors.primaryGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection(UserSetting? settings) {
    // We ignore settings.biometricEnabled here and use AuthService instead
    // because AuthScreen uses AuthService (secure storage) for the check.
    
    final authService = ref.watch(authServiceProvider);

    return FutureBuilder<Map<String, bool>>(
      future: Future.wait([
        authService.isAuthEnabled(),
        authService.isBiometricEnabled(),
      ]).then((values) => {
        'auth': values[0],
        'biometric': values[1],
      }),
      builder: (context, snapshot) {
        final isAppLockEnabled = snapshot.data?['auth'] ?? false;
        final biometricEnabled = snapshot.data?['biometric'] ?? false;

        return GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SettingsTile(
                icon: isAppLockEnabled ? Icons.lock : Icons.lock_open,
                title: ref.watch(translationsProvider).settingsLockApp,
                subtitle: isAppLockEnabled ? ref.watch(translationsProvider).settingsLockAppSubtitleOn : ref.watch(translationsProvider).settingsLockAppSubtitleOff,
                trailing: Switch(
                  value: isAppLockEnabled,
                  onChanged: (value) => _toggleAppLock(value),
                  activeColor: AppColors.primaryGold,
                ),
              ),
              _buildDivider(),
              Opacity(
                opacity: isAppLockEnabled ? 1.0 : 0.5,
                child: AbsorbPointer(
                  absorbing: !isAppLockEnabled,
                  child: SettingsTile(
                    icon: Icons.fingerprint,
                    title: ref.watch(translationsProvider).settingsBiometric,
                    trailing: Switch(
                      value: biometricEnabled,
                      onChanged: (value) => _toggleBiometric(value),
                      activeColor: AppColors.primaryGold,
                    ),
                  ),
                ),
              ),
              if (isAppLockEnabled) ...[
                _buildDivider(),
                SettingsTile(
                  icon: Icons.lock_outline,
                  title: ref.watch(translationsProvider).settingsChangePin,
                  onTap: () => _showChangePinDialog(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppInfoSection() {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SettingsTile(
            icon: Icons.info_outline,
            title: ref.watch(translationsProvider).settingsAboutTitle,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
          _buildDivider(),
          SettingsTile(
            icon: Icons.help_outline,
            title: ref.watch(translationsProvider).settingsHelp,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpFaqScreen()),
            ),
          ),
          _buildDivider(),
          SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: ref.watch(translationsProvider).settingsPrivacy,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
          ),
          _buildDivider(),
          SettingsTile(
            icon: Icons.description_outlined,
            title: ref.watch(translationsProvider).settingsTerms,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TermsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  void _showProfileSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const ProfileSelectorModal(),
    );
  }

  void _showCurrencyPicker(Currency current) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgDarkEnd,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ref.watch(translationsProvider).settingsSelectCurrency,
              style: AppTypography.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...Currency.values.map((c) => ListTile(
              leading: Text(c.symbol, style: const TextStyle(fontSize: 20)),
              title: Text(c.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text(c.code, style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
              trailing: current == c
                  ? const Icon(Icons.check, color: AppColors.primaryGold)
                  : null,
              onTap: () {
                _updateCurrency(c);
                Navigator.pop(context);
              },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleAppLock(bool enable) async {
    final authService = ref.read(authServiceProvider);
    
    if (enable) {
      final hasPin = await authService.hasPin();
      if (hasPin) {
        await authService.setAuthEnabled(true);
        setState(() {}); 
      } else {
        if (!mounted) return;
        // Await the dialog so we can refresh UI after it closes
        await _showNewPinDialog();
        setState(() {});
      }
    } else {
      if (!mounted) return;
      await authService.setAuthEnabled(false);
      setState(() {});
    }
  }

  Future<void> _showChangePinDialog() async {
    final authService = ref.read(authServiceProvider);
    final hasPin = await authService.hasPin();

    if (!mounted) return;

    if (hasPin) {
      await _showVerifyPinDialog();
    } else {
      await _showNewPinDialog();
    }
  }

  Future<void> _showVerifyPinDialog() {
    final pinController = TextEditingController();
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgDarkEnd,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(ref.watch(translationsProvider).settingsVerifyPin, style: AppTypography.textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassInput(
              controller: pinController,
              hintText: ref.watch(translationsProvider).settingsEnterCurrentPin,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(ref.watch(translationsProvider).genericCancel, style: const TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              final authService = ref.read(authServiceProvider);
              final isValid = await authService.verifyPin(pinController.text);
              if (!mounted) return;
              Navigator.pop(context);
              if (isValid) {
                await _showNewPinDialog();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text(ref.watch(translationsProvider).settingsIncorrectPin), backgroundColor: AppColors.error),
                );
              }
            },
            child: Text(ref.watch(translationsProvider).genericVerify, style: const TextStyle(color: AppColors.primaryGold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showNewPinDialog() {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgDarkEnd,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(ref.watch(translationsProvider).settingsSetNewPin, style: AppTypography.textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassInput(
              controller: pinController,
              hintText: ref.watch(translationsProvider).settingsEnterNewPin,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
            ),
            const SizedBox(height: 16),
            GlassInput(
              controller: confirmController,
              hintText: ref.watch(translationsProvider).settingsConfirmNewPin,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(ref.watch(translationsProvider).genericCancel, style: const TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              if (pinController.text.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text(ref.watch(translationsProvider).settingsPinLengthError)),
                );
                return;
              }
              if (pinController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text(ref.watch(translationsProvider).settingsPinMatchError)),
                );
                return;
              }
              
              final authService = ref.read(authServiceProvider);
              await authService.setPin(pinController.text);
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text(ref.watch(translationsProvider).settingsPinSetSuccess), backgroundColor: AppColors.success),
              );
            },
            child: Text(ref.watch(translationsProvider).genericSet, style: const TextStyle(color: AppColors.primaryGold)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateCurrency(Currency currency) async {

    final profileId = ref.read(activeProfileIdProvider);
    if (profileId != null) {
      await ref.read(settingsDaoProvider).setDefaultCurrency(profileId, currency);
    }
  }

  Future<void> _toggleShowDecimal(bool show) async {
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId != null) {
      await ref.read(settingsDaoProvider).setShowDecimal(profileId, show);
    }
  }

  Future<void> _toggleBiometric(bool enabled) async {
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId != null) {
      await ref.read(settingsDaoProvider).setBiometricEnabled(profileId, enabled);
    }
    
    // Update AuthService (secure storage) which is used by AuthScreen
    await ref.read(authServiceProvider).setBiometricEnabled(enabled);
    
    setState(() {});
  }

  Future<void> _showClearDataDialog() async {
    final confirmController = TextEditingController();
    bool canProceed = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.bgDarkEnd,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(ref.watch(translationsProvider).settingsClearDataTitle, style: const TextStyle(color: AppColors.error)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               Text(
                ref.watch(translationsProvider).settingsClearDataContent,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
               Text(
                ref.watch(translationsProvider).settingsClearDataConfirmPrompt,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              GlassInput(
                controller: confirmController,
                hintText: ref.watch(translationsProvider).settingsClearDataConfirmKeyword,
                onChanged: (value) {
                  setState(() {
                    canProceed = value == ref.watch(translationsProvider).settingsClearDataConfirmKeyword;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(ref.watch(translationsProvider).genericCancel, style: const TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: canProceed
                  ? () async {
                      Navigator.pop(context);
                      await _performClearData();
                    }
                  : null,
              child: Text(
                ref.watch(translationsProvider).settingsClearEverything,
                style: TextStyle(
                  color: canProceed ? AppColors.error : Colors.white24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performClearData() async {
    try {
      // Show loading
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
      );

      // Perform wipe
      await ref.read(databaseProvider).clearAllData();

      if (!mounted) return;
      // Close loading
      Navigator.pop(context);

      // Show success and maybe restart or go home
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Text(ref.watch(translationsProvider).settingsClearSuccess),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Force refresh of providers
      ref.invalidate(activeProfileIdProvider);
      ref.invalidate(activeProfileProvider);
      ref.invalidate(activeProfileSettingsProvider);

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ref.read(translationsProvider).settingsClearError}: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgDarkEnd,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final currentLocale = ref.watch(localeProvider);
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ref.watch(translationsProvider).settingsLanguage,
                style: AppTypography.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Text('🇺🇸', style: TextStyle(fontSize: 20)),
                title: const Text('English', style: TextStyle(color: Colors.white)),
                trailing: currentLocale.languageCode == 'en'
                    ? const Icon(Icons.check, color: AppColors.primaryGold)
                    : null,
                onTap: () async {
                  final profileId = ref.read(activeProfileIdProvider);
                  if (profileId != null) {
                    await ref.read(settingsDaoProvider).setLanguage(profileId, 'en');
                  }
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Text('🇮🇩', style: TextStyle(fontSize: 20)),
                title: const Text('Bahasa Indonesia', style: TextStyle(color: Colors.white)),
                trailing: currentLocale.languageCode == 'id'
                    ? const Icon(Icons.check, color: AppColors.primaryGold)
                    : null,
                onTap: () async {
                  final profileId = ref.read(activeProfileIdProvider);
                  if (profileId != null) {
                    await ref.read(settingsDaoProvider).setLanguage(profileId, 'id');
                  }
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
