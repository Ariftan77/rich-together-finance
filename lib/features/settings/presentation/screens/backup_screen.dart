import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../../../../core/services/backup_service.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/widgets/glass_card.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _isLoading = false;
  GoogleSignInAccount? _currentUser;

  @override
  void initState() {
    super.initState();
    // Listen to Google Sign-In state if needed, or just check on load
    // For now, simpler implementation:
    _checkSignIn();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database exported successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleImport() async {
    // Security check or confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgDarkEnd,
        title: const Text('Restore Database?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will overwrite your current data with the backup file. This action cannot be undone. Are you sure?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(backupServiceProvider).importDatabase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database restored! Please restart the app.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final account = await ref.read(backupServiceProvider).signInWithGoogle();
      setState(() => _currentUser = account);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign-In failed: $e'), backgroundColor: AppColors.error),
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
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    try {
      await ref.read(backupServiceProvider).uploadToDrive();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Uploaded to Drive successfully!'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRestoreFromDrive() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);

    List<drive.File> backups;
    try {
      backups = await ref.read(backupServiceProvider).listBackups();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to load backups: $e'), backgroundColor: AppColors.error),
        );
      }
      return;
    }

    if (mounted) setState(() => _isLoading = false);
    if (!mounted) return;

    if (backups.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No backups found on Drive')),
      );
      return;
    }

    final selectedFileId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _buildBackupListSheet(backups),
    );

    if (selectedFileId == null || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgDarkEnd,
        title: const Text('Restore from Drive?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will overwrite your current data with the selected backup. This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(backupServiceProvider).restoreFromDrive(selectedFileId);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Restored! Please restart the app.'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Restore failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildBackupListSheet(List<drive.File> backups) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Select Backup to Restore',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Divider(color: Colors.white.withValues(alpha: 0.1)),
        ...backups.map((file) {
          final name = file.name ?? 'Unknown';
          final created = file.createdTime;
          final size = file.size;
          final sizeText = size != null ? '${(int.tryParse(size) ?? 0) ~/ 1024} KB' : '';
          final dateText = created != null
              ? created.toLocal().toString().split('.').first
              : '';
          return ListTile(
            leading: const Icon(Icons.backup, color: AppColors.primaryGold),
            title: Text(name, style: const TextStyle(color: Colors.white)),
            subtitle: Text(
              '$dateText  $sizeText'.trim(),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            onTap: () => Navigator.pop(context, file.id),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background
        Container(
          decoration: const BoxDecoration(
            gradient: AppColors.mainGradient,
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Backup & Restore'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white), 
             titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          body: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Manual Backup'),
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
                            title: const Text('Export Database', style: TextStyle(color: Colors.white)),
                            subtitle: const Text('Save your data to a file', style: TextStyle(color: Colors.white54)),
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
                            title: const Text('Import Database', style: TextStyle(color: Colors.white)),
                            subtitle: const Text('Restore data from a file', style: TextStyle(color: Colors.white54)),
                            onTap: _handleImport,
                          ),
                        ],
                      ),
                    ),
                    
                    // TODO: Google Drive sync — hidden until auth issue is resolved
                    // const SizedBox(height: 32),
                    // _buildSectionHeader('Cloud Backup (Google Drive)'),
                    // const SizedBox(height: 16),
                    // GlassCard(
                    //   child: Column(
                    //     children: [
                    //       if (_currentUser == null)
                    //         ListTile(
                    //           leading: const Icon(Icons.cloud_off, color: Colors.white54),
                    //           title: const Text('Connect Google Drive', style: TextStyle(color: Colors.white)),
                    //           onTap: _handleGoogleSignIn,
                    //         )
                    //       else ...[
                    //         ListTile(
                    //           leading: CircleAvatar(
                    //             backgroundImage: (_currentUser!.photoUrl != null && _currentUser!.photoUrl!.isNotEmpty)
                    //                 ? NetworkImage(_currentUser!.photoUrl!)
                    //                 : null,
                    //             backgroundColor: AppColors.primaryGold,
                    //             child: (_currentUser!.photoUrl == null || _currentUser!.photoUrl!.isEmpty)
                    //                 ? Text(_currentUser!.displayName?[0] ?? 'U')
                    //                 : null,
                    //           ),
                    //           title: Text(_currentUser!.displayName ?? 'User', style: const TextStyle(color: Colors.white)),
                    //           subtitle: Text(_currentUser!.email, style: const TextStyle(color: Colors.white54)),
                    //           trailing: IconButton(
                    //             icon: const Icon(Icons.logout, color: Colors.white54),
                    //             onPressed: _handleGoogleSignOut,
                    //           ),
                    //         ),
                    //         Divider(color: Colors.white.withValues(alpha: 0.1)),
                    //         ListTile(
                    //           leading: const Icon(Icons.cloud_upload, color: AppColors.primaryGold),
                    //           title: const Text('Backup to Drive', style: TextStyle(color: Colors.white)),
                    //           subtitle: const Text('Save current data to cloud', style: TextStyle(color: Colors.white54)),
                    //           onTap: _handleUploadToDrive,
                    //         ),
                    //         Divider(color: Colors.white.withValues(alpha: 0.1)),
                    //         ListTile(
                    //           leading: const Icon(Icons.cloud_download, color: AppColors.primaryGold),
                    //           title: const Text('Restore from Drive', style: TextStyle(color: Colors.white)),
                    //           subtitle: const Text('Restore data from cloud backup', style: TextStyle(color: Colors.white54)),
                    //           onTap: _handleRestoreFromDrive,
                    //         ),
                    //       ],
                    //     ],
                    //   ),
                    // ),
                  ],
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
