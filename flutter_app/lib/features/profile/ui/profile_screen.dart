import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme.dart';
import '../../../core/network/api_client.dart';
import '../../../widgets/avatar.dart';
import '../../auth/providers/auth_provider.dart';

/// Profile screen for viewing and editing the current user's profile.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).valueOrNull;
    if (user != null) {
      _nameController.text = user.displayName;
      _bioController.text = user.bio;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() => _isUploadingAvatar = true);

    try {
      final dio = ref.read(apiClientProvider);

      // Upload the file
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(image.path),
      });
      final uploadResponse = await dio.post('/upload/', data: formData);
      final fileUrl = uploadResponse.data['file_url'] as String;

      // Patch avatar_url on user profile
      await dio.patch('/users/me/', data: {'avatar_url': fileUrl});

      // Update local auth state
      final updatedUser = ref.read(authStateProvider).valueOrNull?.copyWith(
            avatarUrl: fileUrl,
          );
      if (updatedUser != null) {
        ref.read(authStateProvider.notifier).updateUser(updatedUser);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated'),
            backgroundColor: WhisperColors.surfaceElevated,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload picture: $e'),
            backgroundColor: WhisperColors.surfaceElevated,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final dio = ref.read(apiClientProvider);
      await dio.patch('/users/me/', data: {
        'display_name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
      });

      final updatedUser =
          ref.read(authStateProvider).valueOrNull?.copyWith(
                displayName: _nameController.text.trim(),
                bio: _bioController.text.trim(),
              );
      if (updatedUser != null) {
        ref.read(authStateProvider.notifier).updateUser(updatedUser);
      }

      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated'),
            backgroundColor: WhisperColors.surfaceElevated,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: WhisperColors.surfaceElevated,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showChangePasswordDialog() {
    final oldPwController = TextEditingController();
    final newPwController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WhisperColors.surfaceElevated,
        title: Text('Change Password', style: WhisperTypography.heading3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPwController,
              obscureText: true,
              style: WhisperTypography.bodyLarge,
              decoration: const InputDecoration(hintText: 'Current password'),
            ),
            const SizedBox(height: WhisperSpacing.md),
            TextField(
              controller: newPwController,
              obscureText: true,
              style: WhisperTypography.bodyLarge,
              decoration: const InputDecoration(hintText: 'New password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: WhisperTypography.bodyMedium
                    .copyWith(color: WhisperColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final repo = ref.read(authRepositoryProvider);
                await repo.changePassword(
                  oldPassword: oldPwController.text,
                  newPassword: newPwController.text,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password changed successfully'),
                      backgroundColor: WhisperColors.surfaceElevated,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed: $e'),
                      backgroundColor: WhisperColors.surfaceElevated,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(100, 40),
            ),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WhisperColors.surfaceElevated,
        title: Text('Log Out', style: WhisperTypography.heading3),
        content: Text(
          'Are you sure you want to log out?',
          style: WhisperTypography.bodyLarge.copyWith(
            color: WhisperColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: WhisperTypography.bodyMedium
                    .copyWith(color: WhisperColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: WhisperColors.destructive,
              minimumSize: const Size(100, 40),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).logout();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(LucideIcons.arrowLeft, size: 22),
        ),
        title: Text('Profile', style: WhisperTypography.heading3),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: WhisperColors.accent,
                      ),
                    )
                  : Text(
                      'Save',
                      style: WhisperTypography.bodyMedium
                          .copyWith(color: WhisperColors.accent),
                    ),
            )
          else
            IconButton(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(LucideIcons.pencil,
                  color: WhisperColors.textSecondary, size: 20),
            ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: WhisperSpacing.xl),
              child: Column(
                children: [
                  const SizedBox(height: WhisperSpacing.xxl),

                  // Avatar
                  Stack(
                    children: [
                      WhisperAvatar(
                        imageUrl: user.avatarUrl,
                        name: user.displayName,
                        size: 80,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: WhisperColors.accent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: WhisperColors.background,
                                width: 2,
                              ),
                            ),
                            child: _isUploadingAvatar
                                ? const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    LucideIcons.camera,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms).scale(
                        begin: const Offset(0.9, 0.9),
                        end: const Offset(1.0, 1.0),
                        duration: 400.ms,
                      ),

                  const SizedBox(height: WhisperSpacing.lg),

                  // Display name
                  if (_isEditing)
                    TextField(
                      controller: _nameController,
                      style: WhisperTypography.heading2.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: 'Display name',
                        filled: true,
                        fillColor: WhisperColors.surfaceSecondary,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(WhisperRadius.md),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    )
                  else
                    Text(
                      user.displayName,
                      style: WhisperTypography.heading2,
                      textAlign: TextAlign.center,
                    ),

                  const SizedBox(height: WhisperSpacing.xs),

                  // Email
                  Text(
                    user.email,
                    style: WhisperTypography.bodyMedium.copyWith(
                      color: WhisperColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: WhisperSpacing.xl),

                  // Bio
                  if (_isEditing)
                    TextField(
                      controller: _bioController,
                      style: WhisperTypography.bodyLarge,
                      maxLines: 3,
                      maxLength: 200,
                      decoration: InputDecoration(
                        hintText: 'Bio',
                        filled: true,
                        fillColor: WhisperColors.surfaceSecondary,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(WhisperRadius.md),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    )
                  else if (user.bio.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(WhisperSpacing.lg),
                      decoration: BoxDecoration(
                        color: WhisperColors.surfaceSecondary,
                        borderRadius:
                            BorderRadius.circular(WhisperRadius.md),
                      ),
                      child: Text(
                        user.bio,
                        style: WhisperTypography.bodyLarge.copyWith(
                          color: WhisperColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: WhisperSpacing.xxxl),

                  // Actions
                  _buildActionTile(
                    icon: LucideIcons.lock,
                    title: 'Change Password',
                    onTap: _showChangePasswordDialog,
                  ),
                  _buildActionTile(
                    icon: LucideIcons.settings,
                    title: 'Settings',
                    onTap: () => context.push('/settings'),
                  ),
                  const SizedBox(height: WhisperSpacing.lg),
                  _buildActionTile(
                    icon: LucideIcons.logOut,
                    title: 'Log Out',
                    color: WhisperColors.destructive,
                    onTap: _handleLogout,
                  ),

                  const SizedBox(height: WhisperSpacing.xxxl),

                  // App version
                  Text(
                    'Whisper v1.0.0',
                    style: WhisperTypography.caption.copyWith(
                      color: WhisperColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: WhisperSpacing.xxl),
                ],
              ),
            ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: WhisperSpacing.lg,
        vertical: WhisperSpacing.xs,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WhisperRadius.md),
      ),
      tileColor: WhisperColors.surfacePrimary,
      leading: Icon(
        icon,
        color: color ?? WhisperColors.textSecondary,
        size: 20,
      ),
      title: Text(
        title,
        style: WhisperTypography.bodyLarge.copyWith(
          color: color ?? WhisperColors.textPrimary,
        ),
      ),
      trailing: Icon(
        LucideIcons.chevronRight,
        color: color ?? WhisperColors.textTertiary,
        size: 18,
      ),
    );
  }
}
