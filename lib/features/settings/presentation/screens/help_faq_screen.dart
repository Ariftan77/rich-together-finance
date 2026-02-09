import 'package:flutter/material.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';

class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDarkStart,
      appBar: AppBar(
        title: const Text('Help & FAQ'),
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
                'Help & FAQ',
                style: AppTypography.textTheme.headlineSmall?.copyWith(
                  color: AppColors.primaryGold,
                ),
              ),
              const SizedBox(height: 24),

              _buildFaqItem(
                context,
                'How do I add a transaction?',
                'Tap the + button on the Transactions screen, fill in the details (amount, category, account), and tap Save.',
              ),

              _buildFaqItem(
                context,
                'How do I create multiple profiles?',
                'Go to Settings, tap on your profile card, then select "Add New Profile". Each profile keeps its data completely separate.',
              ),

              _buildFaqItem(
                context,
                'Can I track multiple currencies?',
                'Yes! You can set different currencies for each account. Set your base currency in Settings to see consolidated totals.',
              ),

              _buildFaqItem(
                context,
                'How do I set up recurring transactions?',
                'When adding a transaction, tap "Make Recurring" and choose the frequency (daily, weekly, monthly, yearly).',
              ),

              _buildFaqItem(
                context,
                'Is my data secure?',
                'Yes! All data is stored locally on your device. We never send your financial data to external servers.',
              ),

              _buildFaqItem(
                context,
                'How do I backup my data?',
                'Go to Settings > Data Management > Backup. You can save to Google Drive or export to file.',
              ),

              _buildFaqItem(
                context,
                'Can I use the app offline?',
                'Absolutely! Rich Together works 100% offline. Internet is only needed for optional features like cloud backup.',
              ),

              const SizedBox(height: 32),

              // Contact Support Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryGold.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.support_agent,
                      color: AppColors.primaryGold,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Still need help?',
                      style: AppTypography.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Contact our support team',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Opening email client...'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.email),
                      label: const Text('support@richtogether.app'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqItem(BuildContext context, String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        iconColor: AppColors.primaryGold,
        collapsedIconColor: Colors.white.withValues(alpha: 0.5),
        title: Text(
          question,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        children: [
          Text(
            answer,
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
