import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';


class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  String _version = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _version = info.version;
        _buildNumber = info.buildNumber;
      });
    } catch (e) {
      setState(() {
        _version = '1.0.0';
        _buildNumber = '1';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = AppThemeProvider.isLightMode(context);
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: AppColors.backgroundGradient(context),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(ref.watch(translationsProvider).settingsAboutTitle),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: isLight ? AppColors.textPrimaryLight : Colors.white),
            titleTextStyle: Theme.of(context).textTheme.displaySmall?.copyWith(color: isLight ? AppColors.textPrimaryLight : Colors.white),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),
              
              // App Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  image: const DecorationImage(
                    image: AssetImage('assets/images/app_icon.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // App Name
              Text(
                'About Richer',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.primaryGold,
                ),
              ),
              const SizedBox(height: 8),
              
              // Tagline
              Text(
                ref.watch(translationsProvider).aboutTagline,
                style: TextStyle(
                  color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),

              // Version
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${ref.watch(translationsProvider).settingsVersion} $_version (Build $_buildNumber)',
                  style: TextStyle(
                    color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // Features
              _buildFeatureSection(isLight),
              const SizedBox(height: 32),

              // Encryption Note
              _buildEncryptionNote(isLight),
              const SizedBox(height: 48),

              // Developer Info
              _buildInfoTile(
                icon: Icons.code,
                title: ref.watch(translationsProvider).aboutDeveloper,
                subtitle: 'Arif Tan',
                isLight: isLight,
              ),
              const SizedBox(height: 12),
              _buildInfoTile(
                icon: Icons.email_outlined,
                title: ref.watch(translationsProvider).aboutContact,
                subtitle: 'axiomtech.dev@gmail.com',
                isLight: isLight,
              ),
              const SizedBox(height: 48),

              // Copyright
              Text(
                ref.watch(translationsProvider).aboutCopyright,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        ),
      ],
    );
  }

  Widget _buildFeatureSection(bool isLight) {
    final t = ref.watch(translationsProvider);
    final features = [
      {'emoji': '📊', 'text': t.aboutFeatureExpense},
      {'emoji': '💰', 'text': t.aboutFeatureBudget},
      {'emoji': '📈', 'text': t.aboutFeatureAnalytics},
      {'emoji': '🎯', 'text': t.aboutFeatureGoals},
      {'emoji': '📋', 'text': t.aboutFeatureDebts},
      {'emoji': '🔄', 'text': t.aboutFeatureRecurring},
      {'emoji': '💱', 'text': t.aboutFeatureMultiCurrency},
      {'emoji': '👥', 'text': t.aboutFeatureMultiProfile},
      // {'emoji': '🔐', 'text': t.aboutFeatureEncrypted},
      {'emoji': '🔒', 'text': t.aboutFeatureOffline},
    ];

    final comingSoonFeatures = [
      {'emoji': '📉', 'text': t.aboutFeatureInvestment},
      {'emoji': '☁️', 'text': t.aboutFeatureSync},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.aboutFeatures,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.primaryGold,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...features.map((f) => _buildFeatureChip(f['emoji']!, f['text']!, isLight: isLight)),
            ...comingSoonFeatures.map((f) => _buildFeatureChip(
              f['emoji']!,
              '${f['text']!} (${t.aboutComingSoon})',
              isComingSoon: true,
              isLight: isLight,
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureChip(String emoji, String text, {bool isComingSoon = false, required bool isLight}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isComingSoon
            ? AppColors.primaryGold.withValues(alpha: 0.1)
            : (isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(20),
        border: isComingSoon
            ? Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3))
            : (isLight ? Border.all(color: Colors.black.withValues(alpha: 0.08)) : null),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: isComingSoon
                  ? AppColors.primaryGold.withValues(alpha: 0.8)
                  : (isLight ? AppColors.textPrimaryLight : Colors.white),
              fontSize: 13,
              fontStyle: isComingSoon ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isLight,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: isLight ? Border.all(color: Colors.black.withValues(alpha: 0.08)) : null,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryGold, size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isLight ? AppColors.textPrimaryLight : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEncryptionNote(bool isLight) {
    final t = ref.watch(translationsProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryGold.withValues(alpha: 0.05),
        border: Border.all(
          color: AppColors.primaryGold.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: AppColors.primaryGold, size: 20),
              const SizedBox(width: 8),
              Text(
                t.privacyEncryptionTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.primaryGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            t.privacyEncryptionContent,
            style: TextStyle(
              color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppColors.error, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.aboutEncryptionWarning,
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
