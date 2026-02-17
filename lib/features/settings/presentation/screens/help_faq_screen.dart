import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';

class HelpFaqScreen extends ConsumerWidget {
  const HelpFaqScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trans = ref.watch(translationsProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDarkStart,
      appBar: AppBar(
        title: Text(trans.helpTitle),
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
                trans.helpTitle,
                style: AppTypography.textTheme.headlineSmall?.copyWith(
                  color: AppColors.primaryGold,
                ),
              ),
              const SizedBox(height: 24),

              _buildFaqItem(context, trans.helpFaq1Question, trans.helpFaq1Answer),
              _buildFaqItem(context, trans.helpFaq2Question, trans.helpFaq2Answer),
              _buildFaqItem(context, trans.helpFaq3Question, trans.helpFaq3Answer),
              _buildFaqItem(context, trans.helpFaq4Question, trans.helpFaq4Answer),
              _buildFaqItem(context, trans.helpFaq5Question, trans.helpFaq5Answer),
              _buildFaqItem(context, trans.helpFaq6Question, trans.helpFaq6Answer),
              _buildFaqItem(context, trans.helpFaq7Question, trans.helpFaq7Answer),

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
                      trans.helpContactSupport,
                      style: AppTypography.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      trans.helpContactEmail,
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
                      label: Text(trans.helpContactEmail),
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
