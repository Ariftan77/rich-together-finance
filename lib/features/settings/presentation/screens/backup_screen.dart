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
    // This part depends on how you want to handle auth persistence
    // For now, let's just see if silent sign-in works or if we need to sign in
    // final account = await ref.read(backupServiceProvider).signInSilently(); 
    // ^ Assuming we add signInSilently to service, or just let user tap "Connect"
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
                    
                    const SizedBox(height: 32),
                    _buildSectionHeader('Cloud Backup (Google Drive)'),
                    const SizedBox(height: 16),
                    GlassCard(
                      child: Column(
                        children: [
                          if (_currentUser == null)
                            ListTile(
                              leading: const Icon(Icons.cloud_off, color: Colors.white54),
                              title: const Text('Connect Google Drive', style: TextStyle(color: Colors.white)),
                              onTap: _handleGoogleSignIn,
                            )
                          else ...[
                            ListTile(
                              leading: CircleAvatar(
                                backgroundImage: NetworkImage(_currentUser!.photoUrl ?? ''),
                                backgroundColor: AppColors.primaryGold,
                                child: _currentUser!.photoUrl == null ? Text(_currentUser!.displayName?[0] ?? 'U') : null,
                              ),
                              title: Text(_currentUser!.displayName ?? 'User', style: const TextStyle(color: Colors.white)),
                              subtitle: Text(_currentUser!.email, style: const TextStyle(color: Colors.white54)),
                              trailing: IconButton(
                                icon: const Icon(Icons.logout, color: Colors.white54),
                                onPressed: _handleGoogleSignOut,
                              ),
                            ),
                            Divider(color: Colors.white.withValues(alpha: 0.1)),
                            ListTile(
                              leading: const Icon(Icons.cloud_upload, color: AppColors.primaryGold),
                              title: const Text('Backup to Drive', style: TextStyle(color: Colors.white)),
                              subtitle: const Text('Save current data to cloud', style: TextStyle(color: Colors.white54)),
                              onTap: () async {
                                setState(() => _isLoading = true);
                                try {
                                  await ref.read(backupServiceProvider).uploadToDrive();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Uploaded to Drive successfully!'), backgroundColor: AppColors.success),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error),
                                    );
                                  }
                                } finally {
                                  if (mounted) setState(() => _isLoading = false);
                                }
                              },
                            ),
                          ],
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
