import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/profile_provider.dart';
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
                'Settings',
                style: AppTypography.textTheme.displaySmall,
              ),
              const SizedBox(height: 24),

              // Profile Section
              _buildSectionHeader('Profile'),
              const SizedBox(height: 12),
              activeProfile.when(
                data: (profile) => _buildProfileCard(profile),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 24),

              // Preferences Section
              _buildSectionHeader('Preferences'),
              const SizedBox(height: 12),
              settings.when(
                data: (userSettings) => _buildPreferencesSection(userSettings),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 24),

              // Security Section
              _buildSectionHeader('Security'),
              const SizedBox(height: 12),
              _buildSecuritySection(settings.valueOrNull),
              const SizedBox(height: 24),

              // App Info Section
              _buildSectionHeader('About'),
              const SizedBox(height: 12),
              _buildAppInfoSection(),
              const SizedBox(height: 24),

              // Version info at bottom
              Center(
                child: Text(
                  'Version $_appVersion',
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
    return GlassCard(
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
                  profile?.name ?? 'No Profile',
                  style: AppTypography.textTheme.titleMedium,
                ),
                Text(
                  'Tap to switch profile',
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
            icon: Icons.attach_money,
            title: 'Base Currency',
            subtitle: currency.code,
            onTap: () => _showCurrencyPicker(currency),
          ),
          _buildDivider(),
          SettingsTile(
            icon: Icons.exposure,
            title: 'Show Decimals',
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
    final biometricEnabled = settings?.biometricEnabled ?? true;

    return FutureBuilder<bool>(
      future: ref.read(authServiceProvider).isAuthEnabled(),
      builder: (context, snapshot) {
        final isAppLockEnabled = snapshot.data ?? false;

        return GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SettingsTile(
                icon: isAppLockEnabled ? Icons.lock : Icons.lock_open,
                title: 'Lock App',
                subtitle: isAppLockEnabled ? 'PIN/Biometric required' : 'App is unlocked',
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
                    title: 'Biometric Login',
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
                  title: 'Change PIN',
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
            title: 'About Rich Together',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
          _buildDivider(),
          SettingsTile(
            icon: Icons.help_outline,
            title: 'Help & FAQ',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpFaqScreen()),
            ),
          ),
          _buildDivider(),
          SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
          ),
          _buildDivider(),
          SettingsTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
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
              'Select Currency',
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
        title: Text('Verify Current PIN', style: AppTypography.textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassInput(
              controller: pinController,
              hintText: 'Enter current PIN',
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
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
                  const SnackBar(content: Text('Incorrect PIN'), backgroundColor: AppColors.error),
                );
              }
            },
            child: const Text('Verify', style: TextStyle(color: AppColors.primaryGold)),
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
        title: Text('Set New PIN', style: AppTypography.textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassInput(
              controller: pinController,
              hintText: 'Enter new PIN (6 digits)',
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
            ),
            const SizedBox(height: 16),
            GlassInput(
              controller: confirmController,
              hintText: 'Confirm new PIN',
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              if (pinController.text.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN must be 6 digits')),
                );
                return;
              }
              if (pinController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PINs do not match')),
                );
                return;
              }
              
              final authService = ref.read(authServiceProvider);
              await authService.setPin(pinController.text);
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PIN set & App Lock Enabled'), backgroundColor: AppColors.success),
              );
            },
            child: const Text('Set PIN', style: TextStyle(color: AppColors.primaryGold)),
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
  }
}
