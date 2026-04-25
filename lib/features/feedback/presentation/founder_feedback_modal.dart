import 'package:flutter/material.dart';

import '../../../core/services/analytics_service.dart';
import '../../../shared/theme/app_theme_mode.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/theme/theme_provider_widget.dart';
import '../../../shared/widgets/glass_button.dart';
import '../services/founder_feedback_service.dart';

/// Shows the "Feedback from the Founder" modal bottom sheet.
///
/// Call this once per session — the [FounderFeedbackService.shouldShowModal]
/// gate ensures it only ever appears on the 3rd app open.
///
/// [isIndonesian] switches all copy to Bahasa Indonesia.
void showFounderFeedbackModal(BuildContext context, {required bool isIndonesian}) {
  AnalyticsService.trackFounderFeedbackShown();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _FounderFeedbackSheet(isIndonesian: isIndonesian),
  );
}

// ---------------------------------------------------------------------------
// Internal sheet widget
// ---------------------------------------------------------------------------

class _FounderFeedbackSheet extends StatefulWidget {
  final bool isIndonesian;

  const _FounderFeedbackSheet({required this.isIndonesian});

  @override
  State<_FounderFeedbackSheet> createState() => _FounderFeedbackSheetState();
}

class _FounderFeedbackSheetState extends State<_FounderFeedbackSheet> {
  final _formKey = GlobalKey<FormState>();
  final _contactController = TextEditingController();
  final _messageController = TextEditingController();
  bool _submitting = false;

  // -------------------------------------------------------------------------
  // Copy
  // -------------------------------------------------------------------------

  String get _title => widget.isIndonesian ? 'Pesan dari Founder' : 'A Message from the Founder';

  String get _body => widget.isIndonesian
      ? 'Hei, saya Arif — saya membangun Richer sendirian.\n\n'
          'Saya ingin ngobrol 15 menit tentang bagaimana kamu menggunakan aplikasi ini. '
          'Sebagai ucapan terima kasih, kamu akan mendapat akses premium seumur hidup saat diluncurkan.\n\n'
          'Tinggalkan WhatsApp atau email kamu dan saya akan menghubungi dalam 24 jam.'
      : 'Hi, I\'m Arif — I built Richer alone.\n\n'
          'I\'d love to chat with you for 15 minutes about how you use the app. '
          'As a thank you, you\'ll get lifetime premium access when it launches.\n\n'
          'Drop your WhatsApp or email and I\'ll reach out within 24 hours.';

  String get _contactLabel =>
      widget.isIndonesian ? 'WhatsApp atau email kamu' : 'Your WhatsApp or email';

  String get _messageLabel => widget.isIndonesian
      ? 'Ada yang ingin kamu sampaikan? (opsional)'
      : 'Anything you\'d like to share (optional)';

  String get _submitLabel => widget.isIndonesian ? 'Kirim' : 'Send';

  String get _dismissLabel => widget.isIndonesian ? 'Nanti saja' : 'Maybe later';

  String get _successMessage => widget.isIndonesian
      ? 'Terima kasih! Saya akan segera menghubungi 🙏'
      : 'Thanks! I\'ll reach out soon 🙏';

  String get _validationMessage =>
      widget.isIndonesian ? 'Mohon isi kontak kamu' : 'Please enter your contact';

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  InputDecoration _fieldDecoration(String label, {required bool isLight}) {
    final fillColor = isLight
        ? const Color(0xFFF1F5F9)
        : Colors.white.withValues(alpha: 0.07);
    final textColor = isLight ? const Color(0xFF1E293B) : Colors.white;
    final hintColor = isLight
        ? const Color(0xFF94A3B8)
        : Colors.white.withValues(alpha: 0.4);
    final borderColor = isLight
        ? const Color(0xFFCBD5E1)
        : Colors.white.withValues(alpha: 0.15);

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: hintColor, fontSize: 14),
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE74C3C)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE74C3C), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final contact = _contactController.text.trim();
    final message = _messageController.text.trim();

    setState(() => _submitting = true);

    FounderFeedbackService.submitFeedback(
      contact: contact,
      message: message.isEmpty ? null : message,
    );

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_successMessage),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _contactController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;

    // Match exact background colors used by account/category modals
    final bgColor = isDefault
        ? const Color(0xFF2D2416)
        : isLight
            ? Colors.white
            : const Color(0xFF1A1A1A);

    final titleColor = isLight ? AppColors.textPrimaryLight : Colors.white;
    final bodyColor = isLight
        ? const Color(0xFF475569)
        : Colors.white.withValues(alpha: 0.75);
    final dismissColor = isLight
        ? const Color(0xFF94A3B8)
        : Colors.white.withValues(alpha: 0.45);
    final handleColor = isLight
        ? const Color(0xFFCBD5E1)
        : Colors.white.withValues(alpha: 0.25);

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: handleColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Wave emoji
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Text('👋', style: TextStyle(fontSize: 30)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),

                // Body copy
                Text(
                  _body,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: bodyColor,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 24),

                // Contact field
                TextFormField(
                  controller: _contactController,
                  style: TextStyle(
                    color: isLight ? const Color(0xFF1E293B) : Colors.white,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: _fieldDecoration(_contactLabel, isLight: isLight),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return _validationMessage;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Message field (optional)
                TextFormField(
                  controller: _messageController,
                  style: TextStyle(
                    color: isLight ? const Color(0xFF1E293B) : Colors.white,
                  ),
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  maxLines: 3,
                  decoration: _fieldDecoration(_messageLabel, isLight: isLight),
                ),
                const SizedBox(height: 24),

                // Submit button
                GlassButton(
                  text: _submitLabel,
                  size: GlassButtonSize.large,
                  isFullWidth: true,
                  isPrimary: true,
                  isLoading: _submitting,
                  onPressed: _submit,
                ),
                const SizedBox(height: 8),

                // Dismiss
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    _dismissLabel,
                    style: TextStyle(color: dismissColor, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
