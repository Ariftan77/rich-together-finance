import 'package:flutter/material.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDarkStart,
      appBar: AppBar(
        title: const Text('Terms of Service'),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Terms of Service',
                style: AppTypography.textTheme.headlineSmall?.copyWith(
                  color: AppColors.primaryGold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Last updated: February 2026',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),

              _buildSection(
                '1. Acceptance of Terms',
                'By using Rich Together, you agree to these Terms of Service. If you do not agree, please do not use this application.',
              ),

              _buildSection(
                '2. Use of the App',
                'Rich Together is a personal finance tracking tool designed for individual use. You are responsible for maintaining the confidentiality of your data and any PINs or passwords you set.',
              ),

              _buildSection(
                '3. Data Accuracy',
                'The app provides tools for tracking your finances, but we do not guarantee the accuracy of calculations. You should verify all financial information independently.',
              ),

              _buildSection(
                '4. Not Financial Advice',
                'Rich Together is not a substitute for professional financial advice. The app is for informational purposes only. Consult a qualified financial advisor for investment decisions.',
              ),

              _buildSection(
                '5. Limitation of Liability',
                'We are not liable for any financial losses, data loss, or damages arising from the use of this application.',
              ),

              _buildSection(
                '6. Updates',
                'We may update these terms from time to time. Continued use of the app constitutes acceptance of the updated terms.',
              ),

              _buildSection(
                '7. Contact',
                'For questions about these Terms of Service, contact us at legal@richtogether.app',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
