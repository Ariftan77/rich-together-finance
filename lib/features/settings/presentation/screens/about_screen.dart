import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';

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
    return Scaffold(
      backgroundColor: AppColors.bgDarkStart,
      appBar: AppBar(
        title: Text(ref.watch(translationsProvider).settingsAboutTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.bgDarkStart, AppColors.bgDarkEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              
              // App Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('💰', style: TextStyle(fontSize: 48)),
                ),
              ),
              const SizedBox(height: 24),

              // App Name
              Text(
                'Rich Together',
                style: AppTypography.textTheme.headlineMedium?.copyWith(
                  color: AppColors.primaryGold,
                ),
              ),
              const SizedBox(height: 8),
              
              // Tagline
              Text(
                ref.watch(translationsProvider).aboutTagline,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),

              // Version
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${ref.watch(translationsProvider).settingsVersion} $_version (Build $_buildNumber)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // Features
              _buildFeatureSection(),
              const SizedBox(height: 48),

              // Developer Info
              _buildInfoTile(
                icon: Icons.code,
                title: ref.watch(translationsProvider).aboutDeveloper,
                subtitle: 'Arif Tan',
              ),
              const SizedBox(height: 12),
              _buildInfoTile(
                icon: Icons.email_outlined,
                title: ref.watch(translationsProvider).aboutContact,
                subtitle: 'axiomtech.dev@gmail.com',
              ),
              const SizedBox(height: 48),

              // Copyright
              Text(
                ref.watch(translationsProvider).aboutCopyright,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureSection() {
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
          style: AppTypography.textTheme.titleMedium?.copyWith(
            color: AppColors.primaryGold,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...features.map((f) => _buildFeatureChip(f['emoji']!, f['text']!)),
            ...comingSoonFeatures.map((f) => _buildFeatureChip(
              f['emoji']!,
              '${f['text']!} (${t.aboutComingSoon})',
              isComingSoon: true,
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureChip(String emoji, String text, {bool isComingSoon = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isComingSoon
            ? AppColors.primaryGold.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: isComingSoon
            ? Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3))
            : null,
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
                  : Colors.white,
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
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
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
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
