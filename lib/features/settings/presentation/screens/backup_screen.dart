import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/backup_service.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/premium_gate_modal.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _isLoading = false;
  bool _cloudBackupEnabled = false;
  GoogleSignInAccount? _currentUser;
  int _lastBackupMs = 0;

  static const _cloudBackupEnabledKey = 'cloud_backup_enabled';

  @override
  void initState() {
    super.initState();
    _loadCloudBackupPreference();
    _checkSignIn();
  }

  Future<void> _loadCloudBackupPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _cloudBackupEnabled = prefs.getBool(_cloudBackupEnabledKey) ?? false;
        _lastBackupMs = prefs.getInt('last_drive_backup_ms') ?? 0;
      });
    }
  }

  Future<void> _setCloudBackupEnabled(bool value) async {
    if (value) {
      final premiumEnabled = ref.read(premiumEnabledProvider);
      final iapEnabled = ref.read(iapEnabledProvider);
      if (premiumEnabled && iapEnabled) {
        final isPremium = ref.read(premiumStatusProvider);
        if (!isPremium) {
          final trans = ref.read(translationsProvider);
          await showPremiumGateModal(
            context,
            ref,
            title: trans.premiumGateExportTitle,
            description: trans.premiumGateCloudBackupDesc,
            icon: Icons.cloud_upload_rounded,
          );
          return;
        }
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cloudBackupEnabledKey, value);
    if (mounted) setState(() => _cloudBackupEnabled = value);
    AnalyticsService.logToggleDailyBackup(enabled: value);
  }

  Future<void> _checkSignIn() async {
    final account = await ref.read(backupServiceProvider).signInSilently();
    if (mounted) setState(() => _currentUser = account);
  }

  Future<void> _handleExport() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(backupServiceProvider).exportDatabase();
      if (mounted) {
        final trans = ref.read(translationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trans.backupExportSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        final trans = ref.read(translationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${trans.backupExportFailed}: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleImport() async {
    final trans = ref.read(translationsProvider);
    // Security check or confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final themeMode = AppThemeProvider.of(context);
        final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
        final isDefault = themeMode == AppThemeMode.defaultTheme;
        return AlertDialog(
        backgroundColor: isDefault ? AppColors.bgDarkEnd : isLight ? Colors.white : const Color(0xFF111111),
        title: Text(trans.backupRestoreConfirmTitle, style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white)),
        content: Text(
          trans.backupRestoreConfirmContent,
          style: TextStyle(color: isLight ? const Color(0xFF374151) : Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(trans.cancel, style: TextStyle(color: isLight ? const Color(0xFF374151) : Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(trans.backupRestoreConfirmButton, style: const TextStyle(color: AppColors.error)),
          ),
        ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(backupServiceProvider).importDatabase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(translationsProvider).backupImportSuccess), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ref.read(translationsProvider).backupImportFailed}: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Returns true if the user is premium and the Drive flow should proceed.
  /// If false, the premium gate modal was shown and the caller should abort.
  Future<bool> _guardCloudBackup() async {
    final premiumEnabled = ref.read(premiumEnabledProvider);
    final iapEnabled = ref.read(iapEnabledProvider);
    final isPremium = ref.read(premiumStatusProvider);
    if (!premiumEnabled || !iapEnabled) return true; // Gate disabled — allow access
    if (isPremium) return true;
    final trans = ref.read(translationsProvider);
    await showPremiumGateModal(
      context,
      ref,
      title: trans.premiumGateExportTitle,
      description: trans.premiumGateCloudBackupDesc,
      icon: Icons.cloud_upload_rounded,
    );
    return false;
  }

  Future<void> _handleGoogleSignIn() async {
    if (!await _guardCloudBackup()) return;
    setState(() => _isLoading = true);
    try {
      final account = await ref.read(backupServiceProvider).signInWithGoogle();
      setState(() => _currentUser = account);
    } catch (e) {
      if (mounted) {
        final trans = ref.read(translationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${trans.backupGoogleSignInFailed}: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignOut() async {
    await ref.read(backupServiceProvider).signOutFromGoogle();
    setState(() => _currentUser = null);
  }

  Future<void> _handleUploadToDrive() async {
    if (!await _guardCloudBackup()) return;
    final messenger = ScaffoldMessenger.of(context);
    final trans = ref.read(translationsProvider);
    setState(() => _isLoading = true);
    try {
      await ref.read(backupServiceProvider).uploadToDrive();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(trans.backupUploadSuccess), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${trans.backupUploadFailed}: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRestoreFromDrive() async {
    if (!await _guardCloudBackup()) return;
    final messenger = ScaffoldMessenger.of(context);
    final trans = ref.read(translationsProvider);
    setState(() => _isLoading = true);

    List<drive.File> backups;
    try {
      backups = await ref.read(backupServiceProvider).listBackups();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          SnackBar(content: Text('${trans.backupLoadFailed}: $e'), backgroundColor: AppColors.error),
        );
      }
      return;
    }

    if (mounted) setState(() => _isLoading = false);
    if (!mounted) return;

    if (backups.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(trans.backupNoneOnDrive)),
      );
      return;
    }

    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;
    final sheetBg = isDefault ? AppColors.surface : isLight ? Colors.white : const Color(0xFF111111);
    final selectedFileId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: sheetBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _buildBackupListSheet(backups, isLight),
    );

    if (selectedFileId == null || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dlgThemeMode = AppThemeProvider.of(context);
        final dlgIsLight = dlgThemeMode == AppThemeMode.light || (dlgThemeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
        final dlgIsDefault = dlgThemeMode == AppThemeMode.defaultTheme;
        return AlertDialog(
        backgroundColor: dlgIsDefault ? AppColors.bgDarkEnd : dlgIsLight ? Colors.white : const Color(0xFF111111),
        title: Text(trans.backupDriveConfirmTitle, style: TextStyle(color: dlgIsLight ? AppColors.textPrimaryLight : Colors.white)),
        content: Text(
          trans.backupDriveConfirmContent,
          style: TextStyle(color: dlgIsLight ? const Color(0xFF374151) : Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(trans.cancel, style: TextStyle(color: dlgIsLight ? const Color(0xFF374151) : Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(trans.backupRestoreConfirmButton, style: const TextStyle(color: AppColors.error)),
          ),
        ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(backupServiceProvider).restoreFromDrive(selectedFileId);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(trans.backupRestoreSuccess), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${trans.backupRestoreFailed}: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildBackupListSheet(List<drive.File> backups, bool isLight) {
    final trans = ref.read(translationsProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              trans.backupSelectBackup,
              style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.1)),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: backups.length,
              itemBuilder: (context, index) {
                final file = backups[index];
                final name = file.name ?? 'Unknown';
                final created = file.createdTime;
                final size = file.size;
                final sizeText = size != null ? '${(int.tryParse(size) ?? 0) ~/ 1024} KB' : '';
                final dateText = created != null
                    ? created.toLocal().toString().split('.').first
                    : '';
                return ListTile(
                  leading: const Icon(Icons.backup, color: AppColors.primaryGold),
                  title: Text(name, style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white)),
                  subtitle: Text(
                    '$dateText  $sizeText'.trim(),
                    style: TextStyle(color: isLight ? const Color(0xFF94A3B8) : Colors.white54, fontSize: 12),
                  ),
                  onTap: () => Navigator.pop(context, file.id),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = AppThemeProvider.isLightMode(context);
    return Stack(
      children: [
        // Background
        Container(
          decoration: BoxDecoration(
            gradient: AppColors.backgroundGradient(context),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(ref.watch(translationsProvider).backupTitle),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: isLight ? AppColors.textPrimaryLight : Colors.white),
             titleTextStyle: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Builder(
                  builder: (context) {
                    final trans = ref.watch(translationsProvider);
                    return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(trans.backupManual),
                    const SizedBox(height: 16),
                    GlassCard(
                      child: Column(
                        children: [
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGold.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.upload_file, color: AppColors.primaryGold),
                            ),
                            title: Text(trans.backupExport, style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white)),
                            subtitle: Text(trans.backupExportSubtitle, style: TextStyle(color: isLight ? const Color(0xFF94A3B8) : Colors.white54)),
                            onTap: _handleExport,
                          ),
                          Divider(color: Colors.white.withValues(alpha: 0.1)),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGold.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.download_rounded, color: AppColors.primaryGold),
                            ),
                            title: Text(trans.backupImport, style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white)),
                            subtitle: Text(trans.backupImportSubtitle, style: TextStyle(color: isLight ? const Color(0xFF94A3B8) : Colors.white54)),
                            onTap: _handleImport,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    _buildSectionHeader(trans.backupGoogleDrive),
                    const SizedBox(height: 12),
                    GlassCard(
                      child: Column(
                        children: [
                          SwitchListTile(
                            secondary: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGold.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.cloud_sync_rounded, color: AppColors.primaryGold),
                            ),
                            title: Text(trans.backupCloudEnable, style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white)),
                            subtitle: Text(trans.backupCloudEnableSubtitle, style: TextStyle(color: isLight ? const Color(0xFF94A3B8) : Colors.white54)),
                            value: _cloudBackupEnabled,
                            activeColor: AppColors.primaryGold,
                            onChanged: _setCloudBackupEnabled,
                          ),
                          if (_cloudBackupEnabled) ...[
                            Divider(color: Colors.white.withValues(alpha: 0.1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.info_outline, color: AppColors.primaryGold, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      trans.backupDailyAutoInfo,
                                      style: TextStyle(
                                        color: isLight ? const Color(0xFF374151) : Colors.white70,
                                        fontSize: 12,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    _lastBackupMs > 0 ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                                    color: _lastBackupMs > 0 ? AppColors.success : Colors.orange,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _lastBackupMs > 0
                                          ? () {
                                              final lastDate = DateTime.fromMillisecondsSinceEpoch(_lastBackupMs);
                                              final diff = DateTime.now().difference(lastDate);
                                              if (diff.inHours < 1) return 'Last backup: ${diff.inMinutes}m ago';
                                              if (diff.inHours < 24) return 'Last backup: ${diff.inHours}h ago';
                                              return 'Last backup: ${diff.inDays}d ago';
                                            }()
                                          : 'Never backed up',
                                      style: TextStyle(
                                        color: isLight ? const Color(0xFF374151) : Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(color: Colors.white.withValues(alpha: 0.1)),
                            if (_currentUser == null)
                              ListTile(
                                leading: Icon(Icons.cloud_off, color: isLight ? const Color(0xFF94A3B8) : Colors.white54),
                                title: Text(trans.backupConnectDrive, style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white)),
                                onTap: _handleGoogleSignIn,
                              )
                            else ...[
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: (_currentUser!.photoUrl != null && _currentUser!.photoUrl!.isNotEmpty)
                                      ? NetworkImage(_currentUser!.photoUrl!)
                                      : null,
                                  backgroundColor: AppColors.primaryGold,
                                  child: (_currentUser!.photoUrl == null || _currentUser!.photoUrl!.isEmpty)
                                      ? Text(_currentUser!.displayName?[0] ?? 'U')
                                      : null,
                                ),
                                title: Text(
                                  _currentUser!.displayName ?? 'User',
                                  style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white),
                                ),
                                subtitle: Text(
                                  _currentUser!.email,
                                  style: TextStyle(color: isLight ? const Color(0xFF94A3B8) : Colors.white54),
                                ),
                                trailing: Tooltip(
                                  message: trans.backupDisconnect,
                                  child: IconButton(
                                    icon: Icon(Icons.logout, color: isLight ? const Color(0xFF94A3B8) : Colors.white54),
                                    onPressed: _handleGoogleSignOut,
                                  ),
                                ),
                              ),
                              Divider(color: Colors.white.withValues(alpha: 0.1)),
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGold.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.cloud_upload, color: AppColors.primaryGold),
                                ),
                                title: Text(trans.backupToDrive, style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white)),
                                subtitle: Text(trans.backupToDriveSubtitle, style: TextStyle(color: isLight ? const Color(0xFF94A3B8) : Colors.white54)),
                                onTap: _handleUploadToDrive,
                              ),
                              Divider(color: Colors.white.withValues(alpha: 0.1)),
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGold.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.cloud_download, color: AppColors.primaryGold),
                                ),
                                title: Text(trans.backupRestoreFromDrive, style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white)),
                                subtitle: Text(trans.backupRestoreFromDriveSubtitle, style: TextStyle(color: isLight ? const Color(0xFF94A3B8) : Colors.white54)),
                                onTap: _handleRestoreFromDrive,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                );
                  },
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.primaryGold,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }
}
