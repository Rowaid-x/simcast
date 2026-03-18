import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme.dart';
import '../../../models/user.dart';
import '../../../widgets/avatar.dart';
import '../providers/conversation_provider.dart';

/// Bottom sheet for starting a new direct conversation or group.
class NewConversationSheet extends ConsumerStatefulWidget {
  const NewConversationSheet({super.key});

  @override
  ConsumerState<NewConversationSheet> createState() =>
      _NewConversationSheetState();
}

class _NewConversationSheetState extends ConsumerState<NewConversationSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<User> _searchResults = [];
  bool _isSearching = false;
  bool _isGroupMode = false;
  final List<User> _selectedMembers = [];
  final _groupNameController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _groupNameController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await ref
          .read(conversationRepositoryProvider)
          .searchUsers(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _startDirectChat(User user) async {
    try {
      final conversation = await ref
          .read(conversationsProvider.notifier)
          .createDirect(user.id);
      if (mounted) {
        Navigator.of(context).pop();
        context.push('/chat/${conversation.id}', extra: {
          'name': user.displayName,
          'type': 'direct',
          'avatar': user.avatarUrl,
          'isOnline': user.isOnline,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create conversation: $e')),
        );
      }
    }
  }

  Future<void> _createGroup() async {
    if (_groupNameController.text.trim().isEmpty || _selectedMembers.isEmpty) {
      return;
    }

    try {
      final conversation = await ref
          .read(conversationsProvider.notifier)
          .createGroup(
            name: _groupNameController.text.trim(),
            memberIds: _selectedMembers.map((u) => u.id).toList(),
          );
      if (mounted) {
        Navigator.of(context).pop();
        context.push('/chat/${conversation.id}', extra: {
          'name': _groupNameController.text.trim(),
          'type': 'group',
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: WhisperColors.surfacePrimary,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(WhisperRadius.xl),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: WhisperSpacing.sm),
          // Handle bar
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: WhisperColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: WhisperSpacing.lg),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: WhisperSpacing.lg),
            child: Row(
              children: [
                Text(
                  _isGroupMode ? 'New Group' : 'New Chat',
                  style: WhisperTypography.heading2,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isGroupMode = !_isGroupMode;
                      _selectedMembers.clear();
                    });
                  },
                  icon: Icon(
                    _isGroupMode ? LucideIcons.user : LucideIcons.users,
                    size: 18,
                    color: WhisperColors.accent,
                  ),
                  label: Text(
                    _isGroupMode ? 'Direct' : 'Group',
                    style: WhisperTypography.bodyMedium.copyWith(
                      color: WhisperColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: WhisperSpacing.md),

          // Group name field (only in group mode)
          if (_isGroupMode) ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: WhisperSpacing.lg),
              child: TextField(
                controller: _groupNameController,
                style: WhisperTypography.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'Group name',
                  prefixIcon: Icon(
                    LucideIcons.users,
                    color: WhisperColors.textTertiary,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(height: WhisperSpacing.md),
          ],

          // Selected members chips
          if (_isGroupMode && _selectedMembers.isNotEmpty) ...[
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: WhisperSpacing.lg),
                itemCount: _selectedMembers.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: WhisperSpacing.sm),
                itemBuilder: (context, index) {
                  final user = _selectedMembers[index];
                  return Chip(
                    label: Text(
                      user.displayName,
                      style: WhisperTypography.caption.copyWith(
                        color: WhisperColors.textPrimary,
                      ),
                    ),
                    deleteIcon: const Icon(LucideIcons.x, size: 14),
                    deleteIconColor: WhisperColors.textSecondary,
                    onDeleted: () {
                      setState(() => _selectedMembers.remove(user));
                    },
                    backgroundColor: WhisperColors.surfaceSecondary,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(WhisperRadius.full),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: WhisperSpacing.md),
          ],

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: WhisperSpacing.lg),
            child: TextField(
              controller: _searchController,
              style: WhisperTypography.bodyLarge,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search by name or email',
                prefixIcon: Icon(
                  LucideIcons.search,
                  color: WhisperColors.textTertiary,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: WhisperSpacing.md),

          // Search results
          Expanded(
            child: _isSearching
                ? const Center(
                    child: CircularProgressIndicator(
                      color: WhisperColors.accent,
                      strokeWidth: 2,
                    ),
                  )
                : _searchResults.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.length < 2
                              ? 'Search for users to start chatting'
                              : 'No users found',
                          style: WhisperTypography.bodyMedium.copyWith(
                            color: WhisperColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          final isSelected = _selectedMembers.contains(user);
                          return ListTile(
                            leading: WhisperAvatar(
                              imageUrl: user.avatarUrl,
                              name: user.displayName,
                              size: 40,
                              showOnlineIndicator: true,
                              isOnline: user.isOnline,
                            ),
                            title: Text(
                              user.displayName,
                              style: WhisperTypography.bodyLarge,
                            ),
                            subtitle: Text(
                              user.email,
                              style: WhisperTypography.caption,
                            ),
                            trailing: _isGroupMode
                                ? Checkbox(
                                    value: isSelected,
                                    activeColor: WhisperColors.accent,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedMembers.add(user);
                                        } else {
                                          _selectedMembers.remove(user);
                                        }
                                      });
                                    },
                                  )
                                : const Icon(
                                    LucideIcons.chevronRight,
                                    color: WhisperColors.textTertiary,
                                    size: 20,
                                  ),
                            onTap: () {
                              if (_isGroupMode) {
                                setState(() {
                                  if (isSelected) {
                                    _selectedMembers.remove(user);
                                  } else {
                                    _selectedMembers.add(user);
                                  }
                                });
                              } else {
                                _startDirectChat(user);
                              }
                            },
                          );
                        },
                      ),
          ),

          // Create group button
          if (_isGroupMode && _selectedMembers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(WhisperSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _createGroup,
                  child: Text(
                      'Create Group (${_selectedMembers.length} members)'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
