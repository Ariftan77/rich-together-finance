import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/services/remote_config_service.dart';
import '../../../../core/services/premium_auth_service.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';


class HelpFaqScreen extends ConsumerStatefulWidget {
  const HelpFaqScreen({super.key});

  @override
  ConsumerState<HelpFaqScreen> createState() => _HelpFaqScreenState();
}

class _HelpFaqScreenState extends ConsumerState<HelpFaqScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = '${info.version} (${info.buildNumber})');
      }
    } catch (_) {
      if (mounted) setState(() => _appVersion = '1.0.0');
    }
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
          final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
          final isDefault = themeMode == AppThemeMode.defaultTheme;
          return AlertDialog(
          backgroundColor: isDefault ? AppColors.bgDarkEnd : isLight ? Colors.white : const Color(0xFF111111),
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          title: Text(ref.watch(translationsProvider).settingsSendFeedback, style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white)),
          content: TextField(
            controller: controller,
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
                child: Text(ref.watch(translationsProvider).genericCancel, style: TextStyle(color: isLight ? const Color(0xFF374151) : Colors.white70)),
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
      final String appKey = RemoteConfigService().emailAppKey;
      final String targetEmail = 'axiomtech.dev@gmail.com';

      final smtpServer = gmail(targetEmail, appKey);

      final message = Message()
        ..from = Address(targetEmail, 'RichTogether Feedback')
        ..recipients.add(targetEmail)
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

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
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
            title: Text(trans.helpTitle),
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
                trans.helpTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.primaryGold,
                ),
              ),
              const SizedBox(height: 24),

              _buildFaqItem(context, trans.helpFaq1Question, trans.helpFaq1Answer, isLight),
              _buildFaqItem(context, trans.helpFaq2Question, trans.helpFaq2Answer, isLight),
              _buildFaqItem(context, trans.helpFaq3Question, trans.helpFaq3Answer, isLight),
              _buildFaqItem(context, trans.helpFaq4Question, trans.helpFaq4Answer, isLight),
              _buildFaqItem(context, trans.helpFaq5Question, trans.helpFaq5Answer, isLight),
              _buildFaqItem(context, trans.helpFaq6Question, trans.helpFaq6Answer, isLight),
              _buildFaqItem(context, trans.helpFaq7Question, trans.helpFaq7Answer, isLight),
              _buildFaqItem(context, trans.helpFaq8Question, trans.helpFaq8Answer, isLight),

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
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      trans.helpContactEmail,
                      style: TextStyle(
                        color: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showFeedbackDialog(),
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
      ],
    );
  }

  Widget _buildFaqItem(BuildContext context, String question, String answer, bool isLight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFF1F5F9) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: isLight ? Border.all(color: Colors.black.withValues(alpha: 0.08)) : null,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        iconColor: AppColors.primaryGold,
        collapsedIconColor: isLight ? const Color(0xFF64748B) : Colors.white.withValues(alpha: 0.5),
        title: Text(
          question,
          style: TextStyle(
            color: isLight ? AppColors.textPrimaryLight : Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        children: [
          Text(
            answer,
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
