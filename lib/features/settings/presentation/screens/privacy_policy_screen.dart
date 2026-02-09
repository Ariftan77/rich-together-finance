import 'package:flutter/material.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDarkStart,
      appBar: AppBar(
        title: const Text('Privacy Policy'),
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
                'Privacy Policy',
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
                'Data Collection',
                'Rich Together is designed with your privacy in mind. All your financial data is stored locally on your device. We do not collect, transmit, or store any of your personal financial information on external servers.',
              ),

              _buildSection(
                'Local Storage',
                'Your data is stored securely on your device using encrypted SQLite database. The app operates fully offline, meaning your data never leaves your phone unless you explicitly choose to backup.',
              ),

              _buildSection(
                'Optional Backup',
                'If you choose to use Google Drive backup, your data will be encrypted and stored in your personal Google Drive account. We do not have access to your backup files.',
              ),

              _buildSection(
                'No Third-Party Analytics',
                'We do not use third-party analytics services that track your behavior or collect personal information.',
              ),

              _buildSection(
                'Data Deletion',
                'You can delete all your data at any time from the Settings menu. Deleting the app will also remove all locally stored data.',
              ),

              _buildSection(
                'Contact',
                'If you have questions about this Privacy Policy, please contact us at privacy@richtogether.app',
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
