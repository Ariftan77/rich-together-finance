import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';

import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/glass_input.dart';
import '../../../../shared/widgets/currency_picker_field.dart';
import '../../../../core/services/auth_service.dart';
import '../widgets/profile_selector_modal.dart';
import '../widgets/settings_tile.dart';
import 'about_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';
import 'help_faq_screen.dart';
import 'categories_screen.dart';
import 'backup_screen.dart';
import '../../providers/notification_settings_provider.dart';
import '../../../../core/services/remote_config_service.dart';
import '../../../../core/services/premium_auth_service.dart';
import '../../../../core/services/voucher_service.dart';
import '../../../../core/services/iap_service.dart' show IapService, IapResult;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/providers/announcement_providers.dart';
import '../../../../core/providers/service_providers.dart' show premiumStatusProvider;
import '../widgets/announcements_sheet.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _appVersion = '';
  bool _premiumSignInLoading = false;
  late Future<String?> _premiumFuture;

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackFirstSettingsVisit();
    _loadAppInfo();
    _premiumFuture = PremiumAuthService().getPremiumStatus();
  }

  void _refreshPremiumStatus() {
    setState(() {
      _premiumFuture = PremiumAuthService().getPremiumStatus();
    });
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
              Row(
                children: [
                  Builder(builder: (context) {
                    final isLight = AppThemeProvider.isLightMode(context);
                    return Text(
                      ref.watch(translationsProvider).navSettings,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: isLight ? AppColors.textPrimaryLight : Colors.white,
                      ),
                    );
                  }),
                  const Spacer(),
                  _buildNotificationBell(),
                ],
              ),
              const SizedBox(height: 24),

              // Premium Badge (if premium user)
              FutureBuilder<String?>(
                future: _premiumFuture,
                builder: (context, snapshot) {
                  if (snapshot.data != null) {
                    return Column(
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primaryGold.withValues(alpha: 0.3),
                                  AppColors.primaryGold.withValues(alpha: 0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primaryGold.withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.workspace_premium,
                                  color: AppColors.primaryGold,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'PREMIUM',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppColors.primaryGold,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

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

              // Notifications Section
              // _buildSectionHeader(ref.watch(translationsProvider).settingsNotifications),
              // const SizedBox(height: 12),
              // _buildNotificationsSection(),
              // const SizedBox(height: 24),

              // Premium Section (gated by Remote Config)
              if (RemoteConfigService().premiumEnabled) ...[
                _buildSectionHeader(ref.watch(translationsProvider).settingsPremium),
                const SizedBox(height: 12),
                _buildPremiumSection(),
                const SizedBox(height: 24),
              ],

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
                child: Builder(builder: (context) {
                  final isLight = AppThemeProvider.isLightMode(context);
                  return Text(
                    '${ref.watch(translationsProvider).settingsVersion} $_appVersion',
                    style: TextStyle(
                      color: isLight
                          ? const Color(0xFF94A3B8)
                          : Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Builder(builder: (context) {
      final isLight = AppThemeProvider.isLightMode(context);
      return Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: isLight ? AppColors.primaryGoldTextLight : AppColors.primaryGold,
        ),
      );
    });
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
                    Builder(builder: (context) {
                      final isLight = AppThemeProvider.isLightMode(context);
                      return Text(
                        profile?.name ?? ref.watch(translationsProvider).settingsNoProfile,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isLight ? AppColors.textPrimaryLight : Colors.white,
                        ),
                      );
                    }),
                      Builder(builder: (context) {
                        final isLight = AppThemeProvider.isLightMode(context);
                        return Text(
                          ref.watch(translationsProvider).settingsTapToSwitch,
                          style: TextStyle(
                            color: isLight
                                ? const Color(0xFF64748B)
                                : Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        );
                      }),
                    ],
                ),
              ),
              Builder(builder: (context) {
                final isLight = AppThemeProvider.isLightMode(context);
                return Icon(
                  Icons.chevron_right,
                  color: isLight
                      ? const Color(0xFF94A3B8)
                      : Colors.white.withValues(alpha: 0.5),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreferencesSection(UserSetting? settings) {
    final currency = settings?.defaultCurrency ?? Currency.idr;
    final showDecimal = settings?.showDecimal ?? false;
    final cardShadow = settings?.cardShadow ?? true;

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(builder: (context) {
                  final isLight = AppThemeProvider.isLightMode(context);
                  return Row(
                    children: [
                      Icon(
                        Icons.attach_money,
                        color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.6),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        ref.watch(translationsProvider).settingsBaseCurrency,
                        style: TextStyle(
                          color: isLight ? AppColors.textPrimaryLight : Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 10),
                CurrencyPickerField(
                  value: currency,
                  onChanged: (c) => _updateCurrency(c),
                ),
              ],
            ),
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
          _buildDivider(),
          SettingsTile(
            icon: Icons.brightness_6,
            title: 'Theme',
            subtitle: _themeModeName(settings?.themeMode ?? 0),
            onTap: () => _showThemeSelector(settings?.themeMode ?? 0),
          ),
          _buildDivider(),
          SettingsTile(
            icon: Icons.layers_outlined,
            title: ref.watch(translationsProvider).settingsCardShadow,
            trailing: Switch(
              value: cardShadow,
              onChanged: (value) => _toggleCardShadow(value),
              activeColor: AppColors.primaryGold,
            ),
          ),
        ],
      ),
    );
  }

  String _themeModeName(int mode) {
    return AppThemeModeX.fromValue(mode).label;
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

  Widget _buildNotificationBell() {
    final unread = ref.watch(unreadCountProvider);
    return GestureDetector(
      onTap: () => showAnnouncementsSheet(context, ref),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Builder(builder: (context) {
            final isLight = AppThemeProvider.isLightMode(context);
            return Icon(
              Icons.notifications_outlined,
              color: isLight ? const Color(0xFF374151) : Colors.white70,
              size: 28,
            );
          }),
          if (unread > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
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
            icon: Icons.feedback_outlined,
            title: ref.watch(translationsProvider).settingsSendFeedback,
            onTap: () => _showFeedbackDialog(),
          ),
          _buildDivider(),
          SettingsTile(
            icon: Icons.groups_outlined,
            title: ref.watch(translationsProvider).settingsJoinCommunity,
            onTap: () async {
              final url = Uri.parse('https://t.me/richercommunity');
              await launchUrl(url, mode: LaunchMode.externalApplication);
            },
          ),
          _buildDivider(),
          SettingsTile(
            icon: Icons.star_outline,
            title: ref.watch(translationsProvider).settingsRateUs,
            onTap: () async {
              final url = Uri.parse(
                'https://play.google.com/store/apps/details?id=com.axiomtechdev.richtogether',
              );
              await launchUrl(url, mode: LaunchMode.externalApplication);
            },
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

  Future<void> _showFeedbackDialog() async {
    final controller = TextEditingController();
    bool isSending = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
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
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          title: Text(
            ref.watch(translationsProvider).settingsSendFeedback,
            style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white),
            decoration: InputDecoration(
              hintText: ref.watch(translationsProvider).settingsSendFeedbackHint,
              hintStyle: TextStyle(color: isLight ? const Color(0xFF94A3B8) : Colors.white38),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: isLight ? const Color(0xFFCBD5E1) : Colors.white24),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primaryGold),
              ),
            ),
          ),
          actions: [
            if (!isSending)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  ref.watch(translationsProvider).genericCancel,
                  style: TextStyle(color: isLight ? const Color(0xFF374151) : Colors.white70),
                ),
              ),
            isSending
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGold),
                    ),
                  )
                : TextButton(
                    onPressed: () async {
                      if (controller.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ref.watch(translationsProvider).settingsSendFeedbackEmpty), backgroundColor: AppColors.error),
                        );
                        return;
                      }

                      setState(() => isSending = true);
                      final success = await _sendEmailFeedback(controller.text.trim());
                      setState(() => isSending = false);

                      if (success && mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ref.watch(translationsProvider).settingsSendFeedbackSuccess), backgroundColor: AppColors.success),
                        );
                      }
                    },
                    child: Text(ref.watch(translationsProvider).settingsSendFeedback, style: const TextStyle(color: AppColors.primaryGold)),
                  ),
          ],
        );
        },
      ),
    );
  }

  Future<bool> _sendEmailFeedback(String body) async {
    try {
      // The user specified the remote config key is the app key for axiomtech.dev@gmail.com
      // The email address itself is axiomtech.dev@gmail.com. We fetch the password (app key) from RC.
      final String appKey = RemoteConfigService().emailAppKey;
      final String targetEmail = 'axiomtech.dev@gmail.com'; 

      final smtpServer = gmail(targetEmail, appKey);

      // Create our message.
      final message = Message()
        ..from = Address(targetEmail, 'Richer Feedback')
        ..recipients.add(targetEmail) // send it to ourselves
        ..subject = 'App Feedback / Bug Report: ${DateTime.now().toIso8601String()}'
        ..text = 'Feedback:\n\n$body\n\nApp Version: $_appVersion\nUserId: ${PremiumAuthService().email ?? "Not logged in"}';

      await send(message, smtpServer);
      return true;
    } on MailerException catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('${ref.read(translationsProvider).settingsSendFeedbackError}${e.message}'), backgroundColor: AppColors.error),
         );
      }
      return false;
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('${ref.read(translationsProvider).settingsSendFeedbackError}$e'), backgroundColor: AppColors.error),
         );
      }
      return false;
    }
  }

  Widget _buildDivider() {
    return Builder(builder: (context) {
      final isLight = AppThemeProvider.isLightMode(context);
      return Divider(
        height: 1,
        color: isLight
            ? Colors.black.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.1),
      );
    });
  }

  void _showProfileSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const ProfileSelectorModal(),
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
        title: Text(ref.watch(translationsProvider).settingsVerifyPin, style: Theme.of(context).textTheme.titleLarge),
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
            child: Text(
              ref.watch(translationsProvider).genericCancel,
              style: TextStyle(color: isLight ? const Color(0xFF374151) : Colors.white70),
            ),
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
        );
      },
    );
  }

  Future<void> _showNewPinDialog() {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();

    return showDialog(
      context: context,
      barrierDismissible: false,
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
        title: Text(ref.watch(translationsProvider).settingsSetNewPin, style: Theme.of(context).textTheme.titleLarge),
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
            child: Text(
              ref.watch(translationsProvider).genericCancel,
              style: TextStyle(color: isLight ? const Color(0xFF374151) : Colors.white70),
            ),
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
        );
      },
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

  Future<void> _toggleCardShadow(bool show) async {
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId != null) {
      await ref.read(settingsDaoProvider).setCardShadow(profileId, show);
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
        builder: (context, setState) {
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
          title: Text(ref.watch(translationsProvider).settingsClearDataTitle, style: const TextStyle(color: AppColors.error)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ref.watch(translationsProvider).settingsClearDataContent,
                style: TextStyle(color: isLight ? const Color(0xFF374151) : Colors.white70),
              ),
              const SizedBox(height: 16),
              Text(
                ref.watch(translationsProvider).settingsClearDataConfirmPrompt,
                style: TextStyle(
                  color: isLight ? AppColors.textPrimaryLight : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
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
              child: Text(
                ref.watch(translationsProvider).genericCancel,
                style: TextStyle(color: isLight ? const Color(0xFF374151) : Colors.white70),
              ),
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
                  color: canProceed ? AppColors.error : (isLight ? const Color(0xFFCBD5E1) : Colors.white24),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          );
        },
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

  void _showThemeSelector(int currentMode) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDefault
          ? AppColors.bgDarkEnd
          : isLight
              ? Colors.white
              : const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final sheetThemeMode = AppThemeProvider.of(context);
        final isSheetLight = sheetThemeMode == AppThemeMode.light ||
            (sheetThemeMode == AppThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.light);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isSheetLight ? const Color(0xFFCBD5E1) : Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ...AppThemeMode.values.map((mode) => ListTile(
              leading: Icon(mode.icon, color: AppColors.primaryGold),
              title: Text(
                mode.label,
                style: TextStyle(
                  color: isSheetLight ? AppColors.textPrimaryLight : Colors.white,
                ),
              ),
              trailing: currentMode == mode.value
                  ? const Icon(Icons.check, color: AppColors.primaryGold)
                  : null,
              onTap: () { Navigator.pop(context); _updateThemeMode(mode.value); },
            )),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Future<void> _updateThemeMode(int mode) async {
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId != null) {
      await ref.read(settingsDaoProvider).setThemeMode(profileId, mode);
    }
  }

  void _showLanguageSelector() {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDefault
          ? AppColors.bgDarkEnd
          : isLight
              ? Colors.white
              : const Color(0xFF111111),
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
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Text('🇺🇸', style: TextStyle(fontSize: 20)),
                title: Text(
                  'English',
                  style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white),
                ),
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
                title: Text(
                  'Bahasa Indonesia',
                  style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white),
                ),
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

  Widget _buildNotificationsSection() {
    final notifSettings = ref.watch(notificationSettingsProvider);
    final trans = ref.watch(translationsProvider);

    return GlassCard(
      child: Column(
        children: [
          SettingsTile(
            icon: Icons.notifications_active,
            title: trans.settingsDailyReminder,
            trailing: Switch(
              value: notifSettings.isReminderEnabled,
              onChanged: (value) {
                ref.read(notificationSettingsProvider.notifier).toggleReminder(value);
              },
              activeColor: AppColors.primaryGold,
            ),
          ),
          if (notifSettings.isReminderEnabled) ...[
            Builder(builder: (context) {
              final isLight = AppThemeProvider.isLightMode(context);
              return Divider(
                color: isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.1),
              );
            }),
            SettingsTile(
              icon: Icons.access_time,
              title: trans.settingsReminderTime,
              subtitle: notifSettings.reminderTime.format(context),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: notifSettings.reminderTime,
                );
                if (picked != null) {
                  ref.read(notificationSettingsProvider.notifier).setReminderTime(picked);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPremiumSection() {
    final auth = PremiumAuthService();
    final trans = ref.watch(translationsProvider);
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Premium Benefits tile — always visible at the very top
          SettingsTile(
            icon: Icons.workspace_premium,
            title: trans.premiumBenefitsTitle,
            subtitle: trans.premiumBenefitsSeeWhat,
            onTap: () => _showPremiumBenefitsModal(context),
          ),
          _buildDivider(),
          // Account tile — signed in or sign-in options
          if (auth.isSignedIn)
            _buildSignedInAccountTile(auth)
          else
            ..._buildSignInOptions(),
          FutureBuilder<String?>(
            future: _premiumFuture,
            builder: (context, snapshot) {
              final isPremium = snapshot.data != null;
              return Column(
                children: [
                  if (!isPremium) ...[
                    _buildDivider(),
                    if (RemoteConfigService().voucherEnabled) ...[
                      SettingsTile(
                        icon: Icons.card_giftcard,
                        title: trans.premiumRedeemVoucher,
                        subtitle: trans.premiumLifetimeSubtitle,
                        onTap: _showVoucherDialog,
                      ),
                      _buildDivider(),
                      SettingsTile(
                        icon: Icons.star,
                        title: trans.premiumGetPremium,
                        subtitle: trans.premiumGetPremiumSubtitle,
                        onTap: () => _handleBuyPremium(),
                      ),
                    ],
                    if (RemoteConfigService().iapEnabled) ...[
                      if (RemoteConfigService().voucherEnabled)
                        _buildDivider(),
                      if (!RemoteConfigService().voucherEnabled) ...[
                        SettingsTile(
                          icon: Icons.star,
                          title: trans.premiumGetPremium,
                          subtitle: trans.premiumGetPremiumSubtitle,
                          onTap: () => _handleBuyPremium(),
                        ),
                        _buildDivider(),
                      ],
                      // TODO: Upcoming feature — Sync Subscription (yearly)
                      // SettingsTile(
                      //   icon: Icons.cloud_sync,
                      //   title: trans.premiumSyncSubscription,
                      //   subtitle: trans.premiumSyncSubtitle,
                      //   onTap: () => _handleBuySync(),
                      // ),
                    ],
                  ],
                  _buildDivider(),
                  SettingsTile(
                    icon: Icons.restore,
                    title: trans.premiumRestorePurchase,
                    onTap: _handleRestorePurchase,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSignInOptions() {
    final trans = ref.watch(translationsProvider);
    const syncSubtitle = 'Sign in to restore purchases across devices and sync your premium status';
    return [
      SettingsTile(
        icon: Icons.account_circle_outlined,
        title: trans.premiumSignInGoogle,
        subtitle: syncSubtitle,
        trailing: _premiumSignInLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryGold,
                ),
              )
            : null,
        onTap: _premiumSignInLoading ? null : _handleGoogleSignIn,
      ),
      if (Platform.isIOS) ...[
        _buildDivider(),
        SettingsTile(
          icon: Icons.apple,
          title: trans.premiumSignInApple,
          subtitle: syncSubtitle,
          trailing: _premiumSignInLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryGold,
                  ),
                )
              : null,
          onTap: _premiumSignInLoading ? null : _handleAppleSignIn,
        ),
      ],
    ];
  }

  Widget _buildSignedInAccountTile(PremiumAuthService auth) {
    final photoUrl = auth.photoUrl;
    final isApple = auth.activeProvider == AuthProvider.apple;
    return Builder(builder: (context) {
      final isLight = AppThemeProvider.isLightMode(context);
      return InkWell(
        onTap: null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryGold.withValues(alpha: 0.15),
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? isApple
                        ? const Icon(Icons.apple, color: AppColors.primaryGold, size: 20)
                        : Text(
                            (auth.displayName?.isNotEmpty == true)
                                ? auth.displayName![0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AppColors.primaryGold,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth.displayName ?? (isApple ? 'Apple Account' : 'Google Account'),
                      style: TextStyle(
                        color: isLight ? AppColors.textPrimaryLight : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (auth.email != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          auth.email!,
                          style: TextStyle(
                            color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.logout,
                  color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.6),
                  size: 20,
                ),
                onPressed: _handleGoogleSignOut,
                tooltip: 'Sign out',
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _premiumSignInLoading = true);
    final ok = await PremiumAuthService().signInWithGoogle();
    if (!mounted) return;
    setState(() => _premiumSignInLoading = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(translationsProvider).premiumSignInFailed)),
      );
      return;
    }
    AnalyticsService.logSignInProvider(provider: 'google');
    // Refresh badge/section now that we're signed in
    _refreshPremiumStatus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ref.read(translationsProvider).premiumSignInSuccess)),
    );
    // Show reopen-app dialog if the signed-in account already has premium
    final premiumStatus = await PremiumAuthService().getPremiumStatus();
    if (!mounted) return;
    if (premiumStatus != null) {
      _showSuccessDialog();
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _premiumSignInLoading = true);
    final ok = await PremiumAuthService().signInWithApple();
    if (!mounted) return;
    setState(() => _premiumSignInLoading = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(translationsProvider).premiumSignInFailed)),
      );
      return;
    }
    AnalyticsService.logSignInProvider(provider: 'apple');
    _refreshPremiumStatus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ref.read(translationsProvider).premiumSignInSuccess)),
    );
    final premiumStatus = await PremiumAuthService().getPremiumStatus();
    if (!mounted) return;
    if (premiumStatus != null) {
      _showSuccessDialog();
    }
  }

  Future<void> _handleGoogleSignOut() async {
    await PremiumAuthService().signOut();
    if (!mounted) return;
    _refreshPremiumStatus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ref.read(translationsProvider).premiumSignOutSuccess)),
    );
  }

  Future<void> _showVoucherDialog() async {
    final trans = ref.read(translationsProvider);

    if (!mounted) return;
    final codeController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final themeMode = AppThemeProvider.of(context);
        final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
        final isDefault = themeMode == AppThemeMode.defaultTheme;
        return AlertDialog(
        backgroundColor: isDefault ? AppColors.bgDarkEnd : isLight ? Colors.white : const Color(0xFF111111),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        title: Text(
          trans.premiumRedeemVoucher,
          style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white),
        ),
        content: TextField(
          controller: codeController,
          style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white),
          decoration: InputDecoration(
            hintText: trans.premiumEnterVoucherCode,
            hintStyle: TextStyle(color: isLight ? const Color(0xFF94A3B8) : Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: isLight ? const Color(0xFFCBD5E1) : Colors.white24),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primaryGold),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              trans.genericCancel,
              style: TextStyle(color: isLight ? const Color(0xFF374151) : Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, codeController.text.trim()),
            child: Text(trans.premiumRedeem, style: const TextStyle(color: AppColors.primaryGold)),
          ),
        ],
        );
      },
    );

    if (result != null && result.isNotEmpty && mounted) {
      // Pass requireSignIn: false — unsigned voucher redemption is now allowed
      // on all platforms. The sign-in benefits modal is shown on success.
      final voucherResult = await VoucherService().redeem(
        result,
        requireSignIn: false,
      );
      if (!mounted) return;

      if (voucherResult == VoucherResult.success) {
        _refreshPremiumStatus();
        // Show success snackbar then nudge unsigned users to sign in.
        if (!PremiumAuthService().isSignedIn) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(trans.premiumActivated),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
          await Future.delayed(const Duration(milliseconds: 800));
          if (!mounted) return;
          await _showSignInBenefitsModal();
        } else {
          _showSuccessDialog();
        }
      } else {
        final message = switch (voucherResult) {
          VoucherResult.invalid => trans.premiumInvalidVoucher,
          VoucherResult.alreadyUsed => trans.premiumVoucherUsed,
          VoucherResult.notSignedIn => trans.premiumNotSignedIn,
          VoucherResult.disabled => trans.premiumVoucherDisabled,
          VoucherResult.success => '',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _handleBuyPremium() async {
    final trans = ref.read(translationsProvider);
    final auth = PremiumAuthService();

    // If the user already has premium, restore directly — calling buyPremium()
    // would trigger a Play Store "already owned" error and leave the UI stuck.
    if (auth.isPremium) {
      _refreshPremiumStatus();
      _showSuccessDialog();
      return;
    }

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      ),
    );

    // Both iOS and Android now skip the sign-in check — unsigned purchases are
    // stored locally and synced to the backend when the user later signs in.
    final result = await IapService().buyPremium(
      skipSignInCheck: true,
    );
    if (!mounted) return;
    Navigator.pop(context); // Close loading

    if (result == IapResult.success) {
      if (mounted) {
        ref.invalidate(premiumStatusProvider);
        _refreshPremiumStatus();
        // Nudge unsigned users to sign in after a brief success confirmation.
        if (!auth.isSignedIn) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(trans.premiumActivated),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
          await Future.delayed(const Duration(milliseconds: 800));
          if (!mounted) return;
          await _showSignInBenefitsModal();
        } else {
          _showSuccessDialog();
        }
      }
    } else {
      if (mounted) {
        _showIapErrorSnackBar(result, trans, onRetry: _handleBuyPremium);
      }
    }
  }

  Future<void> _handleBuySync() async {
    final trans = ref.read(translationsProvider);
    final auth = PremiumAuthService();

    // Check if signed in
    if (!auth.isSignedIn) {
      final provider = await _showSignInProviderDialog();
      if (provider == null) return;

      // Sign in
      setState(() => _premiumSignInLoading = true);
      final ok = provider == 'apple'
          ? await auth.signInWithApple()
          : await auth.signInWithGoogle();
      if (!mounted) return;
      setState(() => _premiumSignInLoading = false);

      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trans.premiumSignInFailed), backgroundColor: AppColors.error),
        );
        return;
      }
    }

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      ),
    );

    // Make purchase
    final result = await IapService().buySync();
    if (!mounted) return;
    Navigator.pop(context); // Close loading

    if (result == IapResult.success) {
      if (mounted) {
        _refreshPremiumStatus();
        _showSuccessDialog();
      }
    } else {
      if (mounted) {
        _showIapErrorSnackBar(result, trans, onRetry: _handleBuySync);
      }
    }
  }

  /// Shows an appropriate snackbar for IAP error results.
  ///
  /// - [IapResult.userCanceled]: silently ignored — no snackbar shown.
  /// - Retryable errors (serviceUnavailable, serviceDisconnected): snackbar
  ///   with a "Try Again" action that re-invokes [onRetry].
  /// - [IapResult.activationFailed]: snackbar with "Contact Support" action.
  /// - All other errors: plain error snackbar with localized message.
  void _showIapErrorSnackBar(
    IapResult result,
    dynamic trans, {
    required VoidCallback onRetry,
  }) {
    // USER_CANCELED: user chose to back out — never show error UI.
    if (result == IapResult.userCanceled) return;

    final messenger = ScaffoldMessenger.of(context);

    // Retryable infrastructure errors — offer a "Try Again" action.
    if (result == IapResult.serviceUnavailable ||
        result == IapResult.serviceDisconnected) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(trans.iapErrorServiceUnavailable as String),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: trans.iapActionTryAgain as String,
            textColor: Colors.white,
            onPressed: onRetry,
          ),
        ),
      );
      return;
    }

    // Activation succeeded on Play Store but backend call failed — direct to
    // support so the user can recover their purchase.
    if (result == IapResult.activationFailed) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(trans.iapErrorActivationFailed as String),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: trans.iapActionContactSupport as String,
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
      messenger.showSnackBar(
        SnackBar(
          content: Text(trans.iapErrorAlreadyOwned as String),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: trans.iapActionRestore as String,
            textColor: Colors.white,
            onPressed: _handleRestorePurchase,
          ),
        ),
      );
      return;
    }

    // All other non-retryable errors — plain localized message.
    final message = switch (result) {
      IapResult.notSignedIn => trans.premiumNotSignedIn as String,
      IapResult.productNotFound => trans.iapErrorProductNotFound as String,
      IapResult.billingUnavailable => trans.iapErrorBillingUnavailable as String,
      IapResult.featureNotSupported => trans.iapErrorFeatureNotSupported as String,
      IapResult.disabled => trans.iapErrorDisabled as String,
      _ => trans.iapErrorPurchaseFailed as String,
    };
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  /// Returns 'google', 'apple', or null (cancelled).
  Future<String?> _showSignInProviderDialog() async {
    final trans = ref.read(translationsProvider);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final themeMode = AppThemeProvider.of(context);
        final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
        final isDefault = themeMode == AppThemeMode.defaultTheme;
        return AlertDialog(
        backgroundColor: isDefault ? AppColors.bgDarkEnd : isLight ? Colors.white : const Color(0xFF111111),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.account_circle, color: AppColors.primaryGold),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                trans.signInRequired,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trans.signInRequiredDesc,
              style: TextStyle(
                color: isLight ? AppColors.textPrimaryLight : Colors.white.withValues(alpha: 0.9),
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
                        color: isLight ? AppColors.textPrimaryLight : Colors.white.withValues(alpha: 0.8),
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
            onPressed: () => Navigator.pop(context),
            child: Text(
              trans.genericCancel,
              style: TextStyle(color: isLight ? const Color(0xFF374151) : Colors.white70),
            ),
          ),
          if (Platform.isIOS)
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, 'apple'),
              icon: const Icon(Icons.apple, size: 18),
              label: const Text('Apple'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLight ? Colors.black : Colors.white,
                foregroundColor: isLight ? Colors.white : Colors.black,
              ),
            ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, 'google'),
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Google'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
              foregroundColor: Colors.black,
            ),
          ),
        ],
        );
      },
    );
    return result;
  }

  Future<void> _handleRestorePurchase() async {
    final trans = ref.read(translationsProvider);
    final auth = PremiumAuthService();
    if (!auth.isSignedIn) {
      final provider = await _showSignInProviderDialog();
      if (provider == null) return;
      final ok = provider == 'apple'
          ? await auth.signInWithApple()
          : await auth.signInWithGoogle();
      if (!ok || !mounted) return;
      AnalyticsService.logSignInProvider(provider: provider);
    }

    // Check Supabase
    final status = await auth.getPremiumStatus();
    if (status != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${trans.premiumRestored}$status'), backgroundColor: AppColors.success),
      );
      _refreshPremiumStatus();
      _showSuccessDialog();
      return;
    }

    // Fallback: check platform store
    await IapService().restorePurchases();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          Platform.isIOS ? trans.premiumCheckingAppStore : trans.premiumCheckingPlayStore,
        )),
      );
    }
  }

  void _showPremiumBenefitsModal(BuildContext context) {
    final trans = ref.read(translationsProvider);
    final themeMode = AppThemeProvider.of(context);
    final isDefault = themeMode == AppThemeMode.defaultTheme;
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

    final sheetBg = isDefault
        ? const Color(0xFF1A1208)
        : isLight
            ? Colors.white
            : const Color(0xFF111111);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final accentColor = Theme.of(context).colorScheme.primary;
        final onSurface = Theme.of(context).colorScheme.onSurface;
        final surfaceColor = Theme.of(context).colorScheme.surface;
        final textMuted = onSurface.withValues(alpha: 0.5);
        final rowAlt = onSurface.withValues(alpha: 0.08);
        final textPrimary = onSurface;

        // Table data: [featureLabel, freeValue, isPremiumUnlimited, isFreeCheck]
        // isPremiumUnlimited: true = show "Unlimited", false = show check icon
        // isFreeCheck: true = show locked icon/muted text, false show the freeValue string
        final tableRows = [
          _BenefitsRow(
            feature: trans.premiumFeatureWallets,
            freeLabel: trans.premiumFreeLimit5,
            premiumLabel: trans.premiumUnlimited,
            freeLocked: false,
          ),
          _BenefitsRow(
            feature: trans.premiumFeatureGoals,
            freeLabel: trans.premiumFreeLimit3,
            premiumLabel: trans.premiumUnlimited,
            freeLocked: false,
          ),
          _BenefitsRow(
            feature: trans.premiumFeatureBudgets,
            freeLabel: trans.premiumFreeLimit3,
            premiumLabel: trans.premiumUnlimited,
            freeLocked: false,
          ),
          _BenefitsRow(
            feature: trans.premiumFeatureProfiles,
            freeLabel: trans.premiumFreeLimit1,
            premiumLabel: trans.premiumUnlimited,
            freeLocked: false,
          ),
          _BenefitsRow(
            feature: trans.premiumFeatureAnalytics,
            freeLabel: trans.premiumFreeLocked,
            premiumLabel: '',
            freeLocked: true,
          ),
          _BenefitsRow(
            feature: trans.premiumFeatureCloudBackup,
            freeLabel: trans.premiumFreeLocked,
            premiumLabel: '',
            freeLocked: true,
          ),
        ];

        final price = IapService().premiumPrice;

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle pill
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: onSurface.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),

                // Modal title
                Text(
                  trans.premiumBenefitsModalTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),

                // Subtitle
                Text(
                  trans.premiumBenefitsModalSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Comparison table
                Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Table header row
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            // Feature column header (empty label)
                            const Expanded(flex: 3, child: SizedBox.shrink()),
                            // Free header
                            Expanded(
                              flex: 2,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lock_outline,
                                    size: 13,
                                    color: textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Free',
                                    style: TextStyle(
                                      color: textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Premium header
                            Expanded(
                              flex: 2,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 13,
                                    color: accentColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Premium',
                                    style: TextStyle(
                                      color: accentColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Divider below header
                      Divider(
                        height: 1,
                        color: onSurface.withValues(alpha: 0.08),
                      ),

                      // Data rows
                      ...tableRows.asMap().entries.map((entry) {
                        final index = entry.key;
                        final row = entry.value;
                        final isAlternate = index.isOdd;
                        return Container(
                          decoration: BoxDecoration(
                            color: isAlternate ? rowAlt : Colors.transparent,
                            borderRadius: index == tableRows.length - 1
                                ? const BorderRadius.only(
                                    bottomLeft: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  )
                                : null,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                            child: Row(
                              children: [
                                // Feature name
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    row.feature,
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                // Free cell
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: row.freeLocked
                                        ? Icon(
                                            Icons.close_rounded,
                                            size: 16,
                                            color: textMuted,
                                          )
                                        : Text(
                                            row.freeLabel,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                  ),
                                ),
                                // Premium cell
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: row.premiumLabel.isEmpty
                                        ? Icon(
                                            Icons.check_circle_rounded,
                                            size: 18,
                                            color: accentColor,
                                          )
                                        : Text(
                                            row.premiumLabel,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: accentColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // Price line (only when available from the store)
                if (price != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    price,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textMuted,
                      side: BorderSide(
                        color: onSurface.withValues(alpha: 0.2),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      trans.premiumBenefitsClose,
                      style: TextStyle(
                        color: textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Shows a bottom sheet nudging the user to sign in after a successful
  /// unsigned purchase or voucher redemption. Attempts Google sign-in when the
  /// user taps the sign-in button and invalidates premium status on success.
  Future<void> _showSignInBenefitsModal() async {
    final trans = ref.read(translationsProvider);
    final auth = PremiumAuthService();
    final themeMode = AppThemeProvider.of(context);
    final isDefault = themeMode == AppThemeMode.defaultTheme;
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

    final sheetBg = isDefault
        ? const Color(0xFF1A1208)
        : isLight
            ? Colors.white
            : const Color(0xFF111111);
    final textPrimary = isLight ? AppColors.textPrimaryLight : Colors.white;
    final textMuted = isLight
        ? const Color(0xFF64748B)
        : Colors.white.withValues(alpha: 0.6);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _SettingsSignInBenefitsSheet(
        sheetBg: sheetBg,
        textPrimary: textPrimary,
        textMuted: textMuted,
        trans: trans,
        onSignIn: () async {
          Navigator.pop(sheetContext);
          if (!mounted) return;
          setState(() => _premiumSignInLoading = true);
          final ok = await auth.signInWithGoogle();
          if (!mounted) return;
          setState(() => _premiumSignInLoading = false);
          if (ok) {
            AnalyticsService.logSignInProvider(provider: 'google');
            ref.invalidate(premiumStatusProvider);
            _refreshPremiumStatus();
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

  void _showSuccessDialog() {
    final trans = ref.read(translationsProvider);
    showDialog(
      context: context,
      builder: (context) {
        final themeMode = AppThemeProvider.of(context);
        final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
        final isDefault = themeMode == AppThemeMode.defaultTheme;
        return AlertDialog(
          backgroundColor: isDefault ? AppColors.bgDarkEnd : isLight ? Colors.white : const Color(0xFF111111),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.star, color: AppColors.primaryGold),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  trans.premiumVoucherSuccessTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Text(
            trans.premiumVoucherSuccessBody,
            style: TextStyle(
              color: isLight ? AppColors.textPrimaryLight : Colors.white.withValues(alpha: 0.9),
              height: 1.5,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: Colors.black,
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

}

// ---------------------------------------------------------------------------
// Sign-In Benefits Sheet — shown after unsigned purchase/voucher success
// ---------------------------------------------------------------------------

class _SettingsSignInBenefitsSheet extends StatefulWidget {
  final Color sheetBg;
  final Color textPrimary;
  final Color textMuted;
  final dynamic trans;
  final Future<void> Function() onSignIn;
  final VoidCallback onSkip;

  const _SettingsSignInBenefitsSheet({
    required this.sheetBg,
    required this.textPrimary,
    required this.textMuted,
    required this.trans,
    required this.onSignIn,
    required this.onSkip,
  });

  @override
  State<_SettingsSignInBenefitsSheet> createState() =>
      _SettingsSignInBenefitsSheetState();
}

class _SettingsSignInBenefitsSheetState
    extends State<_SettingsSignInBenefitsSheet> {
  bool _signingIn = false;

  @override
  Widget build(BuildContext context) {
    final benefits = [
      widget.trans.signInBenefitRestore as String,
      widget.trans.signInBenefitBackup as String,
    ];

    return Container(
      decoration: BoxDecoration(
        color: widget.sheetBg,
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
              color: widget.textMuted.withValues(alpha: 0.4),
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
              color: widget.textPrimary,
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
                        color: widget.textMuted,
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
                _signingIn
                    ? ''
                    : widget.trans.signInBenefitsSignInButton as String,
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
                foregroundColor: widget.textMuted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: widget.textMuted.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Text(
                widget.trans.signInBenefitsSkipButton as String,
                style: TextStyle(
                  fontSize: 14,
                  color: widget.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal data model for the premium benefits comparison table
// ---------------------------------------------------------------------------

class _BenefitsRow {
  final String feature;
  final String freeLabel;
  final String premiumLabel; // empty string = show check icon instead
  final bool freeLocked;     // true = show X icon instead of freeLabel text

  const _BenefitsRow({
    required this.feature,
    required this.freeLabel,
    required this.premiumLabel,
    required this.freeLocked,
  });
}

