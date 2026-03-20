import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../widgets/avatar.dart';
import '../../conversations/providers/conversation_provider.dart';

/// Bottom sheet showing group info with members, leave, and remove actions.
class GroupInfoSheet extends ConsumerStatefulWidget {
  final String conversationId;
  final String conversationName;

  const GroupInfoSheet({
    super.key,
    required this.conversationId,
    required this.conversationName,
  });

  @override
  ConsumerState<GroupInfoSheet> createState() => _GroupInfoSheetState();
}

class _GroupInfoSheetState extends ConsumerState<GroupInfoSheet> {
  List<_MemberInfo> _members = [];
  bool _isLoading = true;
  String? _currentUserId;
  String? _currentUserRole;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = await SecureStorage.getUserId();
    setState(() => _currentUserId = userId);
    await _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final dio = ref.read(apiClientProvider);
      final response =
          await dio.get('/conversations/${widget.conversationId}/');
      final data = response.data as Map<String, dynamic>;
      final membersJson = data['members'] as List? ?? [];

      final members = membersJson.map((m) {
        final user = m['user'] as Map<String, dynamic>;
        return _MemberInfo(
          id: user['id'] ?? '',
          displayName: user['display_name'] ?? '',
          email: user['email'] ?? '',
          avatarUrl: user['avatar_url'],
          role: m['role'] ?? 'member',
          isOnline: user['is_online'] ?? false,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _members = members;
          _isLoading = false;
          _currentUserRole = members
              .where((m) => m.id == _currentUserId)
              .firstOrNull
              ?.role;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load members';
        });
      }
    }
  }

  Future<void> _removeMember(_MemberInfo member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhisperColors.surfaceElevated,
        title: Text('Remove Member', style: WhisperTypography.heading3),
        content: Text(
          'Remove ${member.displayName} from this group?',
          style: WhisperTypography.bodyLarge
              .copyWith(color: WhisperColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: WhisperTypography.bodyMedium
                    .copyWith(color: WhisperColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: WhisperColors.destructive,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = ref.read(conversationRepositoryProvider);
      await repo.removeMember(widget.conversationId, member.id);
      await _loadMembers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${member.displayName} removed'),
            backgroundColor: WhisperColors.surfaceElevated,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove member: $e'),
            backgroundColor: WhisperColors.surfaceElevated,
          ),
        );
      }
    }
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WhisperColors.surfaceElevated,
        title: Text('Leave Group', style: WhisperTypography.heading3),
        content: Text(
          'Are you sure you want to leave "${widget.conversationName}"?',
          style: WhisperTypography.bodyLarge
              .copyWith(color: WhisperColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: WhisperTypography.bodyMedium
                    .copyWith(color: WhisperColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: WhisperColors.destructive,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = ref.read(conversationRepositoryProvider);
      await repo.deleteConversation(widget.conversationId);
      ref.read(conversationsProvider.notifier).refresh();
      if (mounted) {
        Navigator.pop(context);
        context.go('/conversations');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to leave group: $e'),
            backgroundColor: WhisperColors.surfaceElevated,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + WhisperSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: WhisperColors.surfacePrimary,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(WhisperRadius.xl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: WhisperSpacing.sm),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: WhisperColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: WhisperSpacing.xl),

          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: WhisperSpacing.xl),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: WhisperColors.accent.withOpacity(0.12),
                    borderRadius:
                        BorderRadius.circular(WhisperRadius.md),
                  ),
                  child: const Icon(
                    LucideIcons.users,
                    color: WhisperColors.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: WhisperSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.conversationName,
                          style: WhisperTypography.heading3),
                      Text('${_members.length} members',
                          style: WhisperTypography.caption.copyWith(
                              color: WhisperColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: WhisperSpacing.lg),

          const Divider(color: WhisperColors.divider, height: 1),

          // Members list
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(WhisperSpacing.xxl),
              child: CircularProgressIndicator(
                color: WhisperColors.accent,
                strokeWidth: 2,
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(WhisperSpacing.xxl),
              child: Text(_error!,
                  style: WhisperTypography.bodyLarge
                      .copyWith(color: WhisperColors.textSecondary)),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                    vertical: WhisperSpacing.sm),
                itemCount: _members.length,
                itemBuilder: (context, index) {
                  final member = _members[index];
                  final isMe = member.id == _currentUserId;
                  final isAdmin = _currentUserRole == 'admin';

                  return ListTile(
                    leading: WhisperAvatar(
                      imageUrl: member.avatarUrl,
                      name: member.displayName,
                      size: 40,
                      showOnlineIndicator: true,
                      isOnline: member.isOnline,
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            isMe
                                ? '${member.displayName} (You)'
                                : member.displayName,
                            style: WhisperTypography.bodyLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (member.role == 'admin') ...[
                          const SizedBox(width: WhisperSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  WhisperColors.accent.withOpacity(0.15),
                              borderRadius:
                                  BorderRadius.circular(WhisperRadius.sm),
                            ),
                            child: Text(
                              'Admin',
                              style: WhisperTypography.caption.copyWith(
                                color: WhisperColors.accent,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      member.email,
                      style: WhisperTypography.caption.copyWith(
                        color: WhisperColors.textTertiary,
                      ),
                    ),
                    trailing: !isMe && isAdmin
                        ? IconButton(
                            onPressed: () => _removeMember(member),
                            icon: const Icon(
                              LucideIcons.userMinus,
                              color: WhisperColors.destructive,
                              size: 18,
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),

          const Divider(color: WhisperColors.divider, height: 1),
          const SizedBox(height: WhisperSpacing.md),

          // Leave group button
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: WhisperSpacing.xl),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _leaveGroup,
                icon: const Icon(LucideIcons.logOut,
                    color: WhisperColors.destructive, size: 18),
                label: Text(
                  'Leave Group',
                  style: WhisperTypography.bodyLarge
                      .copyWith(color: WhisperColors.destructive),
                ),
                style: OutlinedButton.styleFrom(
                  side:
                      const BorderSide(color: WhisperColors.destructive),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(WhisperRadius.md),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberInfo {
  final String id;
  final String displayName;
  final String email;
  final String? avatarUrl;
  final String role;
  final bool isOnline;

  _MemberInfo({
    required this.id,
    required this.displayName,
    required this.email,
    this.avatarUrl,
    required this.role,
    this.isOnline = false,
  });
}
