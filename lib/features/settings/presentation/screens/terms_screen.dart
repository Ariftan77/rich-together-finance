import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';


class TermsScreen extends ConsumerWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trans = ref.watch(translationsProvider);
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
            title: Text(trans.termsTitle),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: isLight ? AppColors.textPrimaryLight : Colors.white),
            titleTextStyle: Theme.of(context).textTheme.displaySmall?.copyWith(color: isLight ? AppColors.textPrimaryLight : Colors.white),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(
                trans.termsTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.primaryGold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                trans.termsLastUpdated,
                style: TextStyle(
                  color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),

              _buildSection(trans.termsAcceptanceTitle, trans.termsAcceptanceContent, isLight),
              _buildSection(trans.termsUsageTitle, trans.termsUsageContent, isLight),
              _buildSection(trans.termsAccuracyTitle, trans.termsAccuracyContent, isLight),
              _buildSection(trans.termsAdviceTitle, trans.termsAdviceContent, isLight),
              _buildSection(trans.termsLiabilityTitle, trans.termsLiabilityContent, isLight),
              _buildSection(trans.termsUpdatesTitle, trans.termsUpdatesContent, isLight),
              _buildSection(trans.termsSecurityTitle, trans.termsSecurityContent, isLight),
              _buildSection(trans.termsContactTitle, trans.termsContactContent, isLight),
            ],
          ),
        ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, String content, bool isLight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isLight ? AppColors.textPrimaryLight : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: isLight ? const Color(0xFF374151) : Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
