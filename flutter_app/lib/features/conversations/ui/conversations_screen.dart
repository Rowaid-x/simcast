import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../widgets/avatar.dart';
import '../../../widgets/shimmer_loading.dart';
import '../providers/conversation_provider.dart';
import 'new_conversation_sheet.dart';
import 'widgets/conversation_tile.dart';

/// Main conversations list screen — the app's home screen.
class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  bool _isSearchExpanded = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openNewConversationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NewConversationSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Custom header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                WhisperSpacing.xl,
                WhisperSpacing.lg,
                WhisperSpacing.lg,
                WhisperSpacing.sm,
              ),
              child: Row(
                children: [
                  Text('Chats', style: WhisperTypography.heading1),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isSearchExpanded = !_isSearchExpanded;
                        if (!_isSearchExpanded) {
                          _searchController.clear();
                          _searchQuery = '';
                        }
                      });
                    },
                    icon: Icon(
                      _isSearchExpanded
                          ? LucideIcons.x
                          : LucideIcons.search,
                      color: WhisperColors.textSecondary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: WhisperSpacing.xs),
                  GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: WhisperAvatar(
                      imageUrl: currentUser?.avatarUrl,
                      name: currentUser?.displayName ?? 'U',
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),

            // Expandable search bar
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _isSearchExpanded
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: WhisperSpacing.lg,
                        vertical: WhisperSpacing.sm,
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: WhisperTypography.bodyLarge,
                        decoration: const InputDecoration(
                          hintText: 'Search conversations...',
                          prefixIcon: Icon(
                            LucideIcons.search,
                            color: WhisperColors.textTertiary,
                            size: 20,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() => _searchQuery = value.toLowerCase());
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // Conversations list
            Expanded(
              child: conversationsAsync.when(
                loading: () => ShimmerLoading.conversationList(),
                error: (error, stack) => _buildErrorState(error),
                data: (conversations) {
                  // Filter by search query
                  final filtered = _searchQuery.isEmpty
                      ? conversations
                      : conversations.where((c) {
                          return c.displayName
                              .toLowerCase()
                              .contains(_searchQuery);
                        }).toList();

                  if (filtered.isEmpty) {
                    return _buildEmptyState();
                  }

                  return RefreshIndicator(
                    color: WhisperColors.accent,
                    backgroundColor: WhisperColors.surfacePrimary,
                    onRefresh: () async {
                      await ref
                          .read(conversationsProvider.notifier)
                          .refresh();
                    },
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            left: 76, // avatar + padding offset
                          ),
                          child: Divider(
                            height: 0.5,
                            color: WhisperColors.divider,
                          ),
                        );
                      },
                      itemBuilder: (context, index) {
                        final conversation = filtered[index];
                        return ConversationTile(
                          conversation: conversation,
                          onTap: () {
                            // Mark as read
                            ref
                                .read(conversationsProvider.notifier)
                                .markAsRead(conversation.id);

                            context.push(
                              '/chat/${conversation.id}',
                              extra: {
                                'name': conversation.displayName,
                                'type': conversation.type,
                                'avatar': conversation.displayAvatar,
                                'isOnline': conversation.isOtherUserOnline,
                                'autoDeleteTimer':
                                    conversation.autoDeleteTimer,
                              },
                            );
                          },
                        ).animate().fadeIn(
                              duration: 200.ms,
                              delay: Duration(milliseconds: index * 30),
                            );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // FAB for new conversation
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewConversationSheet,
        backgroundColor: WhisperColors.accent,
        elevation: 4,
        child: const Icon(
          LucideIcons.messagePlus,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.messageCircle,
            size: 64,
            color: WhisperColors.textTertiary.withOpacity(0.5),
          ),
          const SizedBox(height: WhisperSpacing.lg),
          Text(
            'No conversations yet',
            style: WhisperTypography.heading3.copyWith(
              color: WhisperColors.textSecondary,
            ),
          ),
          const SizedBox(height: WhisperSpacing.sm),
          Text(
            'Start chatting with someone',
            style: WhisperTypography.bodyMedium.copyWith(
              color: WhisperColors.textTertiary,
            ),
          ),
          const SizedBox(height: WhisperSpacing.xl),
          ElevatedButton.icon(
            onPressed: _openNewConversationSheet,
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('Start chatting'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(180, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.wifiOff,
            size: 48,
            color: WhisperColors.textTertiary,
          ),
          const SizedBox(height: WhisperSpacing.lg),
          Text(
            'Could not load conversations',
            style: WhisperTypography.bodyLarge.copyWith(
              color: WhisperColors.textSecondary,
            ),
          ),
          const SizedBox(height: WhisperSpacing.lg),
          ElevatedButton(
            onPressed: () {
              ref.invalidate(conversationsProvider);
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
