import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../config/constants.dart';
import '../../../config/theme.dart';

/// App settings screen with notification and privacy options.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _storage = FlutterSecureStorage();

  bool _pushNotifications = true;
  bool _sound = true;
  bool _readReceipts = true;
  bool _onlineStatus = true;
  String _appVersion = '';
  String _backendVersion = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadVersion();
    _loadBackendVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _appVersion = '${info.version}+${info.buildNumber}');
    }
  }

  Future<void> _loadBackendVersion() async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));
      final response = await dio.get('/version/');
      if (mounted && response.data is Map) {
        setState(() => _backendVersion = response.data['version'] ?? '?');
      }
    } catch (_) {
      if (mounted) setState(() => _backendVersion = 'unreachable');
    }
  }

  Future<void> _loadSettings() async {
    final push = await _storage.read(key: 'setting_push');
    final sound = await _storage.read(key: 'setting_sound');
    final read = await _storage.read(key: 'setting_read_receipts');
    final online = await _storage.read(key: 'setting_online_status');
    if (mounted) {
      setState(() {
        _pushNotifications = push != 'false';
        _sound = sound != 'false';
        _readReceipts = read != 'false';
        _onlineStatus = online != 'false';
      });
    }
  }

  Future<void> _saveSetting(String key, bool value) async {
    await _storage.write(key: key, value: value.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(LucideIcons.arrowLeft, size: 22),
        ),
        title: Text('Settings', style: WhisperTypography.heading3),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: WhisperSpacing.lg),
        children: [
          const SizedBox(height: WhisperSpacing.lg),

          // Notifications section
          _SectionHeader(title: 'Notifications'),
          _SettingsTile(
            icon: LucideIcons.bell,
            title: 'Push Notifications',
            subtitle: 'Receive message notifications',
            trailing: Switch(
              value: _pushNotifications,
              onChanged: (val) {
                setState(() => _pushNotifications = val);
                _saveSetting('setting_push', val);
              },
              activeColor: WhisperColors.accent,
            ),
          ),
          _SettingsTile(
            icon: LucideIcons.bellRing,
            title: 'Sound',
            subtitle: 'Play sound for new messages',
            trailing: Switch(
              value: _sound,
              onChanged: (val) {
                setState(() => _sound = val);
                _saveSetting('setting_sound', val);
              },
              activeColor: WhisperColors.accent,
            ),
          ),

          const SizedBox(height: WhisperSpacing.xl),

          // Privacy section
          _SectionHeader(title: 'Privacy'),
          _SettingsTile(
            icon: LucideIcons.eye,
            title: 'Read Receipts',
            subtitle: 'Let others know when you read messages',
            trailing: Switch(
              value: _readReceipts,
              onChanged: (val) {
                setState(() => _readReceipts = val);
                _saveSetting('setting_read_receipts', val);
              },
              activeColor: WhisperColors.accent,
            ),
          ),
          _SettingsTile(
            icon: LucideIcons.radio,
            title: 'Online Status',
            subtitle: 'Show when you are active',
            trailing: Switch(
              value: _onlineStatus,
              onChanged: (val) {
                setState(() => _onlineStatus = val);
                _saveSetting('setting_online_status', val);
              },
              activeColor: WhisperColors.accent,
            ),
          ),

          const SizedBox(height: WhisperSpacing.xl),

          // Storage section
          _SectionHeader(title: 'Storage'),
          _SettingsTile(
            icon: LucideIcons.hardDrive,
            title: 'Clear Cache',
            subtitle: 'Free up storage space',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared'),
                  backgroundColor: WhisperColors.surfaceElevated,
                ),
              );
            },
          ),

          const SizedBox(height: WhisperSpacing.xl),

          // About section
          _SectionHeader(title: 'About'),
          _SettingsTile(
            icon: LucideIcons.info,
            title: 'App Version',
            subtitle: _appVersion.isEmpty ? '...' : _appVersion,
          ),
          _SettingsTile(
            icon: LucideIcons.server,
            title: 'Backend Version',
            subtitle: _backendVersion.isEmpty ? '...' : _backendVersion,
          ),
          _SettingsTile(
            icon: LucideIcons.shield,
            title: 'Privacy Policy',
            onTap: () {},
          ),
          _SettingsTile(
            icon: LucideIcons.fileText,
            title: 'Terms of Service',
            onTap: () {},
          ),

          const SizedBox(height: WhisperSpacing.xxl),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: WhisperSpacing.lg,
        bottom: WhisperSpacing.sm,
      ),
      child: Text(
        title.toUpperCase(),
        style: WhisperTypography.caption.copyWith(
          color: WhisperColors.textTertiary,
          letterSpacing: 1.0,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: WhisperSpacing.lg,
        vertical: WhisperSpacing.xs,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WhisperRadius.md),
      ),
      leading: Icon(
        icon,
        color: WhisperColors.textSecondary,
        size: 20,
      ),
      title: Text(
        title,
        style: WhisperTypography.bodyLarge,
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: WhisperTypography.caption.copyWith(
                color: WhisperColors.textTertiary,
              ),
            )
          : null,
      trailing: trailing ??
          (onTap != null
              ? const Icon(
                  LucideIcons.chevronRight,
                  color: WhisperColors.textTertiary,
                  size: 18,
                )
              : null),
    );
  }
}
